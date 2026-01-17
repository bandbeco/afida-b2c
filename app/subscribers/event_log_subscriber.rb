# frozen_string_literal: true

# Subscriber that formats Rails.event events and logs them to Logtail
# for structured querying and debugging.
#
# Events are formatted as JSON with a consistent structure:
#   - event: The event name (e.g., "order.placed")
#   - payload: Event-specific data
#   - context: Request-scoped metadata (request_id, user_id, session_id)
#   - tags: Optional domain tags
#   - timestamp: Nanosecond Unix timestamp
#   - source_location: File/line/method where event was emitted
#
# Query in Logtail:
#   event:order.placed
#   payload.email:customer@example.com
#   context.request_id:abc-123
#
class EventLogSubscriber
  # Only log our custom business events, not Rails framework events.
  # Rails 8.1 emits many internal events (action_controller.*, action_view.*, etc.)
  # that would create excessive noise.
  BUSINESS_EVENT_PREFIXES = %w[
    cart.
    checkout.
    email_signup.
    order.
    payment.
    pending_order.
    reorder.
    webhook.
  ].freeze

  def emit(event)
    return unless business_event?(event[:name])

    Rails.logger.info(format_event(event))
  end

  private

  def business_event?(event_name)
    BUSINESS_EVENT_PREFIXES.any? { |prefix| event_name.start_with?(prefix) }
  end

  def format_event(event)
    {
      event: event[:name],
      payload: event[:payload],
      context: event[:context],
      tags: event[:tags],
      timestamp: event[:timestamp],
      source_location: event[:source_location]
    }.to_json
  end
end
