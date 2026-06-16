# frozen_string_literal: true

# Register event subscribers for Rails.event
#
# The EventLogSubscriber formats events as JSON and logs them.
# When Logtail is configured, these logs are sent to Better Stack
# for structured querying and debugging.
#
# The DatafastSubscriber routes events to DataFast analytics goals.
# The KlaviyoSubscriber routes signup/order events to Klaviyo (marketing ESP).
# Both no-op gracefully until their API keys are configured in credentials.
#
# Usage in controllers/services/jobs:
#   Rails.event.notify("order.placed",
#     order_id: order.id,
#     email: order.email,
#     total: order.total_amount
#   )
#
# Future subscribers (e.g., PostHog) can be added here without
# changing any business code.

Rails.application.config.after_initialize do
  Rails.event.subscribe(EventLogSubscriber.new)
  Rails.event.subscribe(DatafastSubscriber.new)
  Rails.event.subscribe(KlaviyoSubscriber.new)
end
