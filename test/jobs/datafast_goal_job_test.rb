# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class DatafastGoalJobTest < ActiveJob::TestCase
  include DatafastTestHelper

  setup do
    @visitor_id = "df_visitor_test123"
    stub_datafast_credentials
  end

  test "calls DatafastService.track with correct arguments" do
    stub_datafast_goal_create
    metadata = { product_id: "123" }

    DatafastService.expects(:track).with("add_to_cart", visitor_id: @visitor_id, metadata: metadata).returns(true)

    DatafastGoalJob.perform_now("add_to_cart", visitor_id: @visitor_id, metadata: metadata)
  end

  test "emits datafast.goal_tracked event on success" do
    stub_datafast_goal_create

    # Create a simple event collector
    events = []
    collector = EventCollector.new(events)
    Rails.event.subscribe(collector)

    DatafastGoalJob.perform_now("add_to_cart", visitor_id: @visitor_id, metadata: {})

    goal_event = events.find { |e| e[:name] == "datafast.goal_tracked" }
    assert goal_event, "Expected datafast.goal_tracked event to be emitted"
    assert_equal "add_to_cart", goal_event[:payload][:name]
    assert goal_event[:payload][:success]
    assert goal_event[:payload][:visitor_id_present]
  ensure
    Rails.event.unsubscribe(collector) if collector
  end

  test "emits datafast.goal_tracked event on failure" do
    stub_datafast_goal_error(status: 500)

    events = []
    collector = EventCollector.new(events)
    Rails.event.subscribe(collector)

    DatafastGoalJob.perform_now("add_to_cart", visitor_id: @visitor_id, metadata: {})

    goal_event = events.find { |e| e[:name] == "datafast.goal_tracked" }
    assert goal_event, "Expected datafast.goal_tracked event to be emitted"
    assert_not goal_event[:payload][:success]
  ensure
    Rails.event.unsubscribe(collector) if collector
  end

  test "job can be enqueued" do
    assert_enqueued_with(job: DatafastGoalJob) do
      DatafastGoalJob.perform_later("purchase", visitor_id: @visitor_id, metadata: { order_id: "123" })
    end
  end

  test "handles empty metadata" do
    stub_datafast_goal_create

    # Should not raise
    DatafastGoalJob.perform_now("view_item", visitor_id: @visitor_id, metadata: {})

    assert_datafast_goal_tracked("view_item")
  end

  # Helper class that collects events for testing
  class EventCollector
    def initialize(events)
      @events = events
    end

    def emit(event)
      @events << event
    end
  end
end
