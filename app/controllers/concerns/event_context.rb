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
#   - datafast_visitor_id: DataFast visitor ID from cookie (for analytics)
#   - datafast_session_id: DataFast session ID from cookie (for analytics)
#
module EventContext
  extend ActiveSupport::Concern

  # Matches the Datafa.st script's own cookie lifetime (365 days) so a visitor
  # is recognised across sessions.
  DATAFAST_VISITOR_COOKIE_MAX_AGE = 365.days

  included do
    before_action :ensure_datafast_visitor_id
    before_action :set_event_context
  end

  private

  # Guarantees a first-party datafast_visitor_id cookie on every request.
  #
  # Datafa.st's tracking script is meant to set this cookie, but it does not do
  # so reliably on this site, which left it blank and caused every conversion
  # goal to be dropped. We mint our own UUID when absent. The Datafa.st script
  # reads an existing datafast_visitor_id cookie before generating its own, so
  # setting it here means Datafa.st adopts the same id for its pageview and both
  # sides agree, making goal attribution work.
  #
  # An existing value (including one Datafa.st set first) is always preserved.
  def ensure_datafast_visitor_id
    return if cookies[:datafast_visitor_id].present?

    cookies[:datafast_visitor_id] = {
      value: SecureRandom.uuid,
      expires: DATAFAST_VISITOR_COOKIE_MAX_AGE.from_now,
      same_site: :lax
    }
  end

  def set_event_context
    Rails.event.set_context(
      request_id: request.request_id,
      user_id: Current.user&.id,
      session_id: Current.session&.id,
      datafast_visitor_id: cookies[:datafast_visitor_id],
      datafast_session_id: cookies[:datafast_session_id]
    )
  end
end
