class CheckoutsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session
  rate_limit to: 10, within: 1.minute, only: :create, with: -> { redirect_to cart_path, alert: "Too many checkout attempts. Please wait before trying again." }

  # Eager loading strategy for cart items used across checkout methods
  CART_ITEM_INCLUDES = [ :product, :product_variant, { design_attachment: :blob } ].freeze

  def create
    cart = Current.cart
    # Eager load associations to prevent N+1 queries when building Stripe line items
    cart_items = cart.cart_items.includes(CART_ITEM_INCLUDES)
    line_items = cart_items.map do |item|
      # For standard products with pack pricing: send packs as quantity
      # For branded/configured products: send units as quantity
      variant_name = item.product_variant.name

      if item.sample?
        # Sample items: free, quantity 1
        quantity = 1
        unit_amount = 0
        product_name = "#{item.product.name} - #{variant_name} (Sample)"
      elsif item.configured?
        # Unit-based pricing (branded products)
        quantity = 1
        unit_amount = (item.price.to_f * item.quantity * 100).round
        units_formatted = ActiveSupport::NumberHelper.number_to_delimited(item.quantity)
        product_name = "#{item.product.name} - #{item.configuration['size']} (#{units_formatted} units)"
      elsif item.product_variant.pac_size.blank? || item.product_variant.pac_size.zero?
        # Unit-based pricing (products without packs)
        quantity = item.quantity
        unit_amount = (item.price.to_f * 100).round
        product_name = "#{item.product.name} - #{variant_name}"
      else
        # Pack-based pricing (standard products)
        packs_needed = item.quantity
        quantity = 1
        unit_amount = (item.price.to_f * packs_needed * 100).round
        packs_label = packs_needed == 1 ? "pack" : "packs"
        product_name = "#{item.product.name} - #{variant_name} (#{packs_needed} #{packs_label})"
      end

      {
        quantity: quantity,
        price_data: {
          currency: "gbp",
          product_data: {
            name: product_name,
            metadata: {
              cart_item_id: item.id.to_s,
              product_variant_id: item.product_variant_id.to_s,
              product_id: item.product.id.to_s,
              is_sample: item.sample?.to_s,
              is_configured: item.configured?.to_s,
              original_quantity: item.quantity.to_s,
              original_price: item.price.to_s,
              pac_size: item.pac_size.to_s
            }
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
        cancel_url: cancel_checkout_url
      }

      if Current.user
        session_params[:customer_email] = Current.user.email_address
        session_params[:client_reference_id] = Current.user.id
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
      # Retrieve session with line_items expanded to get what was actually charged
      # This prevents race conditions where cart is modified during payment
      stripe_session = Stripe::Checkout::Session.retrieve(
        id: session_id,
        expand: [ "line_items.data.price.product" ]
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

      # Create the order from Stripe's line_items (source of truth for what was charged)
      # This works even if cart was modified or emptied during payment
      order = create_order_from_stripe_session(stripe_session)

      # Clear the cart after successful order creation
      cart = Current.cart
      cart&.cart_items&.destroy_all

      # Send order confirmation email
      OrderMailer.with(order: order).confirmation_email.deliver_later

      # Store in session for immediate access (proves ownership for guest checkout)
      session[:recent_order_id] = order.id

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

  # Creates order from Stripe session's line_items (source of truth)
  #
  # Uses Stripe's line_items instead of cart to prevent race conditions where
  # cart is modified during payment. The metadata stored in each product_data
  # contains the original cart_item_id, product_variant_id, and pricing details.
  #
  def create_order_from_stripe_session(stripe_session)
    customer_details = stripe_session.customer_details
    line_items = stripe_session.line_items.data

    # Calculate totals from Stripe's line_items (what was actually charged)
    # Stripe returns amounts in minor units (pence), excluding tax
    subtotal = line_items.sum { |item| item.amount_subtotal } / 100.0
    vat_amount = line_items.sum { |item| item.amount_tax } / 100.0

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

    # Check if any items are configured (for branded order status)
    has_configured_items = line_items.any? do |item|
      metadata = item.price.product.metadata
      metadata["is_configured"] == "true"
    end

    ActiveRecord::Base.transaction do
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

      # Set initial branded order status if order contains configured items
      if has_configured_items
        order.update!(branded_order_status: "design_pending")
      end

      # Create order items from Stripe line_items
      line_items.each do |stripe_item|
        create_order_item_from_stripe(order, stripe_item)
      end

      order
    end
  end

  # Creates an OrderItem from a Stripe line_item
  #
  # The product metadata contains the original cart item details:
  # - cart_item_id: Original cart item (for design attachment lookup)
  # - product_variant_id, product_id: Database references
  # - original_quantity, original_price, pac_size: Pricing details
  # - is_sample, is_configured: Item type flags
  #
  def create_order_item_from_stripe(order, stripe_item)
    metadata = stripe_item.price.product.metadata

    product_variant_id = metadata["product_variant_id"]&.to_i
    product_id = metadata["product_id"]&.to_i
    cart_item_id = metadata["cart_item_id"]&.to_i
    is_sample = metadata["is_sample"] == "true"
    is_configured = metadata["is_configured"] == "true"
    original_quantity = metadata["original_quantity"]&.to_i || stripe_item.quantity
    original_price = metadata["original_price"]&.to_f || (stripe_item.price.unit_amount / 100.0)
    pac_size = metadata["pac_size"]&.to_i

    # Look up variant (may be nil if deleted)
    variant = ProductVariant.find_by(id: product_variant_id)
    product = Product.find_by(id: product_id)

    # Build configuration from cart_item if this is a configured product
    configuration = nil
    if is_configured && cart_item_id
      cart_item = CartItem.find_by(id: cart_item_id)
      configuration = cart_item&.configuration
    end

    order_item = OrderItem.create!(
      order: order,
      product: product,
      product_variant: variant,
      product_name: stripe_item.description,
      product_sku: variant&.sku || "UNKNOWN",
      quantity: original_quantity,
      price: original_price,
      pac_size: pac_size.present? && pac_size > 0 ? pac_size : nil,
      line_total: original_price * original_quantity,
      configuration: configuration,
      is_sample: is_sample
    )

    # Copy design attachment from cart_item if present
    if cart_item_id
      cart_item = CartItem.find_by(id: cart_item_id)
      if cart_item&.design&.attached?
        order_item.design.attach(cart_item.design.blob)
      end
    end

    order_item
  end

  def extract_shipping_address(stripe_session)
    return {} unless stripe_session.customer_details

    {
      name: stripe_session.customer_details.name,
      line1: stripe_session.customer_details.address.line1,
      line2: stripe_session.customer_details.address.line2,
      city: stripe_session.customer_details.address.city,
      postal_code: stripe_session.customer_details.address.postal_code,
      country: stripe_session.customer_details.address.country
    }
  end

  # Returns the Stripe TaxRate for UK VAT (20%)
  #
  # Performance: Uses cached tax_rate_id from credentials to avoid API calls.
  # If not configured, falls back to searching/creating (one-time operation).
  #
  # Setup: After first checkout creates the tax rate, add to credentials:
  #   rails credentials:edit
  #   stripe:
  #     tax_rate_id: txr_xxx
  #
  def tax_rate
    @tax_rate ||= begin
      cached_id = Rails.application.credentials.dig(:stripe, :tax_rate_id)

      if cached_id.present?
        # Fast path: retrieve by ID (single API call, cached for request)
        Stripe::TaxRate.retrieve(cached_id)
      else
        # Slow path: search for existing or create new (logs warning)
        Rails.logger.warn("[Checkout] No stripe.tax_rate_id in credentials - searching/creating tax rate")
        find_or_create_uk_vat_rate
      end
    rescue Stripe::InvalidRequestError => e
      # Cached tax_rate_id was deleted or invalid - fall back to recreation
      Rails.logger.warn("[Checkout] Cached tax_rate_id invalid: #{e.message} - recreating")
      find_or_create_uk_vat_rate
    end
  end

  # Finds existing UK VAT rate or creates one
  # Called only when tax_rate_id not configured in credentials
  def find_or_create_uk_vat_rate
    existing_rates = Stripe::TaxRate.list(active: true, limit: 100)
    uk_vat_rate = existing_rates.data.find do |rate|
      rate.percentage == 20.0 &&
        rate.country == "GB" &&
        rate.inclusive == false
    end

    if uk_vat_rate
      Rails.logger.info("[Checkout] Found existing UK VAT rate: #{uk_vat_rate.id} - add to credentials")
      uk_vat_rate
    else
      new_rate = Stripe::TaxRate.create({
        display_name: "VAT",
        percentage: 20,
        country: "GB",
        jurisdiction: "United Kingdom",
        description: "Value Added Tax",
        inclusive: false
      })
      Rails.logger.info("[Checkout] Created UK VAT rate: #{new_rate.id} - add to credentials")
      new_rate
    end
  end
end
