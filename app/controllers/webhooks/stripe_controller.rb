module Webhooks
  class StripeController < ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection

    # Wraps a transient order-creation failure so `create` returns 5xx and Stripe
    # retries, instead of swallowing it as 200 and losing a paid order.
    class RetryableWebhookError < StandardError; end

    # Raised when the session can never produce a valid order (e.g. no shipping
    # details), so `create` returns 200 and Stripe does NOT retry a doomed payload.
    class PermanentlyInvalidSessionError < StandardError; end

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
    rescue RetryableWebhookError
      # A transient failure while handling the event. Return 5xx so Stripe retries
      # rather than silently dropping a paid order. Already logged/Sentry'd below.
      head :internal_server_error
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
      # "paid" or, for a fully-discounted (0-total) order, "no_payment_required".
      return unless Checkout::COMPLETED_PAYMENT_STATUSES.include?(session.payment_status)

      # Check if order already exists (created by success redirect)
      existing_order = Order.find_by(stripe_session_id: session.id)
      if existing_order
        Rails.logger.info("[Stripe Webhook] Order already exists for session #{session.id}")
        return
      end

      # Order doesn't exist - this means the success redirect failed
      # We need to create the order from the webhook
      Rails.logger.info("[Stripe Webhook] Creating order for session #{session.id} (redirect missed)")

      # Retrieve full session with expanded data. The nested price.product is
      # needed so SessionAmounts can identify the shipping line by its metadata.
      full_session = Stripe::Checkout::Session.retrieve(
        id: session.id,
        # total_details.breakdown is omitted unless expanded, and without it the
        # discount breakdown is nil, so the promotion code cannot be read and the
        # order records no discount_code.
        expand: [ "collected_information", "line_items.data.price.product",
                 "payment_intent.payment_method", "total_details.breakdown" ]
      )

      # Extract shipping address
      shipping = Checkout::SessionDetails.shipping_address(full_session)

      # Guard the permanent failure upstream (as OrderCreator does on the success
      # path): a completed session with no shipping_details would build an order with
      # nil required shipping fields and raise RecordInvalid. That can never succeed
      # on retry, so fail it as permanent here rather than letting it look like a
      # transient (retryable) RecordInvalid from an item rollback.
      if Order.required_shipping_values(shipping).any?(&:blank?)
        raise PermanentlyInvalidSessionError, "session #{full_session.id} has no shipping details"
      end

      # SessionBuilder stamps every website session with its cart_id, so a
      # session without one was completed by an AI agent through Stripe
      # Agentic Commerce: there is no cart, and the items come from the
      # session's line items instead.
      cart_id = full_session.metadata&.[]("cart_id")
      order =
        if cart_id.present?
          create_web_order(full_session, cart_id)
        else
          Rails.logger.info("[Stripe Webhook] Creating agent order for session #{session.id}")
          Checkout::AgentOrderCreator.new(stripe_session: full_session).create
        end

      # Send confirmation email (customer + internal ops copy)
      OrderMailer.with(order: order).confirmation_email.deliver_later
      OrderMailer.with(order: order).ops_confirmation_email.deliver_later

      # Notify the team in Telegram that a new order has been placed
      TelegramOrderNotificationJob.perform_later(order.id)

      # Track purchase server-side via GA4 Measurement Protocol
      # This ensures the purchase is recorded even if the client-side event never fires
      Ga4MeasurementProtocolService.track_purchase(order)

      Rails.logger.info("[Stripe Webhook] Order #{order.id} created successfully")

      # Emit checkout.completed event for Datafast conversion tracking
      # The visitor ID was captured at checkout creation and stored in Stripe metadata
      emit_checkout_completed_event(order, full_session)

      # The Klaviyo "Placed Order" event rides order.placed, which the success
      # redirect emits for website orders. An agent order has no redirect, so
      # the webhook is its only chance to reach Klaviyo.
      emit_order_placed_event(order) if order.agent?

      # Emit webhook.processed event for successful handling
      Rails.event.notify("webhook.processed",
        event_type: event.type,
        stripe_event_id: event.id,
        order_id: order.id
      )
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      # Lost the create race: the success redirect committed the order in the window
      # after our find_by check. Benign and idempotent - the order exists - so log
      # and return 200 (no Stripe retry needed). If no order exists, this was a real
      # failure (e.g. an item rolled the transaction back), so treat it as retryable.
      unless Order.exists?(stripe_session_id: session.id)
        Sentry.capture_exception(e, extra: { stripe_session_id: session.id })
        Rails.event.notify("webhook.failed", event_type: event.type, stripe_event_id: event.id, error: e.message)
        raise RetryableWebhookError, e.message
      end

      Rails.logger.info("[Stripe Webhook] Order already created concurrently for session #{session.id}")
      Rails.event.notify("webhook.processed", event_type: event.type, stripe_event_id: event.id)
    rescue PermanentlyInvalidSessionError, Checkout::SessionAmounts::UnexpandedLineItemError,
           Checkout::AgentOrderCreator::UnknownSkuError => e
      # The session can never produce a valid order on retry, for one of two reasons:
      #   - PermanentlyInvalidSessionError: a completed session carrying no
      #     shipping_details, so the required shipping fields would be nil.
      #   - UnexpandedLineItemError: a dropped expand (programmer error) means the
      #     shipping line can't be identified; the same payload will fail identically.
      #   - UnknownSkuError: an agent paid for a SKU that is not in the catalogue;
      #     the product will not appear on retry, so ops must see it in Sentry now.
      # Either way retrying can never succeed, so capture it for investigation and
      # return 200 to stop Stripe retrying for 72h and flooding Sentry. Both are
      # raised before/while deriving amounts, never from a transient item-level
      # RecordInvalid that rolls the transaction back (that path stays retryable).
      # The success controller rescues UnexpandedLineItemError the same way, so the
      # two order-creation paths don't diverge on this error.
      Rails.logger.error("[Stripe Webhook] Session permanently invalid for #{session.id}: #{e.message}")
      Sentry.capture_exception(e, extra: { stripe_session_id: session.id })
      Rails.event.notify("webhook.failed", event_type: event.type, stripe_event_id: event.id, error: e.message)
    rescue => e
      Rails.logger.error("[Stripe Webhook] Error creating order: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))
      Sentry.capture_exception(e, extra: { stripe_session_id: session.id })

      Rails.event.notify("webhook.failed",
        event_type: event.type,
        stripe_event_id: event.id,
        error: e.message
      )

      # Signal the controller to return 5xx so Stripe retries the event. A transient
      # failure (DB blip, Stripe error) must not be swallowed as 200 - that would
      # lose a paid order with no retry. The race (handled above) is the only case
      # where returning 200 on an exception is correct.
      raise RetryableWebhookError, e.message
    end

    # A website order whose success redirect never ran: rebuild it from the
    # cart the session was created for. Returns the persisted Order.
    def create_web_order(full_session, cart_id)
      # Get user if client_reference_id was set
      user = User.find_by(id: full_session.client_reference_id)

      # Try to get cart from metadata (added to checkout session for webhook fallback)
      cart = Cart.find_by(id: cart_id)

      # Use Stripe session amounts as source of truth (handles discounts
      # correctly). SessionAmounts splits shipping back out of the subtotal, since
      # shipping now rides as a taxed line item rather than a shipping_option.
      amounts = Checkout::SessionAmounts.from(full_session)
      subtotal = amounts.subtotal
      vat_amount = amounts.vat
      discount_amount = amounts.discount
      shipping_amount = amounts.shipping
      total_amount = amounts.total
      discount_code = full_session.metadata&.[]("discount_code")
      if discount_code.blank?
        discount_code = webhook_promotion_code(full_session)
      end

      # Create the order and its items atomically: a mid-loop item failure must
      # not leave a committed paid order with missing items. Cart clearing stays
      # in the transaction so it only happens once the items are safely persisted.
      ApplicationRecord.transaction do
        new_order = Order.create!(
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
          discount_amount: discount_amount,
          discount_code: discount_code.presence,
          branded_order_status: (cart&.cart_items&.any?(&:configured?) ? "design_pending" : nil),
          # Both addresses come from the shared mapping (billing fails open to
          # nils); OrderCreator on the success path merges the same call so the
          # two can't drift.
          **Checkout::SessionDetails.order_address_attributes(full_session),
          # The zone the order was priced against (see SessionDetails), not the
          # zone of the collected address, so the order records what was charged.
          shipping_zone: Checkout::SessionDetails.shipping_zone(full_session)
        )

        if cart&.cart_items&.any?
          cart.cart_items.includes(:product, design_attachment: :blob).each do |cart_item|
            OrderItem.build_from_cart_item(cart_item, new_order).save!
          end
          cart.cart_items.destroy_all
          Rails.logger.info("[Stripe Webhook] Order #{new_order.id} created with #{new_order.order_items.count} items from cart")
        else
          # No cart available - order items cannot be created
          Rails.logger.warn("[Stripe Webhook] Order #{new_order.id} created without line items - cart not found (cart_id: #{cart_id.inspect})")
        end

        new_order
      end
    end

    def emit_order_placed_event(order)
      Rails.event.notify("order.placed",
        order_id: order.id,
        email: order.email,
        total: order.total_amount.to_f,
        item_count: order.order_items.count,
        has_discount: order.discount_code.present?,
        source: order.source
      )
    end

    # The Stripe-entered promotion code, or nil. Unlike OrderCreator (which lets an
    # unexpected discount shape surface), the webhook swallows a NoMethodError: a
    # malformed cosmetic field must not fail an already-paid order and trigger 72h of
    # Stripe retries. The traversal itself lives in Checkout::SessionDetails so the
    # two paths read the session identically.
    def webhook_promotion_code(stripe_session)
      Checkout::SessionDetails.promotion_code(stripe_session)
    rescue NoMethodError
      nil
    end

    # Emits checkout.completed event with Datafast visitor ID from Stripe metadata.
    # This ensures conversion attribution works even when webhook beats the redirect.
    def emit_checkout_completed_event(order, stripe_session)
      visitor_id = stripe_session.metadata&.[]("datafast_visitor_id")
      return unless visitor_id.present?

      # Set context manually since webhooks don't have browser cookies
      Rails.event.set_context(
        request_id: request.request_id,
        datafast_visitor_id: visitor_id,
        datafast_session_id: stripe_session.metadata&.[]("datafast_session_id")
      )

      Rails.event.notify("checkout.completed",
        order_id: order.id,
        total: order.total_amount.to_f,
        payment_method: Checkout::SessionDetails.payment_method_type(stripe_session)
      )
    end
  end
end
