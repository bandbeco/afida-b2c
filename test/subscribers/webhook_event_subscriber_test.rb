# frozen_string_literal: true

require "test_helper"

class WebhookEventSubscriberTest < ActiveSupport::TestCase
  setup do
    @subscriber = WebhookEventSubscriber.new
    @log_output = StringIO.new
    @original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(@log_output)
  end

  teardown do
    Rails.logger = @original_logger
  end

  # ==========================================================================
  # Event handling and logging
  # ==========================================================================

  test "logs webhook.stripe.received event at info level" do
    event = mock_event("webhook.stripe.received", {})

    @subscriber.emit(event)

    log_entry = parsed_log_entry
    assert_equal "webhook.stripe.received", log_entry["event"]
    assert log_entry["timestamp"].present?
  end

  test "logs invoice_created.shipping_added with shipping amount" do
    event = mock_event(
      "webhook.stripe.invoice_created.shipping_added",
      { subscription_id: 123, shipping_amount: 500 }
    )

    @subscriber.emit(event)

    log_entry = parsed_log_entry
    assert_equal "webhook.stripe.invoice_created.shipping_added", log_entry["event"]
    assert_equal 123, log_entry["subscription_id"]
    assert_equal 500, log_entry["shipping_amount"]
  end

  test "logs invoice_created.free_shipping with subtotal" do
    event = mock_event(
      "webhook.stripe.invoice_created.free_shipping",
      { subscription_id: 456, subtotal: 120.0 }
    )

    @subscriber.emit(event)

    log_entry = parsed_log_entry
    assert_equal "webhook.stripe.invoice_created.free_shipping", log_entry["event"]
    assert_equal 456, log_entry["subscription_id"]
    assert_equal 120.0, log_entry["subtotal"]
  end

  test "logs invoice_created.skipped with reason" do
    event = mock_event(
      "webhook.stripe.invoice_created.skipped",
      { reason: "first_invoice" }
    )

    @subscriber.emit(event)

    log_entry = parsed_log_entry
    assert_equal "webhook.stripe.invoice_created.skipped", log_entry["event"]
    assert_equal "first_invoice", log_entry["reason"]
  end

  test "logs renewal_order.created with order_id" do
    event = mock_event(
      "webhook.stripe.renewal_order.created",
      { order_id: 789, subscription_id: 123 }
    )

    @subscriber.emit(event)

    log_entry = parsed_log_entry
    assert_equal "webhook.stripe.renewal_order.created", log_entry["event"]
    assert_equal 789, log_entry["order_id"]
    assert_equal 123, log_entry["subscription_id"]
  end

  test "ignores non-webhook.stripe events" do
    event = mock_event("other.event", { data: "test" })

    @subscriber.emit(event)

    @log_output.rewind
    assert_empty @log_output.read.strip
  end

  # ==========================================================================
  # Log levels
  # ==========================================================================

  test "logs signature_failed at warn level" do
    event = mock_event("webhook.stripe.signature_failed", { error: "Invalid signature" })

    Rails.logger.expects(:warn).once
    @subscriber.emit(event)
  end

  test "logs invoice_created.error at error level" do
    event = mock_event("webhook.stripe.invoice_created.error", { error: "API error" })

    Rails.logger.expects(:error).once
    @subscriber.emit(event)
  end

  test "logs renewal_order.failed at error level" do
    event = mock_event(
      "webhook.stripe.renewal_order.failed",
      { subscription_id: 123, error: "Validation failed" }
    )

    Rails.logger.expects(:error).once
    @subscriber.emit(event)
  end

  test "logs unknown webhook.stripe events at debug level" do
    event = mock_event("webhook.stripe.unknown_event", {})

    Rails.logger.expects(:debug).once
    @subscriber.emit(event)
  end

  # ==========================================================================
  # Context extraction
  # ==========================================================================

  test "includes stripe context in log entry when available" do
    event = mock_event(
      "webhook.stripe.invoice_created.shipping_added",
      { shipping_amount: 500 },
      context: {
        stripe_event_id: "evt_123",
        stripe_event_type: "invoice.created",
        stripe_invoice_id: "in_456",
        stripe_subscription_id: "sub_789",
        billing_reason: "subscription_cycle"
      }
    )

    @subscriber.emit(event)

    log_entry = parsed_log_entry
    assert_equal "evt_123", log_entry["stripe_event_id"]
    assert_equal "invoice.created", log_entry["stripe_event_type"]
    assert_equal "in_456", log_entry["stripe_invoice_id"]
    assert_equal "sub_789", log_entry["stripe_subscription_id"]
    assert_equal "subscription_cycle", log_entry["billing_reason"]
  end

  # ==========================================================================
  # Sentry integration
  # ==========================================================================

  test "adds Sentry breadcrumb for events when Sentry is initialized" do
    skip "Sentry not initialized in test" unless defined?(Sentry) && Sentry.initialized?

    event = mock_event(
      "webhook.stripe.invoice_created.shipping_added",
      { subscription_id: 123, shipping_amount: 500 },
      context: { stripe_event_id: "evt_123" }
    )

    Sentry.expects(:add_breadcrumb).once
    @subscriber.emit(event)
  end

  # ==========================================================================
  # Subscriber registration
  # ==========================================================================

  test "subscriber implements emit method" do
    assert_respond_to @subscriber, :emit
  end

  test "subscribe! registers subscriber with Rails.event" do
    Rails.event.expects(:subscribe).with(instance_of(WebhookEventSubscriber)).once
    WebhookEventSubscriber.subscribe!
  end

  private

  # Rails 8.1 EventReporter passes events as hashes with these keys:
  #   name, payload, context, tags, timestamp, source_location
  def mock_event(name, payload, context: {}, timestamp: Time.current)
    {
      name: name,
      payload: payload,
      context: context,
      tags: [],
      timestamp: timestamp,
      source_location: { filepath: __FILE__, lineno: __LINE__ }
    }
  end

  def parsed_log_entry
    @log_output.rewind
    log_line = @log_output.read.strip
    JSON.parse(log_line)
  end
end
