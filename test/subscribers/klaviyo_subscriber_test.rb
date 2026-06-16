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
                         properties: { source: "cart_discount" } } ]
    ) do
      @subscriber.emit(event)
    end
  end

  test "email_signup.completed does not forward the always-true discount_eligible flag" do
    # The emitter always sends discount_eligible: true (ineligible signups bail
    # out before the event fires), so it carries no segmentation signal in Klaviyo.
    event = build_event("email_signup.completed",
      payload: { email: "buyer@cafe.co.uk", source: "cart_discount", discount_eligible: true })

    @subscriber.emit(event)

    track = enqueued_klaviyo_job("track")
    assert_not_includes track[:properties].keys, :discount_eligible
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

  test "email_signup.discount_claimed does not enqueue when email is blank" do
    event = build_event("email_signup.discount_claimed",
      payload: { email: "", order_id: 99, discount_code: "WELCOME5" })

    assert_no_enqueued_jobs do
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

  test "order.placed does not split the shipping name into first/last for B2B orders" do
    # shipping_name on a B2B order is often a company name, so splitting it into
    # first/last produces nonsense. Leave both nil for business profiles.
    order = orders(:acme_order)

    @subscriber.emit(build_event("order.placed", payload: { order_id: order.id }))

    upsert = enqueued_klaviyo_job("upsert_profile")
    assert_nil upsert[:first_name]
    assert_nil upsert[:last_name]
  end

  test "order.placed fires a Placed Order event with value for a normal (non-sample) order" do
    order = orders(:one)

    @subscriber.emit(build_event("order.placed", payload: { order_id: order.id }))

    track = enqueued_klaviyo_job("track")
    assert track, "expected a track job to be enqueued"
    assert_equal "Placed Order", track[:metric]
    assert_equal order.email, track[:email]
    assert_equal order.total_amount.to_f, track[:value]
  end

  test "order.placed fires a Requested Sample event (not Placed Order) for a sample-only order" do
    order = orders(:sample_only_order)
    assert order.sample_request?, "fixture sanity: sample_only_order must be a sample request"

    @subscriber.emit(build_event("order.placed", payload: { order_id: order.id }))

    track = enqueued_klaviyo_job("track")
    assert_equal "Requested Sample", track[:metric]
    assert_equal order.email, track[:email]
  end

  test "Requested Sample event carries no monetary value so it does not pollute revenue reporting" do
    order = orders(:sample_only_order)

    @subscriber.emit(build_event("order.placed", payload: { order_id: order.id }))

    track = enqueued_klaviyo_job("track")
    assert_not_includes track.keys, :value
  end

  test "order.placed treats a mixed sample+paid order as a Placed Order with value" do
    order = orders(:mixed_order)
    assert_not order.sample_request?, "fixture sanity: mixed_order has paid items, not a sample request"

    @subscriber.emit(build_event("order.placed", payload: { order_id: order.id }))

    track = enqueued_klaviyo_job("track")
    assert_equal "Placed Order", track[:metric]
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
