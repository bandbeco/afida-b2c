# frozen_string_literal: true

# Test helper for stubbing Klaviyo API calls.
#
# Usage in tests:
#   include KlaviyoTestHelper
#
#   test "tracks event" do
#     stub_klaviyo_event_create
#     KlaviyoService.track("Subscribed", email: "a@b.com")
#     assert_klaviyo_event_tracked("Subscribed")
#   end
#
module KlaviyoTestHelper
  KLAVIYO_EVENTS_ENDPOINT = "https://a.klaviyo.com/api/events"
  KLAVIYO_PROFILE_ENDPOINT = "https://a.klaviyo.com/api/profile-import"

  # Stubs successful event creation (Klaviyo returns 202 Accepted with no body)
  def stub_klaviyo_event_create
    stub_request(:post, KLAVIYO_EVENTS_ENDPOINT)
      .to_return(status: 202, body: "", headers: {})
  end

  # Stubs successful profile upsert (profile-import returns 200/201 with a body)
  def stub_klaviyo_profile_upsert
    stub_request(:post, KLAVIYO_PROFILE_ENDPOINT)
      .to_return(
        status: 200,
        body: { data: { id: "01J_TEST_PROFILE", type: "profile" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Stubs an error response on the events endpoint
  def stub_klaviyo_event_error(status: 400, error: "Invalid request")
    stub_request(:post, KLAVIYO_EVENTS_ENDPOINT)
      .to_return(status: status, body: { errors: [ { detail: error } ] }.to_json)
  end

  # Stubs a network timeout on the events endpoint
  def stub_klaviyo_timeout
    stub_request(:post, KLAVIYO_EVENTS_ENDPOINT).to_timeout
  end

  # Stubs a network error on the events endpoint
  def stub_klaviyo_network_error
    stub_request(:post, KLAVIYO_EVENTS_ENDPOINT)
      .to_raise(HTTP::ConnectionError.new("Connection refused"))
  end

  # Asserts an event was tracked with the given metric name
  def assert_klaviyo_event_tracked(metric_name, email: nil)
    assert_requested :post, KLAVIYO_EVENTS_ENDPOINT do |req|
      body = JSON.parse(req.body)
      metric = body.dig("data", "attributes", "metric", "data", "attributes", "name")
      profile_email = body.dig("data", "attributes", "profile", "data", "attributes", "email")
      metric == metric_name && (email.nil? || profile_email == email)
    end
  end

  # Asserts no events were tracked
  def assert_no_klaviyo_events_tracked
    assert_not_requested :post, KLAVIYO_EVENTS_ENDPOINT
  end

  # Asserts a profile was upserted for the given email
  def assert_klaviyo_profile_upserted(email)
    assert_requested :post, KLAVIYO_PROFILE_ENDPOINT do |req|
      body = JSON.parse(req.body)
      body.dig("data", "attributes", "email") == email
    end
  end

  # Sets up a Klaviyo private API key in credentials for testing
  def stub_klaviyo_credentials(api_key: "pk_test_klaviyo_123")
    Rails.application.credentials.stubs(:dig).with(:klaviyo, :api_key).returns(api_key)
  end

  # Clears the Klaviyo API key (simulates unconfigured state)
  def stub_klaviyo_credentials_missing
    Rails.application.credentials.stubs(:dig).with(:klaviyo, :api_key).returns(nil)
  end
end
