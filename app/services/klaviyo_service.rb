# frozen_string_literal: true

require "http"

# Sends marketing events and profile updates to Klaviyo.
#
# Klaviyo is used for MARKETING email only (welcome series, abandoned cart,
# sample-to-customer nurture). Transactional email stays on Mailgun.
#
# Two operations:
#   - track(metric, email:, ...)   → POST /api/events       (records a metric, upserts the profile inline)
#   - upsert_profile(email:, ...)  → POST /api/profile-import (creates/updates a profile)
#
# Both are no-ops (return false) when the API key is not configured, so the
# integration is safe to ship before credentials are set, mirroring
# Ga4MeasurementProtocolService and DatafastService.
#
# API Reference: https://developers.klaviyo.com/en/reference/create_event
#
# Usage:
#   KlaviyoService.track("Subscribed", email: "a@b.com", properties: { source: "cart_discount" })
#   KlaviyoService.upsert_profile(email: "a@b.com", first_name: "Jane", properties: { is_business: true })
#
class KlaviyoService
  BASE_URL = "https://a.klaviyo.com/api"
  EVENTS_ENDPOINT = "#{BASE_URL}/events"
  PROFILE_ENDPOINT = "#{BASE_URL}/profile-import"
  # Klaviyo pins behaviour to a dated API revision via the Revision header.
  API_REVISION = "2024-10-15"
  TIMEOUT_SECONDS = 5

  class << self
    # Records a metric (event) against a profile, creating/updating the profile inline.
    # @param metric [String] event/metric name (e.g. "Subscribed", "Placed Order")
    # @param email [String] profile email (required)
    # @param properties [Hash] event properties
    # @param value [Numeric, nil] optional monetary value (e.g. order total)
    # @return [Boolean] true if accepted by Klaviyo
    def track(metric, email:, properties: {}, value: nil)
      new.track(metric, email: email, properties: properties, value: value)
    end

    # Creates or updates a profile.
    # @param email [String] profile email (required)
    # @param first_name [String, nil]
    # @param last_name [String, nil]
    # @param properties [Hash] custom profile properties (e.g. is_business)
    # @return [Boolean] true if accepted by Klaviyo
    def upsert_profile(email:, first_name: nil, last_name: nil, properties: {})
      new.upsert_profile(email: email, first_name: first_name, last_name: last_name, properties: properties)
    end
  end

  def track(metric, email:, properties: {}, value: nil)
    return skip("email is blank") if email.blank?
    return skip("API key not configured") unless api_key_configured?

    post(EVENTS_ENDPOINT, event_payload(metric, email, properties, value), context: "event '#{metric}'")
  end

  def upsert_profile(email:, first_name: nil, last_name: nil, properties: {})
    return skip("email is blank") if email.blank?
    return skip("API key not configured") unless api_key_configured?

    post(PROFILE_ENDPOINT, profile_payload(email, first_name, last_name, properties), context: "profile upsert")
  end

  private

  def post(endpoint, payload, context:)
    response = http_client.post(endpoint, json: payload)

    if response.status.success?
      Rails.logger.info("[Klaviyo] #{context} accepted (#{response.status})")
      true
    else
      log_error("#{context} rejected #{response.status}: #{response.body}")
      false
    end
  rescue HTTP::Error, HTTP::TimeoutError => e
    log_error("HTTP error on #{context}: #{e.class} - #{e.message}")
    false
  rescue StandardError => e
    log_error("Unexpected error on #{context}: #{e.class} - #{e.message}")
    false
  end

  def http_client
    HTTP
      .headers(
        "Authorization" => "Klaviyo-API-Key #{api_key}",
        "Revision" => API_REVISION,
        "Accept" => "application/vnd.api+json",
        "Content-Type" => "application/vnd.api+json"
      )
      .timeout(TIMEOUT_SECONDS)
  end

  def event_payload(metric, email, properties, value)
    attributes = {
      properties: properties.presence || {},
      metric: {
        data: { type: "metric", attributes: { name: metric } }
      },
      profile: {
        data: { type: "profile", attributes: { email: email } }
      }
    }
    attributes[:value] = value unless value.nil?

    { data: { type: "event", attributes: attributes } }
  end

  def profile_payload(email, first_name, last_name, properties)
    attributes = { email: email }
    attributes[:first_name] = first_name if first_name.present?
    attributes[:last_name] = last_name if last_name.present?
    attributes[:properties] = properties if properties.present?

    { data: { type: "profile", attributes: attributes } }
  end

  def api_key
    Rails.application.credentials.dig(:klaviyo, :api_key)
  end

  def api_key_configured?
    api_key.present?
  end

  def skip(reason)
    Rails.logger.info("[Klaviyo] Skipping — #{reason}")
    false
  end

  def log_error(message)
    # info level to ensure visibility in production logs, matching DatafastService.
    Rails.logger.info("[Klaviyo] FAILED #{message}")
  end
end
