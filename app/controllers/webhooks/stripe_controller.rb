module Webhooks
  # The webhook completion channel (see CONTEXT.md: Checkout completion). It
  # verifies Stripe's signature, hands the session to Checkout::Completion with
  # no browser present, and answers with the status Stripe acts on: 200 stops
  # retries, 5xx asks for one. What a completion does, and the Sentry report
  # when it fails, live in the module; this controller adds only its own
  # webhook.* tracing events.
  class StripeController < ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection

    # Wraps a transient failure so `create` returns 5xx and Stripe retries,
    # instead of swallowing it as 200 and losing a paid order.
    class RetryableWebhookError < StandardError; end

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
      # rather than silently dropping a paid order. Already reported below.
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
      session_id = event.data.object.id
      outcome = Checkout::Completion.complete(session_id, browser_present: false)

      if outcome.created?
        Rails.logger.info("[Stripe Webhook] Order #{outcome.order.id} created for session #{session_id} (redirect missed)")
      elsif outcome.existing?
        Rails.logger.info("[Stripe Webhook] Order already exists for session #{session_id}")
      else
        Rails.logger.info("[Stripe Webhook] Session #{session_id} is not paid; nothing to complete")
      end

      Rails.event.notify("webhook.processed",
        { event_type: event.type, stripe_event_id: event.id, order_id: outcome.order&.id }.compact
      )
    rescue Checkout::PermanentCompletionFailure => e
      # The same payload fails identically on every retry, so answer 200 and stop
      # Stripe retrying for 72h. Completion has already captured it for review.
      Rails.logger.error("[Stripe Webhook] Session permanently invalid for #{session_id}: #{e.message}")
      report_failure(event, e)
    rescue Checkout::TransientCompletionFailure => e
      # Already captured by Completion; ask Stripe to retry.
      report_failure(event, e)
      raise RetryableWebhookError, e.message
    rescue => e
      # Anything Completion did not classify. Never swallow it as 200: that would
      # lose a paid order with no retry.
      Rails.logger.error("[Stripe Webhook] Error completing session #{session_id}: #{e.message}")
      Rails.logger.error(e.backtrace.first(10).join("\n"))
      Sentry.capture_exception(e, extra: { stripe_session_id: session_id })
      report_failure(event, e)
      raise RetryableWebhookError, e.message
    end

    def report_failure(event, error)
      Rails.event.notify("webhook.failed",
        event_type: event.type,
        stripe_event_id: event.id,
        error: error.message
      )
    end
  end
end
