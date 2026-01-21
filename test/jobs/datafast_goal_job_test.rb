# frozen_string_literal: true

require "test_helper"

class DatafastGoalJobTest < ActiveJob::TestCase
  test "calls DatafastService.track with correct arguments" do
    DatafastService.expects(:track).with(
      "add_to_cart",
      visitor_id: "visitor123",
      metadata: { product_id: 1 }
    ).once

    DatafastGoalJob.perform_now("add_to_cart", visitor_id: "visitor123", metadata: { product_id: 1 })
  end

  test "discards errors without retrying" do
    DatafastService.stubs(:track).raises(StandardError, "API error")

    # Should not raise - job discards errors
    assert_nothing_raised do
      DatafastGoalJob.perform_now("test", visitor_id: "v1", metadata: {})
    end
  end
end
