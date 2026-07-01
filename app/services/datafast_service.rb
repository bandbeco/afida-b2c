# frozen_string_literal: true

require "http"

# Sends custom goal events to DataFast analytics API.
#
# Goals enable revenue attribution by linking visitor sessions to conversions.
# Requires the visitor to have at least one pageview before a goal can be recorded.
#
# API Reference: https://datafa.st/docs/api-create-goal
#
# Usage:
#   DatafastService.track("add_to_cart", visitor_id: "abc123", metadata: { product_id: 1 })
#
class DatafastService
  ENDPOINT = "https://datafa.st/api/v1/goals"
  VISITOR_ENDPOINT = "https://datafa.st/api/v1/visitors"
  TIMEOUT_SECONDS = 5
  MAX_METADATA_KEYS = 10

  # How long to remember that a visitor has (or lacks) a recorded pageview, so
  # the several goals fired during one shopping session cost a single lookup.
  VISITOR_VERDICT_TTL = 30.minutes

  class << self
    # Tracks a goal event with DataFast
    # @param name [String] Goal name (e.g., "add_to_cart", "purchase")
    # @param visitor_id [String] DataFast visitor ID from cookie
    # @param metadata [Hash] Optional metadata (max 10 key-value pairs)
    # @return [Boolean] true if successful, false otherwise
    def track(name, visitor_id:, metadata: {})
      new(name, visitor_id: visitor_id, metadata: metadata).track
    end
  end

  def initialize(name, visitor_id:, metadata: {})
    @name = sanitize_goal_name(name)
    @visitor_id = visitor_id
    @metadata = sanitize_metadata(metadata)
  end

  def track
    if @visitor_id.blank?
      log_error("visitor_id is blank")
      return false
    end

    unless api_key_configured?
      log_error("API key not configured in credentials")
      return false
    end

    # DataFast rejects goals for visitors it has no recorded pageview for (bots,
    # JS-blocked clients, server-only requests) with a 404. Skip those instead
    # of firing into a guaranteed error. Fails open: any uncertainty fires the
    # goal so we never drop a real conversion over a flaky lookup.
    unless visitor_has_pageviews?
      log_skipped("visitor has no recorded pageviews")
      return false
    end

    send_goal
  rescue HTTP::Error, HTTP::TimeoutError => e
    log_error("HTTP error: #{e.class} - #{e.message}")
    false
  rescue StandardError => e
    log_error("Unexpected error: #{e.class} - #{e.message}")
    false
  end

  private

  def send_goal
    response = HTTP
      .auth("Bearer #{api_key}")
      .timeout(TIMEOUT_SECONDS)
      .post(ENDPOINT, json: payload)

    if response.status.success?
      log_success
      true
    else
      log_error("API returned #{response.status}: #{response.body}")
      false
    end
  end

  # True if DataFast has at least one recorded pageview for this visitor.
  #
  # DataFast only records a visitor when its client-side script runs in a real
  # browser (it silently ignores bots and blocked clients), so a present cookie
  # does not guarantee DataFast knows the visitor. GET /visitors/:id returns 200
  # when it does and 404 when it does not. The verdict is cached per visitor so
  # the several goals in one session share a single lookup.
  #
  # Fails open: on any error (timeout, network, unexpected status) we return
  # true so the goal still fires rather than silently dropping a real event.
  def visitor_has_pageviews?
    Rails.cache.fetch(visitor_cache_key, expires_in: VISITOR_VERDICT_TTL) do
      response = HTTP
        .auth("Bearer #{api_key}")
        .timeout(TIMEOUT_SECONDS)
        .get("#{VISITOR_ENDPOINT}/#{@visitor_id}")

      case response.code
      when 200 then true
      when 404 then false
      else true # unknown status: fail open
      end
    end
  rescue HTTP::Error, HTTP::TimeoutError
    true # lookup failed: fail open, let the goal through
  end

  def visitor_cache_key
    "datafast:visitor_has_pageviews:#{@visitor_id}"
  end

  def payload
    {
      datafast_visitor_id: @visitor_id,
      name: @name,
      metadata: @metadata.presence
    }.compact
  end

  def api_key
    Rails.application.credentials.dig(:datafast, :api_key)
  end

  def api_key_configured?
    api_key.present?
  end

  # Goal names: lowercase letters, numbers, underscores, hyphens (max 64 chars)
  def sanitize_goal_name(name)
    name.to_s.downcase.gsub(/[^a-z0-9_-]/, "_").first(64)
  end

  # Metadata: max 10 keys, values as strings (max 255 chars)
  def sanitize_metadata(metadata)
    return {} if metadata.blank?

    metadata
      .first(MAX_METADATA_KEYS)
      .to_h
      .transform_keys { |k| k.to_s.downcase.gsub(/[^a-z0-9_-]/, "_").first(64) }
      .transform_values { |v| v.to_s.first(255) }
  end

  def log_success
    # Truncate visitor_id for privacy in logs
    visitor_preview = @visitor_id.to_s.first(8)
    Rails.logger.info("[DataFast] Goal '#{@name}' tracked for visitor #{visitor_preview}...")
  end

  def log_error(message)
    # Use info level to ensure visibility in production logs
    Rails.logger.info("[DataFast] FAILED goal='#{@name}' error='#{message}'")
  end

  # Expected, benign skip (not an error): the visitor was never recorded by
  # DataFast, so there is nothing to attribute the goal to. Logged distinctly
  # from FAILED so the alert on "[DataFast] FAILED" does not fire on it.
  def log_skipped(reason)
    Rails.logger.info("[DataFast] skipped goal='#{@name}' reason='#{reason}'")
  end
end
