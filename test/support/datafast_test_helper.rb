# frozen_string_literal: true

# Test helper for stubbing DataFast API calls.
#
# Usage in tests:
#   include DatafastTestHelper
#
#   test "tracks goal" do
#     stub_datafast_goal_create
#     DatafastService.track("add_to_cart", visitor_id: "abc123")
#     assert_datafast_goal_tracked("add_to_cart")
#   end
#
module DatafastTestHelper
  DATAFAST_ENDPOINT = "https://datafa.st/api/v1/goals"

  # Stubs successful goal creation
  # @param response_body [Hash] Optional custom response body
  def stub_datafast_goal_create(response_body: nil)
    body = response_body || {
      status: "success",
      data: {
        message: "Custom event created successfully",
        eventId: "test_event_#{SecureRandom.hex(12)}"
      }
    }

    stub_request(:post, DATAFAST_ENDPOINT)
      .to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  # Stubs goal creation with error response
  # @param status [Integer] HTTP status code (default: 400)
  # @param error [String] Error message
  def stub_datafast_goal_error(status: 400, error: "Bad Request")
    stub_request(:post, DATAFAST_ENDPOINT)
      .to_return(status: status, body: { error: error }.to_json)
  end

  # Stubs network timeout
  def stub_datafast_timeout
    stub_request(:post, DATAFAST_ENDPOINT).to_timeout
  end

  # Stubs network error
  def stub_datafast_network_error
    stub_request(:post, DATAFAST_ENDPOINT).to_raise(HTTP::ConnectionError.new("Connection refused"))
  end

  # Asserts a goal was tracked with specific name
  # @param goal_name [String] Expected goal name
  # @param visitor_id [String] Optional expected visitor ID
  def assert_datafast_goal_tracked(goal_name, visitor_id: nil)
    request_pattern = { body: hash_including(name: goal_name) }
    request_pattern[:body][:datafast_visitor_id] = visitor_id if visitor_id

    assert_requested :post, DATAFAST_ENDPOINT, request_pattern
  end

  # Asserts no goals were tracked
  def assert_no_datafast_goals_tracked
    assert_not_requested :post, DATAFAST_ENDPOINT
  end

  # Sets up DataFast API key in credentials for testing
  def stub_datafast_credentials(api_key: "df_test_key_123")
    Rails.application.credentials.stubs(:dig).with(:datafast, :api_key).returns(api_key)
  end

  # Clears DataFast API key (simulates unconfigured state)
  def stub_datafast_credentials_missing
    Rails.application.credentials.stubs(:dig).with(:datafast, :api_key).returns(nil)
  end
end
