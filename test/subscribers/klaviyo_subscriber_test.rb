# frozen_string_literal: true

require "test_helper"

class KlaviyoSubscriberTest < ActiveJob::TestCase
  setup do
    @subscriber = KlaviyoSubscriber.new
  end

  # --- email_signup.completed ---

  test "email_signup.completed enqueues a Subscribed track job with source" do
    event = build_event("email_signup.completed",
      payload: { email: "buyer@cafe.co.uk", source: "cart_discount", discount_eligible: true })

    assert_enqueued_with(
      job: KlaviyoEventJob,
      args: [ "track", { metric: "Subscribed", email: "buyer@cafe.co.uk",
                         properties: { source: "cart_discount", discount_eligible: true } } ]
    ) do
      @subscriber.emit(event)
    end
  end

  test "email_signup.completed does not enqueue when email is blank" do
    event = build_event("email_signup.completed", payload: { email: "", source: "cart_discount" })

    assert_no_enqueued_jobs do
      @subscriber.emit(event)
    end
  end

  # --- email_signup.discount_claimed ---

  test "email_signup.discount_claimed enqueues a Claimed Discount track job" do
    event = build_event("email_signup.discount_claimed",
      payload: { email: "buyer@cafe.co.uk", order_id: 99, discount_code: "WELCOME5" })

    assert_enqueued_with(
      job: KlaviyoEventJob,
      args: [ "track", { metric: "Claimed Discount", email: "buyer@cafe.co.uk",
                         properties: { discount_code: "WELCOME5" } } ]
    ) do
      @subscriber.emit(event)
    end
  end

  # --- order.placed ---

  test "order.placed enqueues a profile upsert and a Placed Order track job" do
    order = orders(:one)

    assert_enqueued_jobs 2, only: KlaviyoEventJob do
      @subscriber.emit(build_event("order.placed", payload: { order_id: order.id }))
    end
  end

  test "order.placed upsert carries is_business false and the customer name for a B2C order" do
    order = orders(:one) # no organization

    @subscriber.emit(build_event("order.placed", payload: { order_id: order.id }))

    assert_enqueued_with(
      job: KlaviyoEventJob,
      args: [ "upsert_profile", {
        email: order.email,
        first_name: "John",
        last_name: "Doe",
        properties: { is_business: false, sample_request: false }
      } ]
    )
  end

  test "order.placed upsert carries is_business true for a B2B order" do
    order = orders(:acme_order)

    @subscriber.emit(build_event("order.placed", payload: { order_id: order.id }))

    upsert = enqueued_klaviyo_job("upsert_profile")
    assert upsert, "expected an upsert_profile job to be enqueued"
    assert_equal order.email, upsert[:email]
    assert_equal true, upsert[:properties][:is_business]
  end

  test "order.placed track job carries the order value" do
    order = orders(:one)

    @subscriber.emit(build_event("order.placed", payload: { order_id: order.id }))

    track = enqueued_klaviyo_job("track")
    assert track, "expected a track job to be enqueued"
    assert_equal "Placed Order", track[:metric]
    assert_equal order.email, track[:email]
    assert_equal order.total_amount.to_f, track[:value]
  end

  test "order.placed does nothing when the order cannot be found" do
    assert_no_enqueued_jobs do
      @subscriber.emit(build_event("order.placed", payload: { order_id: 0 }))
    end
  end

  # --- checkout.started ---

  test "checkout.started is ignored at the subscriber level (no email available)" do
    # checkout.started carries no email, so the subscriber cannot build a profile.
    # Abandoned-cart capture is handled separately once an email is known.
    event = build_event("checkout.started", payload: { cart_id: 1, item_count: 2, subtotal: 50 })

    assert_no_enqueued_jobs do
      @subscriber.emit(event)
    end
  end

  # --- unmapped ---

  test "ignores unmapped events" do
    assert_no_enqueued_jobs do
      @subscriber.emit(build_event("cart.viewed", payload: { cart_id: 1 }))
    end
  end

  private

  def build_event(name, payload: {})
    { name: name, payload: payload || {}, context: {} }
  end

  # Finds the first enqueued KlaviyoEventJob with the given operation and returns
  # its keyword args as a hash, or nil if none. Job args serialize as
  # [operation, { kwargs... }] (string keys after round-tripping).
  def enqueued_klaviyo_job(operation)
    job = enqueued_jobs.find do |j|
      j[:job] == KlaviyoEventJob && j[:args].first == operation
    end
    return nil unless job

    job[:args].last.symbolize_keys.transform_values do |v|
      v.is_a?(Hash) ? v.symbolize_keys : v
    end
  end
end
