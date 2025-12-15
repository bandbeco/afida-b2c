# frozen_string_literal: true

# Service to handle subscription checkout flow with Stripe
#
# Creates Stripe Checkout Session in subscription mode with ad-hoc prices
# (products are not stored in Stripe catalog).
#
# Usage:
#   service = SubscriptionCheckoutService.new(cart: cart, user: user, frequency: "every_month")
#   session = service.create_checkout_session(success_url: "...", cancel_url: "...")
#   redirect_to session.url
#
#   # After Stripe redirects back:
#   result = service.complete_checkout(session_id)
#   if result.success?
#     redirect_to order_path(result.order)
#   end
#
class SubscriptionCheckoutService
  # Result object for complete_checkout
  Result = Struct.new(:success?, :subscription, :order, :error_message, keyword_init: true)

  # Maps frequency enum to Stripe recurring params
  FREQUENCY_TO_STRIPE = {
    every_week: { interval: "week", interval_count: 1 },
    every_two_weeks: { interval: "week", interval_count: 2 },
    every_month: { interval: "month", interval_count: 1 },
    every_3_months: { interval: "month", interval_count: 3 }
  }.freeze

  # UK VAT rate (20%)
  VAT_RATE = BigDecimal("0.2")

  attr_reader :cart, :user, :frequency

  def initialize(cart:, user:, frequency:)
    @cart = cart
    @user = user
    @frequency = frequency&.to_sym
  end

  # Create a Stripe Checkout Session for subscription
  #
  # @param success_url [String] URL to redirect after successful payment
  # @param cancel_url [String] URL to redirect if user cancels
  # @return [Stripe::Checkout::Session]
  # @raise [Stripe::StripeError] if Stripe API call fails
  def create_checkout_session(success_url:, cancel_url:)
    customer = ensure_stripe_customer

    Stripe::Checkout::Session.create(
      mode: "subscription",
      customer: customer.id,
      line_items: build_line_items,
      success_url: "#{success_url}?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: cancel_url,
      metadata: {
        user_id: user.id.to_s,
        frequency: frequency.to_s,
        cart_id: cart.id.to_s
      },
      subscription_data: {
        metadata: {
          user_id: user.id.to_s,
          frequency: frequency.to_s
        }
      },
      shipping_address_collection: {
        allowed_countries: [ "GB" ]
      },
      shipping_options: shipping_options_for_cart,
      automatic_tax: { enabled: false }
    )
  end

  # Complete checkout after successful payment
  #
  # @param session_id [String] Stripe Checkout Session ID from callback
  # @return [Result] with success?, subscription, order, or error_message
  def complete_checkout(session_id)
    stripe_session = retrieve_stripe_session(session_id)

    # Idempotency: check if subscription already exists
    existing = Subscription.find_by(stripe_subscription_id: stripe_session.subscription.id)
    if existing
      order = existing.orders.first
      return Result.new(success?: true, subscription: existing, order: order)
    end

    # Build snapshots
    items_snapshot = build_items_snapshot
    shipping_snapshot = build_shipping_snapshot(stripe_session)

    ActiveRecord::Base.transaction do
      # Create subscription record
      subscription = create_subscription_record(stripe_session, items_snapshot, shipping_snapshot)

      # Create first order
      order = create_first_order(stripe_session, subscription, shipping_snapshot)

      # Clear cart
      cart.cart_items.destroy_all

      Result.new(success?: true, subscription: subscription, order: order)
    end
  rescue Stripe::StripeError => e
    Rails.logger.error("SubscriptionCheckoutService Stripe error: #{e.message}")
    Result.new(success?: false, error_message: "Payment session not found. Please contact support.")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("SubscriptionCheckoutService record invalid: #{e.message}")
    Result.new(success?: false, error_message: "Unable to create subscription. Please contact support.")
  end

  private

  # T008: Ensures user has a Stripe customer, creating one if needed
  #
  # @return [Stripe::Customer]
  def ensure_stripe_customer
    if user.stripe_customer_id.present?
      Stripe::Customer.retrieve(user.stripe_customer_id)
    else
      customer = Stripe::Customer.create(
        email: user.email_address,
        name: user.respond_to?(:full_name) ? user.full_name : nil,
        metadata: { user_id: user.id.to_s }
      )
      user.update!(stripe_customer_id: customer.id)
      customer
    end
  end

  # T009: Builds Stripe line items with ad-hoc prices and recurring params
  #
  # @return [Array<Hash>]
  def build_line_items
    cart.cart_items.includes(product_variant: :product).map do |item|
      variant = item.product_variant

      {
        price_data: {
          currency: "gbp",
          product_data: {
            name: variant_display_name(variant),
            description: variant.pac_size.present? && variant.pac_size > 1 ? "#{variant.pac_size} units per pack" : nil,
            metadata: {
              product_variant_id: variant.id.to_s,
              product_id: variant.product_id.to_s,
              sku: variant.sku
            }
          },
          unit_amount: (variant.price * 100).to_i,
          recurring: stripe_recurring_params
        },
        quantity: item.quantity
      }
    end
  end

  # T010: Builds items snapshot for JSONB storage (in minor currency units)
  #
  # @return [Hash]
  def build_items_snapshot
    items = cart.cart_items.includes(product_variant: :product).map do |item|
      variant = item.product_variant
      unit_price_minor = (variant.price * 100).to_i
      total_minor = unit_price_minor * item.quantity

      {
        "product_variant_id" => variant.id,
        "product_id" => variant.product_id,
        "sku" => variant.sku,
        "name" => variant_display_name(variant),
        "quantity" => item.quantity,
        "unit_price_minor" => unit_price_minor,
        "pac_size" => variant.pac_size,
        "total_minor" => total_minor
      }
    end

    subtotal_minor = items.sum { |i| i["total_minor"] }
    vat_minor = (subtotal_minor * VAT_RATE).to_i

    {
      "items" => items,
      "subtotal_minor" => subtotal_minor,
      "vat_minor" => vat_minor,
      "total_minor" => subtotal_minor + vat_minor,
      "currency" => "gbp"
    }
  end

  # T011: Builds shipping snapshot from Stripe session
  #
  # @param stripe_session [Stripe::Checkout::Session]
  # @return [Hash]
  def build_shipping_snapshot(stripe_session)
    customer_details = stripe_session.customer_details
    address = customer_details&.address

    shipping_cost = stripe_session.shipping_cost
    cost_minor = shipping_cost ? shipping_cost.amount_total : 0

    {
      "method" => "standard",
      "cost_minor" => cost_minor,
      "name" => "Standard Delivery",
      "address" => {
        "line1" => address&.line1,
        "line2" => address&.line2,
        "city" => address&.city,
        "postal_code" => address&.postal_code,
        "country" => address&.country
      },
      "recipient_name" => customer_details&.name
    }
  end

  # T012: Creates subscription record from completed checkout
  #
  # @return [Subscription]
  def create_subscription_record(stripe_session, items_snapshot, shipping_snapshot)
    stripe_sub = stripe_session.subscription
    price_id = stripe_sub.items.data.first&.price&.id

    Subscription.create!(
      user: user,
      stripe_subscription_id: stripe_sub.id,
      stripe_customer_id: stripe_session.customer,
      stripe_price_id: price_id || "unknown",
      frequency: frequency,
      status: :active,
      items_snapshot: items_snapshot,
      shipping_snapshot: shipping_snapshot,
      current_period_start: Time.at(stripe_sub.current_period_start),
      current_period_end: Time.at(stripe_sub.current_period_end)
    )
  end

  # Creates first order from subscription checkout
  #
  # @return [Order]
  def create_first_order(stripe_session, subscription, shipping_snapshot)
    address = shipping_snapshot["address"]
    items_snapshot = subscription.items_snapshot
    items_snapshot = JSON.parse(items_snapshot) if items_snapshot.is_a?(String)

    # Calculate amounts in pounds from minor units
    subtotal = items_snapshot["subtotal_minor"] / 100.0
    vat = items_snapshot["vat_minor"] / 100.0
    shipping = shipping_snapshot["cost_minor"] / 100.0
    total = subtotal + vat + shipping

    order = Order.create!(
      user: user,
      subscription: subscription,
      stripe_session_id: stripe_session.id,
      # First order has no stripe_invoice_id (created via checkout, not webhook)
      stripe_invoice_id: nil,
      email: stripe_session.customer_details.email,
      status: "paid",
      subtotal_amount: subtotal,
      vat_amount: vat,
      shipping_amount: shipping,
      total_amount: total,
      shipping_name: shipping_snapshot["recipient_name"],
      shipping_address_line1: address["line1"],
      shipping_address_line2: address["line2"],
      shipping_city: address["city"],
      shipping_postal_code: address["postal_code"],
      shipping_country: address["country"]
    )

    # Create order items from cart items
    cart.cart_items.each do |cart_item|
      OrderItem.create_from_cart_item(cart_item, order).save!
    end

    order
  end

  # Helper: Get recurring params for Stripe price_data
  def stripe_recurring_params
    FREQUENCY_TO_STRIPE.fetch(frequency) do
      raise ArgumentError, "Unknown frequency: #{frequency}"
    end
  end

  # Helper: Build display name for variant
  def variant_display_name(variant)
    "#{variant.product.name} - #{variant.name}"
  end

  # Helper: Retrieve Stripe session with subscription expanded
  def retrieve_stripe_session(session_id)
    Stripe::Checkout::Session.retrieve(
      id: session_id,
      expand: [ "subscription" ]
    )
  end

  # Helper: Determine shipping options based on cart value
  def shipping_options_for_cart
    # Use existing Shipping class if available, otherwise default
    if defined?(Shipping) && Shipping.respond_to?(:shipping_options_for_subtotal)
      Shipping.shipping_options_for_subtotal(cart.subtotal_amount)
    else
      [
        {
          shipping_rate_data: {
            type: "fixed_amount",
            fixed_amount: { amount: 0, currency: "gbp" },
            display_name: "Free Delivery"
          }
        }
      ]
    end
  end
end
