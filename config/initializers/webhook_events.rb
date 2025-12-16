# frozen_string_literal: true

# Subscribe to webhook events for structured logging
#
# This initializer sets up event subscribers that log all webhook.stripe.*
# events with structured JSON payloads for easy debugging and monitoring.
#
# Events are emitted from:
#   - Webhooks::StripeController (invoice.created, invoice.paid, subscription.*, etc.)
#
# Log output example:
#   {"event":"webhook.stripe.invoice_created.shipping_added","timestamp":"2024-01-15T10:30:00.123Z",
#    "stripe_event_id":"evt_xxx","stripe_invoice_id":"in_xxx","shipping_amount":500}
#

Rails.application.config.after_initialize do
  WebhookEventSubscriber.subscribe!
end
