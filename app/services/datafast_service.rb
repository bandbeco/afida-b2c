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
  TIMEOUT_SECONDS = 5
  MAX_METADATA_KEYS = 10

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
    return false if @visitor_id.blank?
    return false unless api_key_configured?

    send_goal
  rescue HTTP::Error, HTTP::TimeoutError => e
    log_error("HTTP error: #{e.message}")
    false
  rescue StandardError => e
    log_error("Unexpected error: #{e.message}")
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
    Rails.logger.warn("[DataFast] Failed to track goal '#{@name}': #{message}")
  end
end
