require "test_helper"

class CreatePendingOrdersJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @product_variant = product_variants(:one)

    # Create a schedule due in 3 days (the job creates pending orders 3 days before delivery)
    @schedule = ReorderSchedule.create!(
      user: @user,
      frequency: :every_month,
      status: :active,
      next_scheduled_date: 3.days.from_now.to_date,
      stripe_payment_method_id: "pm_test_123"
    )

    # Add items to the schedule
    @schedule_item = ReorderScheduleItem.create!(
      reorder_schedule: @schedule,
      product_variant: @product_variant,
      quantity: 2,
      price: @product_variant.price
    )
  end

  # ==========================================================================
  # Job Enqueuing
  # ==========================================================================

  test "job can be enqueued" do
    assert_enqueued_with(job: CreatePendingOrdersJob) do
      CreatePendingOrdersJob.perform_later
    end
  end

  # ==========================================================================
  # Finding Due Schedules
  # ==========================================================================

  test "creates pending order for schedule due in 3 days" do
    assert_difference "PendingOrder.count", 1 do
      CreatePendingOrdersJob.perform_now
    end

    pending_order = PendingOrder.last
    assert_equal @schedule, pending_order.reorder_schedule
    assert_equal @schedule.next_scheduled_date, pending_order.scheduled_for
    assert_equal "pending", pending_order.status
  end

  test "skips schedules not due in exactly 3 days" do
    # Make schedule due in 5 days (not 3)
    @schedule.update!(next_scheduled_date: 5.days.from_now.to_date)

    assert_no_difference "PendingOrder.count" do
      CreatePendingOrdersJob.perform_now
    end
  end

  test "skips paused schedules" do
    @schedule.pause!

    assert_no_difference "PendingOrder.count" do
      CreatePendingOrdersJob.perform_now
    end
  end

  test "skips cancelled schedules" do
    @schedule.cancel!

    assert_no_difference "PendingOrder.count" do
      CreatePendingOrdersJob.perform_now
    end
  end

  test "skips schedules that already have pending order for same date" do
    # Create existing pending order
    PendingOrder.create!(
      reorder_schedule: @schedule,
      scheduled_for: @schedule.next_scheduled_date,
      items_snapshot: { "items" => [], "total" => "0.00" }
    )

    assert_no_difference "PendingOrder.count" do
      CreatePendingOrdersJob.perform_now
    end
  end

  # ==========================================================================
  # Items Snapshot Building
  # ==========================================================================

  test "builds items_snapshot with current prices" do
    # Update the variant price to something different from schedule item price
    @product_variant.update!(price: 25.00)

    CreatePendingOrdersJob.perform_now

    pending_order = PendingOrder.last
    items = pending_order.items

    assert_equal 1, items.length
    item = items.first
    assert_equal @product_variant.id, item["product_variant_id"]
    assert_equal 2, item["quantity"]
    assert_equal "25.00", item["price"] # Current price, not original
    assert_equal true, item["available"]
  end

  test "includes product and variant names in snapshot" do
    CreatePendingOrdersJob.perform_now

    pending_order = PendingOrder.last
    item = pending_order.items.first

    assert item["product_name"].present?
    assert item["variant_name"].present?
  end

  test "calculates correct totals in snapshot" do
    # 2 items at current price
    @product_variant.update!(price: 10.00)

    CreatePendingOrdersJob.perform_now

    pending_order = PendingOrder.last
    snapshot = pending_order.items_snapshot

    # subtotal = 2 * 10.00 = 20.00
    assert_equal "20.00", snapshot["subtotal"]
    # vat = 20% of 20.00 = 4.00
    assert_equal "4.00", snapshot["vat"]
    # total = 20.00 + 4.00 = 24.00 (assuming free shipping for now)
    assert snapshot["total"].present?
  end

  # ==========================================================================
  # Handling Unavailable Items
  # ==========================================================================

  test "marks unavailable items in snapshot" do
    # Make the product variant inactive
    @product_variant.update!(active: false)

    CreatePendingOrdersJob.perform_now

    pending_order = PendingOrder.last
    unavailable = pending_order.unavailable_items

    assert_equal 1, unavailable.length
    assert_equal @product_variant.id, unavailable.first["product_variant_id"]
  end

  test "handles schedule with all items unavailable" do
    @product_variant.update!(active: false)

    # Should still create pending order but with empty available items
    assert_difference "PendingOrder.count", 1 do
      CreatePendingOrdersJob.perform_now
    end

    pending_order = PendingOrder.last
    assert_equal 0, pending_order.items.count
    assert_equal 1, pending_order.unavailable_items.count
  end

  # ==========================================================================
  # Email Sending
  # ==========================================================================

  test "sends reminder email when pending order created" do
    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      CreatePendingOrdersJob.perform_now
    end
  end

  test "does not send email if no pending orders created" do
    @schedule.update!(next_scheduled_date: 10.days.from_now.to_date)

    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      CreatePendingOrdersJob.perform_now
    end
  end

  # ==========================================================================
  # Multiple Schedules
  # ==========================================================================

  test "processes multiple schedules due on same day" do
    user2 = users(:two)
    schedule2 = ReorderSchedule.create!(
      user: user2,
      frequency: :every_week,
      status: :active,
      next_scheduled_date: 3.days.from_now.to_date,
      stripe_payment_method_id: "pm_test_456"
    )
    ReorderScheduleItem.create!(
      reorder_schedule: schedule2,
      product_variant: @product_variant,
      quantity: 1,
      price: @product_variant.price
    )

    assert_difference "PendingOrder.count", 2 do
      CreatePendingOrdersJob.perform_now
    end
  end
end
