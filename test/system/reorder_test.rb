# frozen_string_literal: true

require "application_system_test_case"

class ReorderTest < ApplicationSystemTestCase
  # Note: Full E2E tests with authentication are covered by controller tests
  # (test/controllers/orders_controller_test.rb).
  #
  # The comprehensive test coverage includes:
  # - ReorderService unit tests (test/services/reorder_service_test.rb)
  # - Controller integration tests with auth (test/controllers/orders_controller_test.rb)
  #
  # System tests here focus on basic route accessibility without login.

  test "guest cannot access order history" do
    visit orders_path

    # Should redirect to sign in
    assert_current_path new_session_path
  end
end
