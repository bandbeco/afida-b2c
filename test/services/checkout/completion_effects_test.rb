require "test_helper"

# What fires once an Order exists, asserted against an Order and plain facts
# with no Stripe session in the fixture (see Checkout::CompletionEffects).
class Checkout::CompletionEffectsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    @order = orders(:one)
  end

  test "sends the confirmation emails and the team notification" do
    effects(browser_present: true).run

    assert_enqueued_emails 2
    assert_enqueued_with(job: TelegramOrderNotificationJob, args: [ @order.id ])
  end

  test "fires the server-side GA4 purchase only when no browser will" do
    Ga4MeasurementProtocolService.expects(:track_purchase).never
    effects(browser_present: true).run

    Ga4MeasurementProtocolService.expects(:track_purchase).once.with(@order)
    effects(browser_present: false).run
  end

  test "emits checkout.completed and order.placed for every completion" do
    events = capture_events { effects(browser_present: true, payment_method: "card").run }

    completed = events.find { |e| e[:name] == "checkout.completed" }
    assert_equal @order.id, completed[:payload][:order_id]
    assert_equal "card", completed[:payload][:payment_method]

    placed = events.find { |e| e[:name] == "order.placed" }
    assert_equal @order.id, placed[:payload][:order_id]
    assert_equal "checkout", placed[:payload][:source]
    assert_equal false, placed[:payload][:has_discount]
  end

  test "claims the Welcome discount when the session recorded one" do
    assert_event_reported("email_signup.discount_claimed", payload: { order_id: @order.id, discount_code: "WELCOME10" }) do
      effects(browser_present: true, welcome_discount_code: "WELCOME10").run
    end
  end

  test "does not claim a discount when the session recorded none" do
    assert_no_event_reported("email_signup.discount_claimed") do
      effects(browser_present: true, welcome_discount_code: nil).run
    end
  end

  test "attributes the Datafast conversion to the visitor who paid" do
    events = capture_events do
      effects(browser_present: false, datafast_visitor_id: "visitor-1", datafast_session_id: "sess-1").run
    end

    completed = events.find { |e| e[:name] == "checkout.completed" }
    assert_equal "visitor-1", completed[:context][:datafast_visitor_id]
    assert_equal "sess-1", completed[:context][:datafast_session_id]
  end

  test "the webhook channel skips checkout.completed when the session recorded no Datafast visitor" do
    # The webhook request has no browser cookie, and EventContext mints a
    # visitor id for every request, so an unguarded event would attribute the
    # conversion to a visitor that never existed.
    assert_no_event_reported("checkout.completed") do
      effects(browser_present: false, datafast_visitor_id: nil).run
    end

    assert_event_reported("checkout.completed") do
      effects(browser_present: true, datafast_visitor_id: nil).run
    end
  end

  test "a missing Datafast session id in metadata does not erase the browser's" do
    Rails.event.set_context(datafast_session_id: "cookie-sess")

    events = capture_events do
      effects(browser_present: true, datafast_visitor_id: "visitor-1", datafast_session_id: nil).run
    end

    completed = events.find { |e| e[:name] == "checkout.completed" }
    assert_equal "cookie-sess", completed[:context][:datafast_session_id]
  ensure
    Rails.event.clear_context
  end

  test "a failing event does not stop the events after it" do
    # Later expectations match first in Mocha; the bare stub absorbs the
    # framework's own notify calls (active_job.enqueued).
    Rails.event.stubs(:notify)
    Rails.event.stubs(:notify).with { |name, *| name == "checkout.completed" }.raises(StandardError.new("bad payload"))
    Rails.event.expects(:notify).with { |name, *| name == "order.placed" }.once
    Sentry.expects(:capture_exception).once

    effects(browser_present: true).run
  end

  test "a failed effect is reported and the remaining effects still fire" do
    OrderMailer.stubs(:with).raises(StandardError.new("mailer down"))
    Sentry.expects(:capture_exception).once

    assert_event_reported("order.placed") do
      effects(browser_present: true).run
    end
    assert_enqueued_with(job: TelegramOrderNotificationJob, args: [ @order.id ])
  end

  private

  def effects(**facts)
    Checkout::CompletionEffects.new(@order, **facts)
  end
end
