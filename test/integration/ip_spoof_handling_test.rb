# frozen_string_literal: true

require "test_helper"

class IpSpoofHandlingTest < ActionDispatch::IntegrationTest
  test "rescue_responses mapping is configured for IP spoof" do
    mapping = Rails.application.config.action_dispatch.rescue_responses
    assert_equal :bad_request, mapping["ActionDispatch::RemoteIp::IpSpoofAttackError"],
                 "IP spoof attacks should map to :bad_request (400)"
  end

  test "IP spoof error is excluded from Sentry reporting" do
    excluded = Sentry.configuration.excluded_exceptions
    assert_includes excluded, "ActionDispatch::RemoteIp::IpSpoofAttackError",
                    "IP spoof attacks should be excluded from Sentry"
  end
end
