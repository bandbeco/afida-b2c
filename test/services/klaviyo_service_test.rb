# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class KlaviyoServiceTest < ActiveSupport::TestCase
  include KlaviyoTestHelper

  setup do
    stub_klaviyo_credentials
  end

  # --- track (events) ---

  test "tracks an event successfully" do
    stub_klaviyo_event_create

    result = KlaviyoService.track("Subscribed", email: "buyer@cafe.co.uk")

    assert result
    assert_klaviyo_event_tracked("Subscribed", email: "buyer@cafe.co.uk")
  end

  test "includes properties in the event payload" do
    stub_klaviyo_event_create

    KlaviyoService.track("Subscribed", email: "buyer@cafe.co.uk", properties: { source: "cart_discount" })

    assert_requested :post, KlaviyoTestHelper::KLAVIYO_EVENTS_ENDPOINT do |req|
      body = JSON.parse(req.body)
      body.dig("data", "attributes", "properties", "source") == "cart_discount"
    end
  end

  test "sends a monetary value when provided" do
    stub_klaviyo_event_create

    KlaviyoService.track("Placed Order", email: "buyer@cafe.co.uk", value: 119.99)

    assert_requested :post, KlaviyoTestHelper::KLAVIYO_EVENTS_ENDPOINT do |req|
      body = JSON.parse(req.body)
      body.dig("data", "attributes", "value") == 119.99
    end
  end

  test "sends authorization and revision headers" do
    stub_klaviyo_event_create

    KlaviyoService.track("Subscribed", email: "buyer@cafe.co.uk")

    assert_requested :post, KlaviyoTestHelper::KLAVIYO_EVENTS_ENDPOINT,
      headers: {
        "Authorization" => "Klaviyo-API-Key pk_test_klaviyo_123",
        "Revision" => KlaviyoService::API_REVISION
      }
  end

  test "returns false and skips when email is blank" do
    stub_klaviyo_event_create

    assert_not KlaviyoService.track("Subscribed", email: nil)
    assert_not KlaviyoService.track("Subscribed", email: "")
    assert_no_klaviyo_events_tracked
  end

  test "returns false and skips when credentials are missing" do
    stub_klaviyo_credentials_missing
    stub_klaviyo_event_create

    assert_not KlaviyoService.track("Subscribed", email: "buyer@cafe.co.uk")
    assert_no_klaviyo_events_tracked
  end

  test "returns false on API error response without raising" do
    stub_klaviyo_event_error(status: 400)

    assert_nothing_raised do
      assert_not KlaviyoService.track("Subscribed", email: "buyer@cafe.co.uk")
    end
  end

  test "returns false on timeout without raising" do
    stub_klaviyo_timeout

    assert_nothing_raised do
      assert_not KlaviyoService.track("Subscribed", email: "buyer@cafe.co.uk")
    end
  end

  test "returns false on network error without raising" do
    stub_klaviyo_network_error

    assert_nothing_raised do
      assert_not KlaviyoService.track("Subscribed", email: "buyer@cafe.co.uk")
    end
  end

  # --- upsert_profile ---

  test "upserts a profile successfully" do
    stub_klaviyo_profile_upsert

    result = KlaviyoService.upsert_profile(email: "buyer@cafe.co.uk", properties: { is_business: true })

    assert result
    assert_klaviyo_profile_upserted("buyer@cafe.co.uk")
  end

  test "maps known profile attributes to Klaviyo standard fields" do
    stub_klaviyo_profile_upsert

    KlaviyoService.upsert_profile(
      email: "buyer@cafe.co.uk",
      first_name: "Jane",
      last_name: "Smith",
      properties: { is_business: true }
    )

    assert_requested :post, KlaviyoTestHelper::KLAVIYO_PROFILE_ENDPOINT do |req|
      attrs = JSON.parse(req.body).dig("data", "attributes")
      attrs["first_name"] == "Jane" &&
        attrs["last_name"] == "Smith" &&
        attrs.dig("properties", "is_business") == true
    end
  end

  test "upsert_profile returns false when email is blank" do
    stub_klaviyo_profile_upsert

    assert_not KlaviyoService.upsert_profile(email: "")
    assert_not_requested :post, KlaviyoTestHelper::KLAVIYO_PROFILE_ENDPOINT
  end

  test "upsert_profile returns false when credentials are missing" do
    stub_klaviyo_credentials_missing
    stub_klaviyo_profile_upsert

    assert_not KlaviyoService.upsert_profile(email: "buyer@cafe.co.uk")
    assert_not_requested :post, KlaviyoTestHelper::KLAVIYO_PROFILE_ENDPOINT
  end

  test "upsert_profile returns false on API error response without raising" do
    stub_request(:post, KlaviyoTestHelper::KLAVIYO_PROFILE_ENDPOINT)
      .to_return(status: 400, body: { errors: [ { detail: "bad" } ] }.to_json)

    assert_nothing_raised do
      assert_not KlaviyoService.upsert_profile(email: "buyer@cafe.co.uk")
    end
  end

  test "upsert_profile returns false on timeout without raising" do
    stub_request(:post, KlaviyoTestHelper::KLAVIYO_PROFILE_ENDPOINT).to_timeout

    assert_nothing_raised do
      assert_not KlaviyoService.upsert_profile(email: "buyer@cafe.co.uk")
    end
  end

  test "upsert_profile returns false on network error without raising" do
    stub_request(:post, KlaviyoTestHelper::KLAVIYO_PROFILE_ENDPOINT)
      .to_raise(HTTP::ConnectionError.new("Connection refused"))

    assert_nothing_raised do
      assert_not KlaviyoService.upsert_profile(email: "buyer@cafe.co.uk")
    end
  end
end
