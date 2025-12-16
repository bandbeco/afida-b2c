# frozen_string_literal: true

# Subscribes to webhook.stripe.* events and logs them with structured data.
#
# Uses Rails 8.1's native EventReporter API. Subscribers must implement #emit
# to receive events. This subscriber logs all webhook events with JSON-formatted
# payloads for easy parsing by log aggregators.
#
# Event naming convention:
#   webhook.stripe.<handler>.<outcome>
#
# Examples:
#   webhook.stripe.received                    - Webhook received (before routing)
#   webhook.stripe.invoice_created.shipping_added - Shipping line item added
#   webhook.stripe.invoice_created.skipped     - Invoice skipped (with reason)
#   webhook.stripe.renewal_order.created       - Renewal order created
#   webhook.stripe.renewal_order.failed        - Renewal order creation failed
#
# See: https://edgeapi.rubyonrails.org/classes/ActiveSupport/EventReporter.html
#
class WebhookEventSubscriber
  # Log levels for different event types
  EVENT_LOG_LEVELS = {
    # Informational events
    "webhook.stripe.received" => :info,
    "webhook.stripe.unhandled" => :info,
    "webhook.stripe.invoice_created.skipped" => :info,
    "webhook.stripe.invoice_created.free_shipping" => :info,
    "webhook.stripe.invoice_created.shipping_added" => :info,
    "webhook.stripe.invoice.skipped" => :info,
    "webhook.stripe.subscription.updated" => :info,
    "webhook.stripe.subscription.cancelled" => :info,
    "webhook.stripe.renewal_order.created" => :info,

    # Warning events
    "webhook.stripe.signature_failed" => :warn,
    "webhook.stripe.subscription_not_found" => :warn,
    "webhook.stripe.variant_not_found" => :warn,
    "webhook.stripe.payment.failed" => :warn,

    # Error events
    "webhook.stripe.invoice_created.error" => :error,
    "webhook.stripe.renewal_order.failed" => :error
  }.freeze

  class << self
    def subscribe!
      # Rails 8.1+ uses Rails.event.subscribe with a subscriber object
      # that implements #emit
      Rails.event.subscribe(new)
    end
  end

  # Rails 8.1 EventReporter calls this method for each event
  #
  # Event structure:
  #   {
  #     name: "webhook.stripe.received",
  #     payload: { ... },
  #     context: { stripe_event_id: "evt_xxx", ... },
  #     tags: [],
  #     timestamp: Time,
  #     source_location: { filepath: "...", lineno: 123 }
  #   }
  #
  def emit(event)
    event_name = event[:name]

    # Only handle webhook.stripe.* events
    return unless event_name&.start_with?("webhook.stripe.")

    payload = event[:payload] || {}
    context = event[:context] || {}
    raw_timestamp = event[:timestamp]
    timestamp = parse_timestamp(raw_timestamp)

    log_level = EVENT_LOG_LEVELS[event_name] || :debug

    # Build structured log entry
    log_entry = build_log_entry(event_name, payload, context, timestamp)

    # Log with appropriate level
    Rails.logger.public_send(log_level, log_entry.to_json)

    # Also send to Sentry breadcrumbs for error correlation
    add_sentry_breadcrumb(event_name, payload, context, log_level)
  end

  private

  def build_log_entry(event_name, payload, context, timestamp)
    {
      event: event_name,
      timestamp: timestamp.iso8601(3),

      # Stripe identifiers from context (set via Rails.event.set_context)
      stripe_event_id: context[:stripe_event_id],
      stripe_event_type: context[:stripe_event_type],
      stripe_invoice_id: context[:stripe_invoice_id],
      stripe_subscription_id: context[:stripe_subscription_id],
      billing_reason: context[:billing_reason],

      # Event-specific payload
      **payload.except(:exception, :exception_object)
    }.compact
  end

  def parse_timestamp(raw_timestamp)
    if raw_timestamp.is_a?(Time) || raw_timestamp.is_a?(DateTime) || raw_timestamp.is_a?(ActiveSupport::TimeWithZone)
      raw_timestamp
    elsif raw_timestamp.is_a?(Integer) || raw_timestamp.is_a?(Float)
      Time.at(raw_timestamp)
    else
      Time.current
    end
  end

  def add_sentry_breadcrumb(event_name, payload, context, log_level)
    return unless defined?(Sentry) && Sentry.initialized?

    sentry_level = { error: "error", warn: "warning" }.fetch(log_level, "info")

    Sentry.add_breadcrumb(
      Sentry::Breadcrumb.new(
        category: "webhook.stripe",
        message: event_name,
        level: sentry_level,
        data: {
          stripe_event_id: context[:stripe_event_id],
          stripe_invoice_id: context[:stripe_invoice_id],
          stripe_subscription_id: context[:stripe_subscription_id],
          **payload.slice(:reason, :error, :subscription_id, :order_id, :shipping_amount)
        }.compact
      )
    )
  end
end
