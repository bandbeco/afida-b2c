module Webhooks
  class StripeController < ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection

    def create
      payload = request.body.read
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
      webhook_secret = Rails.application.credentials.dig(:stripe, :webhook_secret)

      unless webhook_secret.present?
        Rails.logger.error("[Stripe Webhook] Missing webhook_secret in credentials")
        head :bad_request
        return
      end

      begin
        event = Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)
      rescue JSON::ParserError
        Rails.logger.error("[Stripe Webhook] Invalid JSON payload")
        head :bad_request
        return
      rescue Stripe::SignatureVerificationError
        Rails.logger.error("[Stripe Webhook] Invalid signature")
        head :bad_request
        return
      end

      # Emit webhook.received event for tracing
      Rails.event.notify("webhook.received",
        event_type: event.type,
        stripe_event_id: event.id
      )

      handle_event(event)
      head :ok
    end

    private

    def handle_event(event)
      case event.type
      when "checkout.session.completed"
        handle_checkout_completed(event)
      else
        Rails.logger.info("[Stripe Webhook] Unhandled event type: #{event.type}")
      end
    end

    def handle_checkout_completed(event)
      session = event.data.object
      return unless session.payment_status == "paid"

      # Check if order already exists (created by success redirect)
      existing_order = Order.find_by(stripe_session_id: session.id)
      if existing_order
        Rails.logger.info("[Stripe Webhook] Order already exists for session #{session.id}")
        return
      end

      # Order doesn't exist - this means the success redirect failed
      # We need to create the order from the webhook
      Rails.logger.info("[Stripe Webhook] Creating order for session #{session.id} (redirect missed)")

      # Retrieve full session with expanded data
      full_session = Stripe::Checkout::Session.retrieve(
        id: session.id,
        expand: [ "collected_information", "line_items" ]
      )

      # Extract shipping address
      shipping = extract_shipping_address(full_session)

      # Get user if client_reference_id was set
      user = User.find_by(id: full_session.client_reference_id)

      # Try to get cart from metadata (added to checkout session for webhook fallback)
      cart_id = full_session.metadata&.cart_id
      cart = Cart.find_by(id: cart_id) if cart_id.present?

      # Calculate amounts - prefer cart data if available, fall back to Stripe line items
      if cart&.cart_items&.any?
        subtotal = cart.subtotal_amount
        vat_amount = cart.vat_amount
      else
        # Fallback: Calculate from Stripe line items
        line_items = full_session.line_items.data
        # Stripe line item amount_total includes tax, so we need to subtract it
        tax_amount_from_stripe = full_session.total_details&.amount_tax.to_i / 100.0
        subtotal = (line_items.sum { |item| item.amount_total } / 100.0) - tax_amount_from_stripe
        vat_amount = tax_amount_from_stripe
      end

      # Get shipping amount from Stripe
      shipping_amount = full_session.shipping_cost&.amount_total.to_i / 100.0
      total_amount = subtotal + vat_amount + shipping_amount

      order = Order.create!(
        user: user,
        organization: user&.organization,
        placed_by_user: user&.organization_id? ? user : nil,
        email: full_session.customer_details&.email,
        stripe_session_id: full_session.id,
        status: "paid",
        subtotal_amount: subtotal,
        vat_amount: vat_amount,
        shipping_amount: shipping_amount,
        total_amount: total_amount,
        shipping_name: shipping[:name],
        shipping_address_line1: shipping[:line1],
        shipping_address_line2: shipping[:line2],
        shipping_city: shipping[:city],
        shipping_postal_code: shipping[:postal_code],
        shipping_country: shipping[:country]
      )

      # Create order items from cart if available
      if cart&.cart_items&.any?
        # Set branded order status if cart contains configured items
        if cart.cart_items.any?(&:configured?)
          order.update!(branded_order_status: "design_pending")
        end

        # Create order items from cart items
        cart.cart_items.includes(:product, design_attachment: :blob).each do |cart_item|
          OrderItem.create_from_cart_item(cart_item, order).save!
        end

        # Clear the cart after successful order creation
        cart.cart_items.destroy_all

        Rails.logger.info("[Stripe Webhook] Order #{order.id} created with #{order.order_items.count} items from cart")
      else
        # No cart available - order items cannot be created
        Rails.logger.warn("[Stripe Webhook] Order #{order.id} created without line items - cart not found (cart_id: #{cart_id.inspect})")
      end

      # Send confirmation email
      OrderMailer.with(order: order).confirmation_email.deliver_later

      Rails.logger.info("[Stripe Webhook] Order #{order.id} created successfully")

      # Emit webhook.processed event for successful handling
      Rails.event.notify("webhook.processed",
        event_type: event.type,
        stripe_event_id: event.id,
        order_id: order.id
      )
    rescue => e
      Rails.logger.error("[Stripe Webhook] Error creating order: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))

      # Emit webhook.failed event for debugging
      Rails.event.notify("webhook.failed",
        event_type: event.type,
        stripe_event_id: event.id,
        error: e.message
      )

      # Don't re-raise - we still return 200 to prevent Stripe retries
      # The error is logged for manual investigation
    end

    def extract_shipping_address(stripe_session)
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
  end
end
