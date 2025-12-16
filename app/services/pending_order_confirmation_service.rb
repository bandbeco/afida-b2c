# frozen_string_literal: true

class PendingOrderConfirmationService
  Result = Struct.new(:success?, :order, :error, keyword_init: true)

  def initialize(pending_order)
    @pending_order = pending_order
    @schedule = pending_order.reorder_schedule
    @user = @schedule.user
  end

  def confirm!
    # Check for existing order with same payment intent (recovery from partial failure)
    existing_order = Order.find_by(stripe_session_id: idempotency_key)
    if existing_order
      @pending_order.confirm!(existing_order) unless @pending_order.confirmed?
      return success_result(existing_order)
    end

    payment_intent = nil

    ActiveRecord::Base.transaction do
      # Pessimistic lock prevents race condition where two concurrent requests
      # could both pass status checks before either updates the database
      @pending_order.lock!

      return error_result("Order has already been confirmed") if @pending_order.confirmed?
      return error_result("Order has expired") if @pending_order.expired?
      return error_result("Order is empty - no items to confirm") if @pending_order.items.empty?

      payment_intent = charge_payment!
      order = create_order!(payment_intent)
      @pending_order.confirm!(order)
      @schedule.advance_schedule!
      send_confirmation_email(order)

      success_result(order)
    end
  rescue Stripe::CardError => e
    error_result(e.message)
  rescue Stripe::StripeError => e
    error_result("Payment failed: #{e.message}")
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    # Payment succeeded but order creation failed - refund the charge
    refund_payment(payment_intent) if payment_intent
    error_result("Order creation failed: #{e.message}")
  end

  private

  # Idempotency key ensures retries don't create duplicate charges
  # Using pending_order ID ensures same charge for same pending order
  def idempotency_key
    "pending_order_#{@pending_order.id}"
  end

  def charge_payment!
    amount_in_cents = (@pending_order.total_amount * 100).to_i

    Stripe::PaymentIntent.create(
      {
        amount: amount_in_cents,
        currency: "gbp",
        customer: @user.stripe_customer_id,
        payment_method: @schedule.stripe_payment_method_id,
        off_session: true,
        confirm: true,
        description: "Scheduled reorder ##{@pending_order.id}",
        metadata: {
          pending_order_id: @pending_order.id,
          user_id: @user.id,
          schedule_id: @schedule.id
        }
      },
      { idempotency_key: idempotency_key }
    )
  end

  def refund_payment(payment_intent)
    return unless payment_intent&.id

    Stripe::Refund.create(
      payment_intent: payment_intent.id,
      reason: "requested_by_customer"
    )
  rescue Stripe::StripeError => e
    # Log refund failure but don't raise - original error is more important
    Rails.logger.error("Failed to refund payment #{payment_intent.id}: #{e.message}")
  end

  def create_order!(payment_intent)
    order = Order.create!(
      user: @user,
      email: @user.email_address,
      stripe_session_id: idempotency_key,
      order_number: generate_order_number,
      status: :paid,
      subtotal_amount: @pending_order.subtotal_amount,
      vat_amount: @pending_order.vat_amount,
      shipping_amount: shipping_amount,
      total_amount: @pending_order.total_amount,
      reorder_schedule: @schedule,
      **shipping_address_attributes
    )

    create_order_items!(order)
    order
  end

  def create_order_items!(order)
    @pending_order.items.each do |item|
      variant = ProductVariant.find(item["product_variant_id"])

      order.order_items.create!(
        product: variant.product,
        product_variant: variant,
        product_name: item["product_name"],
        product_sku: variant.sku,
        price: item["price"].to_d,
        quantity: item["quantity"],
        line_total: item["line_total"].to_d,
        pac_size: variant.pac_size
      )
    end
  end

  def shipping_amount
    @pending_order.items_snapshot["shipping"]&.to_d || 0
  end

  def shipping_address_attributes
    # Use user's default shipping address if available
    # Otherwise fall back to basic info
    if @user.respond_to?(:shipping_name) && @user.shipping_name.present?
      {
        shipping_name: @user.shipping_name,
        shipping_address_line1: @user.shipping_address_line1,
        shipping_address_line2: @user.shipping_address_line2,
        shipping_city: @user.shipping_city,
        shipping_postal_code: @user.shipping_postal_code,
        shipping_country: @user.shipping_country || "GB"
      }
    else
      # Fallback - use email as name placeholder
      {
        shipping_name: @user.email_address.split("@").first.titleize,
        shipping_address_line1: "Address pending update",
        shipping_address_line2: nil,
        shipping_city: "London",
        shipping_postal_code: "SW1A 1AA",
        shipping_country: "GB"
      }
    end
  end

  def generate_order_number
    # Same format as Order model
    year = Date.current.year
    random_part = SecureRandom.alphanumeric(6).upcase
    "#{year}-#{random_part}"
  end

  def send_confirmation_email(order)
    OrderMailer.with(order: order).confirmation_email.deliver_later
  end

  def success_result(order)
    Result.new(success?: true, order: order, error: nil)
  end

  def error_result(message)
    Result.new(success?: false, order: nil, error: message)
  end
end
