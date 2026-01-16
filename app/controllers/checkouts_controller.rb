class CheckoutsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session
  rate_limit to: 10, within: 1.minute, only: :create, with: -> { redirect_to cart_path, alert: "Too many checkout attempts. Please wait before trying again." }

  # Eager loading strategy for cart items used across checkout methods
  CART_ITEM_INCLUDES = [ :product, { design_attachment: :blob } ].freeze

  def create
    cart = Current.cart
    # Eager load associations to prevent N+1 queries when building Stripe line items
    cart_items = cart.cart_items.includes(CART_ITEM_INCLUDES)
    line_items = cart_items.map do |item|
      # For standard products with pack pricing: send packs as quantity
      # For branded/configured products: send units as quantity
      product = item.product

      if item.sample?
        # Sample items: free, quantity 1
        quantity = 1
        unit_amount = 0
        product_name = "#{product.generated_title} (Sample)"
      elsif item.configured?
        # Unit-based pricing (branded products)
        quantity = 1
        unit_amount = (item.price.to_f * item.quantity * 100).round
        units_formatted = ActiveSupport::NumberHelper.number_to_delimited(item.quantity)
        product_name = "#{product.generated_title} - #{item.configuration['size']} (#{units_formatted} units)"
      elsif product.pac_size.blank? || product.pac_size.zero?
        # Unit-based pricing (products without packs)
        quantity = item.quantity
        unit_amount = (item.price.to_f * 100).round
        product_name = product.generated_title
      else
        # Pack-based pricing (standard products)
        packs_needed = item.quantity
        quantity = 1
        unit_amount = (item.price.to_f * packs_needed * 100).round
        packs_label = packs_needed == 1 ? "pack" : "packs"
        product_name = "#{product.generated_title} (#{packs_needed} #{packs_label})"
      end

      {
        quantity: quantity,
        price_data: {
          currency: "gbp",
          product_data: {
            name: product_name
          },
          unit_amount: unit_amount,
          tax_behavior: "exclusive"
        },
        tax_rates: [ tax_rate.id ]
      }
    end

    begin
      # Determine shipping options based on order type and subtotal:
      # - Samples-only orders: Fixed sample delivery rate
      # - Orders >= £100 subtotal: Free shipping
      # - Orders < £100 subtotal: Standard shipping (£5)
      shipping_options = if cart.only_samples?
        [ Shipping.sample_only_shipping_option ]
      else
        Shipping.shipping_options_for_subtotal(cart.subtotal_amount)
      end

      session_params = {
        payment_method_types: [ "card" ],
        line_items: line_items,
        mode: "payment",
        shipping_address_collection: {
          allowed_countries: Shipping::ALLOWED_COUNTRIES
        },
        shipping_options: shipping_options,
        success_url: success_checkout_url + "?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: cancel_checkout_url,
        metadata: {
          cart_id: cart.id.to_s
        }
      }

      # Apply discount coupon if present in session
      if session[:discount_code].present?
        session_params[:discounts] = [ { coupon: session[:discount_code] } ]
      end

      if Current.user
        session_params[:client_reference_id] = Current.user.id

        # If user selected an address, sync it to Stripe Customer for prefill
        if params[:address_id].present?
          address = Current.user.addresses.find_by(id: params[:address_id])
          if address
            # Sync address to Stripe Customer (creates customer if needed)
            Current.user.sync_stripe_customer!(address: address)
            session[:selected_address_id] = params[:address_id]

            # Use Stripe Customer for address prefill
            session_params[:customer] = Current.user.stripe_customer_id
          else
            # Address not found - fall back to email only
            session_params[:customer_email] = Current.user.email_address
          end
        else
          # User chose "Enter a different address" or has no addresses
          # Use customer_email so Stripe doesn't prefill from existing Customer
          session_params[:customer_email] = Current.user.email_address
        end
      end

      session = Stripe::Checkout::Session.create(session_params)

      redirect_to session.url, allow_other_host: true, status: :see_other
    rescue Stripe::StripeError => e
      Rails.logger.error("Stripe error: #{e.message}")
      flash[:error] = e.message
      redirect_to cart_path
    end
  end

  def success
    session_id = params[:session_id]

    unless session_id.present?
      flash[:error] = "Invalid checkout session"
      return redirect_to cart_path
    end

    begin
      stripe_session = Stripe::Checkout::Session.retrieve(
        id: session_id,
        expand: [ "collected_information" ]
      )

      unless stripe_session.payment_status == "paid"
        flash[:error] = "Payment was not completed successfully"
        return redirect_to cart_path
      end

      # Check if order already exists for this session (prevent duplicates)
      existing_order = Order.find_by(stripe_session_id: session_id)
      if existing_order
        # Redirect to show page (not confirmation) for duplicate requests
        return redirect_to order_path(existing_order, token: existing_order.signed_access_token)
      end

      # Get the cart with eager loading for order creation
      cart = Current.cart
      if cart.blank? || cart.cart_items.empty?
        flash[:error] = "No items found in cart"
        return redirect_to root_path
      end

      # Preload associations for order item creation (prevents N+1 queries)
      cart.cart_items.includes(CART_ITEM_INCLUDES).load

      # Create the order
      customer_details = stripe_session.customer_details
      order = create_order_from_stripe_session(stripe_session, cart)

      # Clear the cart after successful order creation
      cart.cart_items.destroy_all

      # Send order confirmation email
      OrderMailer.with(order: order).confirmation_email.deliver_later

      # Store in session for immediate access (proves ownership for guest checkout)
      session[:recent_order_id] = order.id

      # Clear discount code after successful order (one-time use)
      session.delete(:discount_code)

      # Redirect to confirmation page with signed token
      redirect_to confirmation_order_path(order, token: order.signed_access_token),
                  status: :see_other

    rescue Stripe::StripeError => e
      Rails.logger.error("Stripe error in checkout success: #{e.message}")
      flash[:error] = "Unable to verify payment. Please contact support."
      redirect_to cart_path
    rescue => e
      Rails.logger.error("Error creating order: #{e.message}")
      flash[:error] = "There was an error processing your order. Please contact support."
      redirect_to cart_path
    end
  end

  def cancel
    redirect_to cart_path, notice: "Checkout cancelled."
  end

  private

  def create_order_from_stripe_session(stripe_session, cart)
    customer_details = stripe_session.customer_details
    # Calculate totals from cart
    subtotal = cart.subtotal_amount
    vat_amount = cart.vat_amount

    # Get shipping cost from Stripe session
    shipping_cost = if stripe_session.shipping_cost
      (stripe_session.shipping_cost.amount_total / 100.0).round(2)
    else
      0.0
    end

    total_amount = subtotal + vat_amount + shipping_cost

    # Extract shipping address details
    shipping_address = extract_shipping_address(stripe_session)

    if [ shipping_address[:name], shipping_address[:line1], shipping_address[:city], shipping_address[:postal_code], shipping_address[:country] ].any?(&:blank?)
      raise "Shipping details are required"
    end

    # Get user for order
    user = User.find_by(id: stripe_session.client_reference_id)

    # Create the order
    order = Order.create!(
      user: user,
      organization: user&.organization,
      placed_by_user: user&.organization_id? ? user : nil,
      email: customer_details.email,
      stripe_session_id: stripe_session.id,
      status: "paid",
      subtotal_amount: subtotal,
      vat_amount: vat_amount,
      shipping_amount: shipping_cost,
      total_amount: total_amount,
      shipping_name: shipping_address[:name],
      shipping_address_line1: shipping_address[:line1],
      shipping_address_line2: shipping_address[:line2],
      shipping_city: shipping_address[:city],
      shipping_postal_code: shipping_address[:postal_code],
      shipping_country: shipping_address[:country]
    )

    # Set initial branded order status if cart contains configured items
    if cart.cart_items.any?(&:configured?)
      order.update!(branded_order_status: "design_pending")
    end

    # Create order items from cart items
    cart.cart_items.each do |cart_item|
      OrderItem.create_from_cart_item(cart_item, order).save!
    end

    order
  end

  def extract_shipping_address(stripe_session)
    # Use with_indifferent_access for reliable key access (Stripe returns symbol keys)
    # Requires Stripe API Clover release (2025-03-31+) where shipping_details
    # moved to collected_information.shipping_details
    # https://docs.stripe.com/changelog/basil/2025-03-31/checkout-session-remove-shipping-details
    session_hash = stripe_session.to_hash.with_indifferent_access

    shipping = session_hash.dig(:collected_information, :shipping_details)
    return {} unless shipping

    shipping = shipping.with_indifferent_access if shipping.respond_to?(:with_indifferent_access)
    address = shipping[:address]
    return {} unless address

    address = address.with_indifferent_access if address.respond_to?(:with_indifferent_access)

    {
      name: shipping[:name],
      line1: address[:line1],
      line2: address[:line2],
      city: address[:city],
      postal_code: address[:postal_code],
      country: address[:country]
    }
  end

  def tax_rate
    @tax_rate ||= begin
      # Try to find existing UK VAT tax rate to avoid creating duplicates
      existing_rates = Stripe::TaxRate.list(active: true, limit: 100)
      uk_vat_rate = existing_rates.data.find do |rate|
        rate.percentage == 20.0 &&
          rate.country == "GB" &&
          rate.inclusive == false
      end

      # Use existing rate if found, otherwise create new one
      uk_vat_rate || Stripe::TaxRate.create({
        display_name: "VAT",
        percentage: 20,
        country: "GB",
        jurisdiction: "United Kingdom",
        description: "Value Added Tax",
        inclusive: false
      })
    end
  end
end
