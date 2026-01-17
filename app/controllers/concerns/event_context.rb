# frozen_string_literal: true

# Sets request-scoped context for all Rails.event events.
#
# Context is attached to every event emitted during a request,
# enabling correlation of related events in Logtail.
#
# Example query: Find all events for a specific request
#   context.request_id:abc-123-def-456
#
# Context fields:
#   - request_id: Rails request UUID (always present)
#   - user_id: Current user ID (nil for guests)
#   - session_id: Current session ID (nil for unauthenticated)
#
module EventContext
  extend ActiveSupport::Concern

  included do
    before_action :set_event_context
  end

  private

  def set_event_context
    Rails.event.set_context(
      request_id: request.request_id,
      user_id: Current.user&.id,
      session_id: Current.session&.id
    )
  end
end
