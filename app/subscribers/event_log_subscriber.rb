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
  def emit(event)
    Rails.logger.info(format_event(event))
  end

  private

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
