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

  test "conflicting X-Forwarded-For and Client-IP headers return 400" do
    # RemoteIp stores a lazy calculator and raises only when remote_ip is read.
    # Samples#index reads it through rate_limit, so the spoof check runs inside
    # that middleware rather than from a route that raises the error itself.
    get samples_path, headers: {
      "X-Forwarded-For" => "203.0.113.5",
      "Client-IP" => "198.51.100.8"
    }

    assert_response :bad_request
  end
end
