# frozen_string_literal: true

# Test helper for asserting Rails.event emissions.
#
# Usage in tests:
#   test "emits checkout.completed event" do
#     assert_event_reported("checkout.completed") do
#       post checkout_path
#     end
#   end
#
#   test "includes payload data" do
#     assert_event_reported("order.placed", payload: { order_id: 1 }) do
#       post checkout_path
#     end
#   end
#
#   test "does not emit event on failure" do
#     assert_no_event_reported("checkout.completed") do
#       post checkout_path
#     end
#   end
#
module EventTestHelper
  # A lightweight subscriber that collects emitted events during a test block.
  class EventCollector
    attr_reader :events

    def initialize
      @events = []
    end

    def emit(event)
      @events << event
    end
  end

  # Asserts that an event with the given name is emitted during the block.
  #
  # @param event_name [String] The expected event name
  # @param payload [Hash] Optional payload keys/values to match. Values can be
  #   Procs/lambdas for custom matching (e.g., ->(v) { v.is_a?(Integer) })
  def assert_event_reported(event_name, payload: nil, &block)
    events = capture_events(&block)

    matching = events.select { |e| e[:name] == event_name }
    assert matching.any?, "Expected event '#{event_name}' to be reported, but it was not. " \
      "Events reported: #{events.map { |e| e[:name] }.inspect}"

    if payload
      match_found = matching.any? do |event|
        event_payload = event[:payload] || {}
        payload.all? do |key, expected|
          actual = event_payload[key]
          if expected.respond_to?(:call)
            expected.call(actual)
          else
            actual == expected
          end
        end
      end

      assert match_found, "Event '#{event_name}' was reported but payload didn't match.\n" \
        "Expected payload to include: #{payload.inspect}\n" \
        "Actual payloads: #{matching.map { |e| e[:payload] }.inspect}"
    end
  end

  # Asserts that no event with the given name is emitted during the block.
  def assert_no_event_reported(event_name, &block)
    events = capture_events(&block)

    matching = events.select { |e| e[:name] == event_name }
    assert matching.empty?, "Expected event '#{event_name}' NOT to be reported, but it was. " \
      "Payloads: #{matching.map { |e| e[:payload] }.inspect}"
  end

  private

  # Subscribes a collector, yields the block, then unsubscribes and returns captured events.
  def capture_events
    collector = EventCollector.new
    Rails.event.subscribe(collector)
    yield
    collector.events
  ensure
    Rails.event.unsubscribe(collector)
  end
end
