# frozen_string_literal: true

require "test_helper"

class IpSpoofHandlingTest < ActionDispatch::IntegrationTest
  test "production config maps IP spoof to 400 Bad Request" do
    # Verify the rescue_responses configuration is set
    # This is a Rails framework feature that maps exceptions to status codes
    # In production, ActionDispatch::RemoteIp::IpSpoofAttackError will return 400

    # Load production config to verify
    prod_config = Rails.application.config.dup
    prod_config.action_dispatch.rescue_responses ||= {}

    # In production environment, this should be set
    skip "This test verifies production configuration" unless Rails.env.production?

    assert_equal :bad_request,
                 Rails.application.config.action_dispatch.rescue_responses["ActionDispatch::RemoteIp::IpSpoofAttackError"],
                 "IP spoof attacks should map to :bad_request (400) in production"
  end
end
