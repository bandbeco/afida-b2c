# frozen_string_literal: true

require "test_helper"

class KlaviyoSubscriberTest < ActiveJob::TestCase
  setup do
    @subscriber = KlaviyoSubscriber.new
  end

  # --- email_signup.completed ---

  # The subscriber resolves the email from the EmailSubscription (Rails.event
  # filters :email out of the payload), so tests pass subscription_id and assert
  # the fixture's address, not the filtered payload value.
  test "email_signup.completed enqueues a Subscribed track job with source" do
    subscription = email_subscriptions(:claimed_discount)
    event = build_event("email_signup.completed",
      payload: { email: "[FILTERED]", subscription_id: subscription.id,
                 source: "cart_discount", discount_eligible: true })

    assert_enqueued_with(
      job: KlaviyoEventJob,
      args: [ "track", { metric: "Subscribed", email: subscription.email,
                         properties: { source: "cart_discount" } } ]
    ) do
      @subscriber.emit(event)
    end
  end

  test "email_signup.completed does not forward the always-true discount_eligible flag" do
    # The emitter always sends discount_eligible: true (ineligible signups bail
    # out before the event fires), so it carries no segmentation signal in Klaviyo.
    subscription = email_subscriptions(:claimed_discount)
    event = build_event("email_signup.completed",
      payload: { subscription_id: subscription.id, source: "cart_discount", discount_eligible: true })

    @subscriber.emit(event)

    track = enqueued_klaviyo_job("track")
    assert_not_includes track[:properties].keys, :discount_eligible
  end

  test "email_signup.completed does not enqueue when the subscription cannot be found" do
    event = build_event("email_signup.completed",
      payload: { subscription_id: 0, source: "cart_discount" })

    assert_no_enqueued_jobs do
      @subscriber.emit(event)
    end
  end

  # --- email_signup.discount_claimed ---

  test "email_signup.discount_claimed enqueues a Claimed Discount track job" do
    order = orders(:one)
    event = build_event("email_signup.discount_claimed",
      payload: { email: "[FILTERED]", order_id: order.id, discount_code: "WELCOME5" })

    assert_enqueued_with(
      job: KlaviyoEventJob,
      args: [ "track", { metric: "Claimed Discount", email: order.email,
                         properties: { discount_code: "WELCOME5" } } ]
    ) do
      @subscriber.emit(event)
    end
  end

  test "email_signup.discount_claimed does not enqueue when the order cannot be found" do
    event = build_event("email_signup.discount_claimed",
      payload: { order_id: 0, discount_code: "WELCOME5" })

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

  # --- cart.checkout_initiated (abandoned-cart trigger) ---

  test "cart.checkout_initiated enqueues a Started Checkout track job with the cart total as value" do
    cart = carts(:one) # cart_items(:one): product :one, quantity 2, price 10
    subscription = email_subscriptions(:claimed_discount)

    @subscriber.emit(build_event("cart.checkout_initiated",
      payload: { cart_id: cart.id, email: "[FILTERED]",
                 subscription_id: subscription.id, source: "cart_discount" }))

    track = enqueued_klaviyo_job("track")
    assert track, "expected a track job to be enqueued"
    assert_equal "Started Checkout", track[:metric]
    assert_equal subscription.email, track[:email]
    assert_in_delta cart.total_amount.to_f, track[:value], 0.001
  end

  test "cart.checkout_initiated properties carry item_count, line_items_count, items and checkout_url" do
    cart = carts(:one)
    item = cart_items(:one)
    subscription = email_subscriptions(:claimed_discount)

    @subscriber.emit(build_event("cart.checkout_initiated",
      payload: { cart_id: cart.id, subscription_id: subscription.id, source: "cart_discount" }))

    props = enqueued_klaviyo_job("track")[:properties]
    assert_equal cart.items_count, props[:item_count]
    assert_equal cart.line_items_count, props[:line_items_count]
    assert props[:checkout_url].present?, "expected a recovery checkout_url"

    assert_equal 1, props[:items].length
    line = props[:items].first.symbolize_keys
    assert_equal item.product.name, line[:name]
    assert_equal item.quantity, line[:quantity]
    assert_in_delta item.price.to_f, line[:price], 0.001
  end

  test "cart.checkout_initiated caps the items array but reports the true line_items_count" do
    cart = Cart.create!
    21.times do |i|
      product = Product.create!(
        category: categories(:cups), name: "Cap Test #{i}",
        sku: "CAP-TEST-#{i}", price: 5.00, pac_size: 50, active: true
      )
      cart.cart_items.create!(product: product, quantity: 1, price: product.price)
    end
    subscription = email_subscriptions(:claimed_discount)

    @subscriber.emit(build_event("cart.checkout_initiated",
      payload: { cart_id: cart.id, subscription_id: subscription.id, source: "cart_discount" }))

    props = enqueued_klaviyo_job("track")[:properties]
    assert_equal KlaviyoSubscriber::MAX_ITEMS_IN_PAYLOAD, props[:items].length
    assert_equal 21, props[:line_items_count]
  end

  test "cart.checkout_initiated does not enqueue when the subscription cannot be found" do
    cart = carts(:one)

    assert_no_enqueued_jobs do
      @subscriber.emit(build_event("cart.checkout_initiated",
        payload: { cart_id: cart.id, subscription_id: 0, source: "cart_discount" }))
    end
  end

  test "cart.checkout_initiated does nothing when the cart cannot be found" do
    subscription = email_subscriptions(:claimed_discount)

    assert_no_enqueued_jobs do
      @subscriber.emit(build_event("cart.checkout_initiated",
        payload: { cart_id: 0, subscription_id: subscription.id }))
    end
  end

  test "cart.checkout_initiated does not enqueue when the cart has no items" do
    empty = Cart.create!
    subscription = email_subscriptions(:claimed_discount)

    assert_no_enqueued_jobs do
      @subscriber.emit(build_event("cart.checkout_initiated",
        payload: { cart_id: empty.id, subscription_id: subscription.id }))
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
