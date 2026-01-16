# frozen_string_literal: true

require "test_helper"

class EventLogSubscriberTest < ActiveSupport::TestCase
  setup do
    @subscriber = EventLogSubscriber.new
  end

  test "formats event as JSON with all required fields" do
    event = {
      name: "order.placed",
      payload: { order_id: 123, email: "test@example.com" },
      context: { request_id: "abc-123", user_id: 456 },
      tags: { source: "checkout" },
      timestamp: 1738964843208679035,
      source_location: { filepath: "app/controllers/checkouts_controller.rb", lineno: 45, label: "success" }
    }

    # Test the format_event method directly by calling emit and checking logger
    # We use mocha to stub the logger
    Rails.logger.expects(:info).with do |logged_json|
      parsed = JSON.parse(logged_json)

      assert_equal "order.placed", parsed["event"]
      assert_equal({ "order_id" => 123, "email" => "test@example.com" }, parsed["payload"])
      assert_equal({ "request_id" => "abc-123", "user_id" => 456 }, parsed["context"])
      assert_equal({ "source" => "checkout" }, parsed["tags"])
      assert_equal 1738964843208679035, parsed["timestamp"]
      assert_equal({ "filepath" => "app/controllers/checkouts_controller.rb", "lineno" => 45, "label" => "success" }, parsed["source_location"])

      true # Return true to satisfy the expectation
    end

    @subscriber.emit(event)
  end

  test "handles minimal event with only name and payload" do
    event = {
      name: "test.minimal",
      payload: { data: "value" },
      context: {},
      tags: {},
      timestamp: 1738964843208679035,
      source_location: nil
    }

    Rails.logger.expects(:info).with do |logged_json|
      parsed = JSON.parse(logged_json)

      assert_equal "test.minimal", parsed["event"]
      assert_equal({ "data" => "value" }, parsed["payload"])
      assert_nil parsed["source_location"]

      true
    end

    @subscriber.emit(event)
  end

  test "handles empty payload" do
    event = {
      name: "test.empty",
      payload: {},
      context: {},
      tags: {},
      timestamp: 1738964843208679035,
      source_location: nil
    }

    Rails.logger.expects(:info).with do |logged_json|
      parsed = JSON.parse(logged_json)

      assert_equal "test.empty", parsed["event"]
      assert_equal({}, parsed["payload"])

      true
    end

    @subscriber.emit(event)
  end
end
