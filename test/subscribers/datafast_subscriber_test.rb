# frozen_string_literal: true

require "test_helper"

class DatafastSubscriberTest < ActiveJob::TestCase
  setup do
    @subscriber = DatafastSubscriber.new
    @visitor_id = "df_visitor_test123"
  end

  test "enqueues job for cart.item_added event" do
    event = build_event("cart.item_added",
      payload: { product_id: 1, product_sku: "SKU-001", quantity: 2 })

    assert_enqueued_with(job: DatafastGoalJob) do
      @subscriber.emit(event)
    end
  end

  test "maps cart.item_added to add_to_cart goal" do
    event = build_event("cart.item_added",
      payload: { product_id: 1, product_sku: "SKU-001", quantity: 2 })

    assert_enqueued_with(
      job: DatafastGoalJob,
      args: [ "add_to_cart", { visitor_id: @visitor_id, metadata: { product_id: 1, product_sku: "SKU-001", quantity: 2 } } ]
    ) do
      @subscriber.emit(event)
    end
  end

  test "maps cart.item_removed to remove_from_cart goal" do
    event = build_event("cart.item_removed",
      payload: { product_id: 1, product_sku: "SKU-001" })

    assert_enqueued_with(
      job: DatafastGoalJob,
      args: [ "remove_from_cart", { visitor_id: @visitor_id, metadata: { product_id: 1, product_sku: "SKU-001" } } ]
    ) do
      @subscriber.emit(event)
    end
  end

  test "maps checkout.started to begin_checkout goal" do
    event = build_event("checkout.started",
      payload: { cart_id: 123, item_count: 3, subtotal: 99.99 })

    assert_enqueued_with(
      job: DatafastGoalJob,
      args: [ "begin_checkout", { visitor_id: @visitor_id, metadata: { cart_id: 123, item_count: 3, subtotal: "99.99" } } ]
    ) do
      @subscriber.emit(event)
    end
  end

  test "maps checkout.completed to purchase goal" do
    event = build_event("checkout.completed",
      payload: { order_id: 456, total: 119.99 })

    assert_enqueued_with(
      job: DatafastGoalJob,
      args: [ "purchase", { visitor_id: @visitor_id, metadata: { order_id: 456, total: "119.99" } } ]
    ) do
      @subscriber.emit(event)
    end
  end

  test "maps email_signup.completed to email_signup goal" do
    event = build_event("email_signup.completed",
      payload: { source: "homepage_popup" })

    assert_enqueued_with(
      job: DatafastGoalJob,
      args: [ "email_signup", { visitor_id: @visitor_id, metadata: { source: "homepage_popup" } } ]
    ) do
      @subscriber.emit(event)
    end
  end

  test "does not enqueue job when visitor_id is missing" do
    event = build_event("cart.item_added",
      payload: { product_id: 1 },
      context: { datafast_visitor_id: nil })

    assert_no_enqueued_jobs do
      @subscriber.emit(event)
    end
  end

  test "does not enqueue job when visitor_id is blank string" do
    event = build_event("cart.item_added",
      payload: { product_id: 1 },
      context: { datafast_visitor_id: "" })

    assert_no_enqueued_jobs do
      @subscriber.emit(event)
    end
  end

  test "ignores unmapped events" do
    event = build_event("order.placed",
      payload: { order_id: 1 })

    assert_no_enqueued_jobs do
      @subscriber.emit(event)
    end
  end

  test "ignores webhook events" do
    event = build_event("webhook.received",
      payload: { event_type: "checkout.session.completed" })

    assert_no_enqueued_jobs do
      @subscriber.emit(event)
    end
  end

  test "handles missing payload fields gracefully" do
    event = build_event("checkout.started",
      payload: { cart_id: 123 }) # Missing item_count and subtotal

    assert_enqueued_with(
      job: DatafastGoalJob,
      args: [ "begin_checkout", { visitor_id: @visitor_id, metadata: { cart_id: 123 } } ]
    ) do
      @subscriber.emit(event)
    end
  end

  test "handles nil payload gracefully" do
    event = build_event("email_signup.completed", payload: nil)

    assert_enqueued_with(job: DatafastGoalJob) do
      @subscriber.emit(event)
    end
  end

  private

  def build_event(name, payload: {}, context: nil)
    {
      name: name,
      payload: payload || {},
      context: context || { datafast_visitor_id: @visitor_id }
    }
  end
end
