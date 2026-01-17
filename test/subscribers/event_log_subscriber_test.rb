# frozen_string_literal: true

require "test_helper"

class EventLogSubscriberTest < ActiveSupport::TestCase
  setup do
    @subscriber = EventLogSubscriber.new
  end

  test "formats business event as JSON with all required fields" do
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

  test "logs all supported business event prefixes" do
    # All business event prefixes should be logged
    supported_events = %w[
      cart.item_added
      checkout.started
      email_signup.completed
      order.placed
      payment.succeeded
      pending_order.created
      reorder.scheduled
      webhook.received
    ]

    supported_events.each do |event_name|
      event = {
        name: event_name,
        payload: { test: true },
        context: {},
        tags: {},
        timestamp: 1738964843208679035,
        source_location: nil
      }

      Rails.logger.expects(:info).once

      @subscriber.emit(event)
    end
  end

  test "ignores Rails framework events" do
    # Rails framework events should be filtered out
    framework_events = %w[
      action_controller.request_started
      action_controller.request_completed
      action_view.render_partial
      action_view.render_template
      action_view.render_collection
      active_storage.service_url
    ]

    framework_events.each do |event_name|
      event = {
        name: event_name,
        payload: { some: "data" },
        context: {},
        tags: {},
        timestamp: 1738964843208679035,
        source_location: nil
      }

      Rails.logger.expects(:info).never

      @subscriber.emit(event)
    end
  end

  test "handles empty payload for business events" do
    event = {
      name: "checkout.started",
      payload: {},
      context: {},
      tags: {},
      timestamp: 1738964843208679035,
      source_location: nil
    }

    Rails.logger.expects(:info).with do |logged_json|
      parsed = JSON.parse(logged_json)

      assert_equal "checkout.started", parsed["event"]
      assert_equal({}, parsed["payload"])

      true
    end

    @subscriber.emit(event)
  end
end
