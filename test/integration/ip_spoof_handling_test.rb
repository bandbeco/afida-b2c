# frozen_string_literal: true

require "test_helper"

class IpSpoofHandlingTest < ActionDispatch::IntegrationTest
  test "conflicting forwarded IP headers return 400 Bad Request" do
    # Simulate IP spoofing with conflicting X-Forwarded-For and Client-IP headers
    # This triggers ActionDispatch::RemoteIp::IpSpoofAttackError
    get root_path, headers: {
      "HTTP_X_FORWARDED_FOR" => "1.2.3.4",
      "HTTP_CLIENT_IP" => "5.6.7.8"
    }

    assert_response :bad_request
  end

  test "rescue_responses mapping is configured" do
    mapping = Rails.application.config.action_dispatch.rescue_responses
    assert_equal :bad_request, mapping["ActionDispatch::RemoteIp::IpSpoofAttackError"],
                 "IP spoof attacks should map to :bad_request (400)"
  end
end
