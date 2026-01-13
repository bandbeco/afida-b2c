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

      handle_event(event)
      head :ok
    end

    private

    def handle_event(event)
      case event.type
      when "checkout.session.completed"
        handle_checkout_completed(event.data.object)
      else
        Rails.logger.info("[Stripe Webhook] Unhandled event type: #{event.type}")
      end
    end

    def handle_checkout_completed(session)
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

      # Calculate amounts from line items
      line_items = full_session.line_items.data
      subtotal = line_items.sum { |item| item.amount_total } / 100.0

      # Get shipping and tax amounts
      shipping_amount = full_session.shipping_cost&.amount_total.to_i / 100.0
      tax_amount = full_session.total_details&.amount_tax.to_i / 100.0
      total_amount = full_session.amount_total / 100.0

      order = Order.create!(
        user: user,
        organization: user&.organization,
        placed_by_user: user&.organization_id? ? user : nil,
        email: full_session.customer_details&.email,
        stripe_session_id: full_session.id,
        status: "paid",
        subtotal_amount: subtotal - tax_amount, # Stripe includes tax in line item amounts
        vat_amount: tax_amount,
        shipping_amount: shipping_amount,
        total_amount: total_amount,
        shipping_name: shipping[:name],
        shipping_address_line1: shipping[:line1],
        shipping_address_line2: shipping[:line2],
        shipping_city: shipping[:city],
        shipping_postal_code: shipping[:postal_code],
        shipping_country: shipping[:country]
      )

      # Note: We cannot recreate OrderItems from Stripe line items alone
      # as we don't have the original cart data. The order total is accurate,
      # but line item details would need manual reconciliation.
      Rails.logger.warn("[Stripe Webhook] Order #{order.id} created without line items - manual review needed")

      # Send confirmation email
      OrderMailer.with(order: order).confirmation_email.deliver_later

      Rails.logger.info("[Stripe Webhook] Order #{order.id} created successfully")
    rescue => e
      Rails.logger.error("[Stripe Webhook] Error creating order: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))
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
