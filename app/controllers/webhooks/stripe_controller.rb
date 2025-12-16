# frozen_string_literal: true

module Webhooks
  # Handles incoming Stripe webhooks
  #
  # Endpoint: POST /webhooks/stripe
  #
  # Supported events:
  #   - invoice.created: Adds shipping line item to draft invoices for renewals
  #   - invoice.paid: Creates renewal orders for subscriptions
  #   - customer.subscription.updated: Syncs subscription status
  #   - customer.subscription.deleted: Marks subscription as cancelled
  #   - invoice.payment_failed: Logs payment failures
  #
  # KNOWN LIMITATION: Subscription Item Changes
  #   If a customer modifies their subscription items via Stripe's Customer Portal
  #   or Dashboard (add/remove products, change quantities), our items_snapshot
  #   will NOT be updated. Renewal orders will continue to use the original
  #   items_snapshot until the customer creates a new subscription.
  #
  #   To support subscription item modifications, implement:
  #   1. Handle 'customer.subscription.updated' to detect item changes
  #   2. Compare invoice line_items with items_snapshot
  #   3. Update items_snapshot when differences are detected
  #
  #   For now, item modifications are only supported by cancelling and
  #   creating a new subscription.
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
        Rails.event.notify("webhook.stripe.signature_failed", { error: e.message })
        return head :bad_request
      end

      # Set context for all events during this webhook request (Rails 8.1 structured events)
      # Context is automatically cleared after the request
      Rails.event.set_context(
        stripe_event_id: event["id"],
        stripe_event_type: event["type"]
      )

      Rails.event.notify("webhook.stripe.received")

      handle_event(event)
      head :ok
    end

    private

    # T043: Verify webhook signature
    #
    # SECURITY: Raises if webhook_signing_secret is not configured.
    # Without a secret, signature verification cannot work and webhooks
    # could be forged by anyone.
    #
    def verify_webhook_signature(payload, sig_header)
      webhook_secret = Rails.application.credentials.dig(:stripe, :webhook_signing_secret)

      if webhook_secret.blank?
        Rails.logger.error("[SECURITY] Stripe webhook_signing_secret not configured - rejecting all webhooks")
        raise Stripe::SignatureVerificationError.new(
          "Webhook signing secret not configured",
          sig_header
        )
      end

      Stripe::Webhook.construct_event(
        payload,
        sig_header,
        webhook_secret
      )
    end

    # Route events to appropriate handlers
    def handle_event(event)
      case event["type"]
      when "invoice.created"
        handle_invoice_created(event["data"]["object"])
      when "invoice.paid"
        handle_invoice_paid(event["data"]["object"])
      when "customer.subscription.updated"
        handle_subscription_updated(event["data"]["object"])
      when "customer.subscription.deleted"
        handle_subscription_deleted(event["data"]["object"])
      when "invoice.payment_failed"
        handle_invoice_payment_failed(event["data"]["object"])
      else
        Rails.event.notify("webhook.stripe.unhandled")
      end
    end

    # Handle invoice.created event
    #
    # Adds shipping line item to draft invoices for subscription renewals.
    # This ensures customers are charged for shipping on each renewal based
    # on the FREE_SHIPPING_THRESHOLD (orders >= £100 get free shipping).
    #
    # Stripe creates invoices in "draft" status, giving us time to add
    # line items before the invoice is finalized and charged.
    #
    # Skips:
    #   - First invoice (subscription_create) - shipping handled in checkout
    #   - Non-subscription invoices
    #   - Subscriptions not in our database
    #
    def handle_invoice_created(invoice)
      billing_reason = invoice["billing_reason"]
      invoice_id = invoice["id"]
      subscription_id = invoice["subscription"]
      customer_id = invoice["customer"]

      Rails.event.set_context(
        stripe_invoice_id: invoice_id,
        stripe_subscription_id: subscription_id,
        billing_reason: billing_reason
      )

      # Skip first invoice (shipping handled during checkout)
      if billing_reason == "subscription_create"
        Rails.event.notify("webhook.stripe.invoice_created.skipped", { reason: "first_invoice" })
        return
      end

      # Only process subscription renewal invoices
      unless subscription_id.present?
        Rails.event.notify("webhook.stripe.invoice_created.skipped", { reason: "non_subscription" })
        return
      end

      # Find subscription in our database
      subscription = Subscription.find_by(stripe_subscription_id: subscription_id)
      unless subscription
        Rails.event.notify("webhook.stripe.invoice_created.skipped", { reason: "subscription_not_found" })
        return
      end

      # Calculate shipping based on items_snapshot subtotal
      items_snapshot = subscription.items_snapshot
      items_snapshot = JSON.parse(items_snapshot) if items_snapshot.is_a?(String)

      subtotal_pounds = (items_snapshot["subtotal_minor"] || 0) / Currency::MINOR_UNIT_MULTIPLIER.to_f
      shipping_cost_minor = Shipping.cost_for_subtotal(subtotal_pounds)

      # Add shipping line item if not free
      if shipping_cost_minor > 0
        Stripe::InvoiceItem.create(
          customer: customer_id,
          invoice: invoice_id,
          amount: shipping_cost_minor,
          currency: Shipping::CURRENCY,
          description: "Standard Shipping"
        )

        Rails.event.notify("webhook.stripe.invoice_created.shipping_added", {
          subscription_id: subscription.id,
          shipping_amount: shipping_cost_minor
        })
      else
        Rails.event.notify("webhook.stripe.invoice_created.free_shipping", {
          subscription_id: subscription.id,
          subtotal: subtotal_pounds
        })
      end
    rescue Stripe::StripeError => e
      # Log error but don't fail the webhook - Stripe will retry
      Rails.event.notify("webhook.stripe.invoice_created.error", {
        error: e.message,
        subscription_id: subscription&.id
      })
      Sentry.capture_exception(e, extra: {
        invoice_id: invoice_id,
        subscription_id: subscription_id
      })
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

      # Add invoice context to all subsequent events
      Rails.event.set_context(
        stripe_invoice_id: invoice_id,
        stripe_subscription_id: subscription_id,
        billing_reason: billing_reason
      )

      # T040: Skip first invoice (created during checkout)
      if billing_reason == "subscription_create"
        Rails.event.notify("webhook.stripe.invoice.skipped", { reason: "first_invoice" })
        return
      end

      # Only process renewal invoices
      unless billing_reason == "subscription_cycle"
        Rails.event.notify("webhook.stripe.invoice.skipped", { reason: "non_renewal" })
        return
      end

      # T045: Idempotency check - don't create duplicate orders
      if Order.exists?(stripe_invoice_id: invoice_id)
        Rails.event.notify("webhook.stripe.invoice.skipped", { reason: "duplicate" })
        return
      end

      # Find the subscription
      subscription = Subscription.find_by(stripe_subscription_id: subscription_id)
      unless subscription
        Rails.event.notify("webhook.stripe.subscription_not_found")
        return
      end

      # T046: Create renewal order from subscription snapshot
      order = create_renewal_order(subscription, invoice)

      if order
        # T051: Send email notification
        SubscriptionMailer.order_placed(order).deliver_later
        Rails.event.notify("webhook.stripe.renewal_order.created", {
          order_id: order.id,
          subscription_id: subscription.id
        })
      end
    end

    # T046: Create renewal order from subscription's items_snapshot
    #
    # Recalculates shipping for each renewal based on the FREE_SHIPPING_THRESHOLD:
    # - Orders >= £100 subtotal: Free shipping
    # - Orders < £100 subtotal: Standard shipping (£5)
    #
    def create_renewal_order(subscription, invoice)
      items_snapshot = subscription.items_snapshot
      items_snapshot = JSON.parse(items_snapshot) if items_snapshot.is_a?(String)

      shipping_snapshot = subscription.shipping_snapshot
      shipping_snapshot = JSON.parse(shipping_snapshot) if shipping_snapshot.is_a?(String)

      address = shipping_snapshot["address"] || {}

      # Calculate amounts from snapshot (already in minor units)
      subtotal = (items_snapshot["subtotal_minor"] || 0) / Currency::MINOR_UNIT_MULTIPLIER.to_f
      vat = (items_snapshot["vat_minor"] || 0) / Currency::MINOR_UNIT_MULTIPLIER.to_f

      # Recalculate shipping based on current subtotal to apply free shipping threshold
      # This ensures orders >= £100 get free shipping on every renewal
      shipping_cost_minor = Shipping.cost_for_subtotal(subtotal)
      shipping = shipping_cost_minor / Currency::MINOR_UNIT_MULTIPLIER.to_f
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

          # Emit warning if variant was deleted but proceed with order creation
          # Items snapshot has all needed data (name, sku, price, pac_size)
          if variant.nil?
            Rails.event.notify("webhook.stripe.variant_not_found", {
              variant_id: item["product_variant_id"],
              variant_name: item["name"]
            })
          end

          OrderItem.create!(
            order: order,
            product_variant: variant,
            product: variant&.product,
            quantity: item["quantity"],
            price: item["unit_price_minor"] / Currency::MINOR_UNIT_MULTIPLIER.to_f,
            product_name: item["name"],
            product_sku: item["sku"],
            pac_size: item["pac_size"] || 1
          )
        end

        order
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.event.notify("webhook.stripe.renewal_order.failed", {
        subscription_id: subscription.id,
        invoice_id: invoice["id"],
        error: e.message
      })
      # Alert monitoring - this is a critical failure that loses revenue
      Sentry.capture_exception(e, extra: {
        subscription_id: subscription.id,
        invoice_id: invoice["id"],
        items_snapshot: subscription.items_snapshot
      })
      nil
    end

    # T058-T060: Handle subscription updates from Stripe
    #
    # Syncs subscription status and billing period dates from Stripe.
    # Handles pause_collection for detecting paused state.
    #
    def handle_subscription_updated(subscription_data)
      Rails.event.set_context(stripe_subscription_id: subscription_data["id"])

      subscription = Subscription.find_by(stripe_subscription_id: subscription_data["id"])
      unless subscription
        Rails.event.notify("webhook.stripe.subscription_not_found")
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

      Rails.event.notify("webhook.stripe.subscription.updated", {
        subscription_id: subscription.id,
        new_status: new_status
      })
    end

    # T061-T062: Handle subscription deletion (cancellation)
    #
    # Sets status to cancelled and records cancelled_at timestamp.
    #
    def handle_subscription_deleted(subscription_data)
      Rails.event.set_context(stripe_subscription_id: subscription_data["id"])

      subscription = Subscription.find_by(stripe_subscription_id: subscription_data["id"])
      unless subscription
        Rails.event.notify("webhook.stripe.subscription_not_found")
        return
      end

      subscription.update!(
        status: "cancelled",
        cancelled_at: Time.current
      )

      Rails.event.notify("webhook.stripe.subscription.cancelled", {
        subscription_id: subscription.id
      })
    end

    # T063: Handle payment failures
    #
    # Logs warning and alerts monitoring. Stripe handles retries automatically.
    # Future: could notify user via email.
    #
    def handle_invoice_payment_failed(invoice)
      subscription_id = invoice["subscription"]
      attempt_count = invoice["attempt_count"]

      Rails.event.set_context(
        stripe_invoice_id: invoice["id"],
        stripe_subscription_id: subscription_id,
        attempt_count: attempt_count
      )

      Rails.event.notify("webhook.stripe.payment.failed", {
        customer_id: invoice["customer"]
      })

      # Alert on final attempt failures (Stripe default is 4 attempts)
      if attempt_count >= 3
        Sentry.capture_message(
          "Subscription payment failing repeatedly",
          level: :warning,
          extra: {
            invoice_id: invoice["id"],
            subscription_id: subscription_id,
            attempt_count: attempt_count,
            customer_id: invoice["customer"]
          }
        )
      end
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
