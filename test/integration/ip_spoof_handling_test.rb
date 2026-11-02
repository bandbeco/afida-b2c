# frozen_string_literal: true

require "test_helper"

class IpSpoofHandlingTest < ActionDispatch::IntegrationTest
  test "IP spoof attack returns 400 Bad Request" do
    # Simulate IP spoof by having Rails raise the error
    # In production, this is handled by config.action_dispatch.rescue_responses
    ApplicationController.any_instance.stubs(:verify_authenticity_token).raises(
      ActionDispatch::RemoteIp::IpSpoofAttackError
    )

    get root_path

    assert_response :bad_request
  ensure
    ApplicationController.any_instance.unstub(:verify_authenticity_token)
  end
end
