# frozen_string_literal: true

module Webhooks
  # Handles incoming Stripe webhooks
  #
  # Endpoint: POST /webhooks/stripe
  #
  # Supported events:
  #   - invoice.paid: Creates renewal orders for subscriptions
  #   - customer.subscription.updated: Syncs subscription status
  #   - customer.subscription.deleted: Marks subscription as cancelled
  #   - invoice.payment_failed: Logs payment failures
  #
  class StripeController < ApplicationController
    skip_forgery_protection
    allow_unauthenticated_access

    # POST /webhooks/stripe
    def create
      payload = request.body.read
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

      begin
        event = verify_webhook_signature(payload, sig_header)
      rescue Stripe::SignatureVerificationError => e
        Rails.logger.error("Stripe webhook signature verification failed: #{e.message}")
        return head :bad_request
      end

      handle_event(event)
      head :ok
    end

    private

    # T043: Verify webhook signature
    def verify_webhook_signature(payload, sig_header)
      webhook_secret = Rails.application.credentials.dig(:stripe, :webhook_signing_secret)

      Stripe::Webhook.construct_event(
        payload,
        sig_header,
        webhook_secret
      )
    end

    # Route events to appropriate handlers
    def handle_event(event)
      case event["type"]
      when "invoice.paid"
        handle_invoice_paid(event["data"]["object"])
      when "customer.subscription.updated"
        handle_subscription_updated(event["data"]["object"])
      when "customer.subscription.deleted"
        handle_subscription_deleted(event["data"]["object"])
      when "invoice.payment_failed"
        handle_invoice_payment_failed(event["data"]["object"])
      else
        Rails.logger.info("Unhandled Stripe event type: #{event['type']}")
      end
    end

    # T044: Handle invoice.paid event
    #
    # Creates renewal orders for subscription cycles.
    # Skips the first invoice (subscription_create) as that order
    # is created during checkout.
    #
    def handle_invoice_paid(invoice)
      billing_reason = invoice["billing_reason"]
      invoice_id = invoice["id"]
      subscription_id = invoice["subscription"]

      # T040: Skip first invoice (created during checkout)
      if billing_reason == "subscription_create"
        Rails.logger.info("Skipping first invoice for subscription: #{subscription_id}")
        return
      end

      # Only process renewal invoices
      unless billing_reason == "subscription_cycle"
        Rails.logger.info("Skipping invoice with billing_reason: #{billing_reason}")
        return
      end

      # T045: Idempotency check - don't create duplicate orders
      if Order.exists?(stripe_invoice_id: invoice_id)
        Rails.logger.info("Order already exists for invoice: #{invoice_id}")
        return
      end

      # Find the subscription
      subscription = Subscription.find_by(stripe_subscription_id: subscription_id)
      unless subscription
        Rails.logger.error("Subscription not found for renewal: #{subscription_id}")
        return
      end

      # T046: Create renewal order from subscription snapshot
      order = create_renewal_order(subscription, invoice)

      if order
        # T051: Send email notification
        SubscriptionMailer.order_placed(order).deliver_later
        Rails.logger.info("Created renewal order #{order.id} for subscription #{subscription.id}")
      end
    end

    # T046: Create renewal order from subscription's items_snapshot
    def create_renewal_order(subscription, invoice)
      items_snapshot = subscription.items_snapshot
      items_snapshot = JSON.parse(items_snapshot) if items_snapshot.is_a?(String)

      shipping_snapshot = subscription.shipping_snapshot
      shipping_snapshot = JSON.parse(shipping_snapshot) if shipping_snapshot.is_a?(String)

      address = shipping_snapshot["address"] || {}

      # Calculate amounts from snapshot (already in minor units)
      subtotal = (items_snapshot["subtotal_minor"] || 0) / 100.0
      vat = (items_snapshot["vat_minor"] || 0) / 100.0
      shipping = (shipping_snapshot["cost_minor"] || 0) / 100.0
      total = subtotal + vat + shipping

      ActiveRecord::Base.transaction do
        order = Order.create!(
          user: subscription.user,
          subscription: subscription,
          stripe_invoice_id: invoice["id"],
          email: subscription.user.email_address,
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

        # Create order items from items_snapshot
        (items_snapshot["items"] || []).each do |item|
          variant = ProductVariant.find_by(id: item["product_variant_id"])

          OrderItem.create!(
            order: order,
            product_variant: variant,
            product: variant&.product,
            quantity: item["quantity"],
            price: item["unit_price_minor"] / 100.0,
            product_name: item["name"],
            product_sku: item["sku"],
            pac_size: item["pac_size"] || 1
          )
        end

        order
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to create renewal order: #{e.message}")
      nil
    end

    # T058-T060: Handle subscription updates from Stripe
    #
    # Syncs subscription status and billing period dates from Stripe.
    # Handles pause_collection for detecting paused state.
    #
    def handle_subscription_updated(subscription_data)
      subscription = Subscription.find_by(stripe_subscription_id: subscription_data["id"])
      unless subscription
        Rails.logger.warn("Subscription not found for update: #{subscription_data['id']}")
        return
      end

      # Map Stripe status to local status, considering pause_collection
      new_status = map_stripe_status(subscription_data)

      # Update subscription with new status and dates
      subscription.update!(
        status: new_status,
        current_period_start: Time.at(subscription_data["current_period_start"]),
        current_period_end: Time.at(subscription_data["current_period_end"])
      )

      Rails.logger.info("Subscription #{subscription.id} updated: status=#{new_status}")
    end

    # T061-T062: Handle subscription deletion (cancellation)
    #
    # Sets status to cancelled and records cancelled_at timestamp.
    #
    def handle_subscription_deleted(subscription_data)
      subscription = Subscription.find_by(stripe_subscription_id: subscription_data["id"])
      unless subscription
        Rails.logger.warn("Subscription not found for deletion: #{subscription_data['id']}")
        return
      end

      subscription.update!(
        status: "cancelled",
        cancelled_at: Time.current
      )

      Rails.logger.info("Subscription #{subscription.id} cancelled")
    end

    # T063: Handle payment failures
    #
    # Logs warning for monitoring. Future: could notify user or retry.
    #
    def handle_invoice_payment_failed(invoice)
      subscription_id = invoice["subscription"]
      attempt_count = invoice["attempt_count"]

      Rails.logger.warn(
        "Invoice payment failed: #{invoice['id']} " \
        "(subscription: #{subscription_id}, attempt: #{attempt_count})"
      )
    end

    # T060: Map Stripe subscription status to local enum
    #
    # Stripe uses pause_collection to indicate paused state while keeping
    # status as "active". We detect this and map to our "paused" status.
    #
    def map_stripe_status(subscription_data)
      stripe_status = subscription_data["status"]
      pause_collection = subscription_data["pause_collection"]

      # Stripe uses "active" with pause_collection for paused subscriptions
      if stripe_status == "active" && pause_collection.present?
        return "paused"
      end

      # Map Stripe's "canceled" to our "cancelled"
      if stripe_status == "canceled"
        return "cancelled"
      end

      # Direct mapping for other statuses (active, past_due, etc.)
      stripe_status
    end
  end
end
