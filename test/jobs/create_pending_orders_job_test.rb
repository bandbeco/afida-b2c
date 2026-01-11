# frozen_string_literal: true

require "test_helper"

class CreatePendingOrdersJobTest < ActiveJob::TestCase
  setup do
    @schedule = reorder_schedules(:active_monthly)
    @user = @schedule.user
    @product_variant = products(:one)
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
    # active_monthly fixture is set to 3.days.from_now.to_date
    initial_count = PendingOrder.count

    CreatePendingOrdersJob.perform_now

    # Should create pending orders for all active schedules due in 3 days
    assert PendingOrder.count > initial_count, "Expected at least one pending order to be created"

    pending_order = @schedule.pending_orders.last
    assert_equal @schedule.next_scheduled_date, pending_order.scheduled_for
    assert_equal "pending", pending_order.status
  end

  test "skips schedules not due in exactly 3 days" do
    # Move our schedule to 5 days out
    @schedule.update!(next_scheduled_date: 5.days.from_now.to_date)

    assert_no_difference -> { @schedule.pending_orders.count } do
      CreatePendingOrdersJob.perform_now
    end
  end

  test "skips paused schedules" do
    paused = reorder_schedules(:paused_schedule)
    # Ensure it would be due in 3 days if it were active
    paused.update!(next_scheduled_date: 3.days.from_now.to_date)

    assert_no_difference -> { paused.pending_orders.count } do
      CreatePendingOrdersJob.perform_now
    end
  end

  test "skips cancelled schedules" do
    cancelled = reorder_schedules(:cancelled_schedule)
    # Ensure it would be due in 3 days if it were active
    cancelled.update!(next_scheduled_date: 3.days.from_now.to_date)

    assert_no_difference -> { cancelled.pending_orders.count } do
      CreatePendingOrdersJob.perform_now
    end
  end

  test "skips schedules that already have pending order for same date" do
    # Create existing pending order for the fixture schedule
    @schedule.pending_orders.create!(
      scheduled_for: @schedule.next_scheduled_date,
      items_snapshot: { "items" => [], "total" => "0.00" }
    )

    assert_no_difference -> { @schedule.pending_orders.count } do
      CreatePendingOrdersJob.perform_now
    end
  end

  test "handles race condition gracefully via database constraint" do
    # Simulate a race condition: another worker created the pending order
    # between when we checked and when we try to create
    #
    # The unique constraint on (reorder_schedule_id, scheduled_for) WHERE status = 0
    # prevents duplicates and raises RecordNotUnique which the job catches
    existing = @schedule.pending_orders.create!(
      scheduled_for: @schedule.next_scheduled_date,
      items_snapshot: { "items" => [], "total" => "0.00" }
    )

    # Even though we try to create, it should skip without error
    assert_nothing_raised do
      CreatePendingOrdersJob.perform_now
    end

    # Only the one we created should exist
    assert_equal 1, @schedule.pending_orders.where(
      scheduled_for: @schedule.next_scheduled_date,
      status: :pending
    ).count
  end

  test "does not send duplicate email when race condition occurs" do
    # Pre-create the pending order
    @schedule.pending_orders.create!(
      scheduled_for: @schedule.next_scheduled_date,
      items_snapshot: { "items" => [], "total" => "0.00" }
    )

    # Count other due schedules that don't have pending orders yet
    other_due_schedules = ReorderSchedule.active.due_in_days(3)
      .where.not(id: @schedule.id)
      .reject { |s| s.pending_orders.pending.exists?(scheduled_for: s.next_scheduled_date) }
      .count

    # Should only send emails for schedules without existing pending orders
    assert_enqueued_jobs other_due_schedules, only: ActionMailer::MailDeliveryJob do
      CreatePendingOrdersJob.perform_now
    end
  end

  # ==========================================================================
  # Items Snapshot Building
  # ==========================================================================

  test "builds items_snapshot with current prices" do
    # Get the first item from fixture
    item = @schedule.reorder_schedule_items.first
    variant = item.product

    # Update the variant price to something different
    original_price = variant.price
    variant.update!(price: 25.00)

    CreatePendingOrdersJob.perform_now

    pending_order = @schedule.pending_orders.last
    items = pending_order.items

    assert items.any?, "Expected items in snapshot"
    snapshot_item = items.find { |i| i["product_id"] == variant.id }
    assert_equal "25.00", snapshot_item["price"] # Current price, not original

    # Restore
    variant.update!(price: original_price)
  end

  test "includes product and variant names in snapshot" do
    CreatePendingOrdersJob.perform_now

    pending_order = @schedule.pending_orders.last
    item = pending_order.items.first

    assert item["product_name"].present?
    assert item["variant_name"].present?
  end

  test "calculates correct totals in snapshot" do
    # Remove extra items and set known values for predictable calculation
    @schedule.reorder_schedule_items.where.not(id: @schedule.reorder_schedule_items.first.id).destroy_all

    item = @schedule.reorder_schedule_items.first
    variant = item.product
    original_price = variant.price
    variant.update!(price: 10.00)
    item.update!(quantity: 2)

    CreatePendingOrdersJob.perform_now

    pending_order = @schedule.pending_orders.last
    snapshot = pending_order.items_snapshot

    # subtotal = 2 * 10.00 = 20.00
    assert_equal "20.00", snapshot["subtotal"]
    # vat = 20% of 20.00 = 4.00
    assert_equal "4.00", snapshot["vat"]
    assert snapshot["total"].present?

    # Restore
    variant.update!(price: original_price)
  end

  # ==========================================================================
  # Handling Unavailable Items
  # ==========================================================================

  test "marks unavailable items in snapshot" do
    item = @schedule.reorder_schedule_items.first
    variant = item.product
    original_active = variant.active

    # Make the product variant inactive
    variant.update!(active: false)

    CreatePendingOrdersJob.perform_now

    pending_order = @schedule.pending_orders.last
    unavailable = pending_order.unavailable_items

    assert unavailable.any? { |u| u["product_id"] == variant.id }

    # Restore
    variant.update!(active: original_active)
  end

  test "handles schedule with all items unavailable" do
    # Make all variants inactive
    original_states = @schedule.reorder_schedule_items.map do |item|
      [ item.product, item.product.active ]
    end

    @schedule.reorder_schedule_items.each do |item|
      item.product.update!(active: false)
    end

    # Should still create pending order but with empty available items
    assert_difference -> { @schedule.pending_orders.count }, 1 do
      CreatePendingOrdersJob.perform_now
    end

    pending_order = @schedule.pending_orders.last
    assert_equal 0, pending_order.items.count
    assert pending_order.unavailable_items.count > 0

    # Restore
    original_states.each { |variant, active| variant.update!(active: active) }
  end

  # ==========================================================================
  # Email Sending
  # ==========================================================================

  test "sends reminder email when pending order created" do
    # Count how many schedules are due in 3 days
    due_schedules = ReorderSchedule.active.due_in_days(3).count

    assert_enqueued_jobs due_schedules, only: ActionMailer::MailDeliveryJob do
      CreatePendingOrdersJob.perform_now
    end
  end

  test "does not send email for schedule if no pending order created" do
    # Move all schedules away from the 3-day window
    ReorderSchedule.active.update_all(next_scheduled_date: 10.days.from_now.to_date)

    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      CreatePendingOrdersJob.perform_now
    end
  end

  # ==========================================================================
  # Multiple Schedules
  # ==========================================================================

  test "processes multiple schedules due on same day" do
    # due_today fixture is for user two, move it to 3 days from now
    due_today = reorder_schedules(:due_today)
    due_today.update!(next_scheduled_date: 3.days.from_now.to_date)

    # Now we have active_monthly (user one) and due_today (user two) both due in 3 days
    due_schedules = ReorderSchedule.active.due_in_days(3)
    expected_count = due_schedules.count

    assert expected_count >= 2, "Expected at least 2 schedules due in 3 days"

    created_count = 0
    due_schedules.each do |schedule|
      created_count += 1 unless schedule.pending_orders.exists?(
        scheduled_for: schedule.next_scheduled_date,
        status: :pending
      )
    end

    assert_difference "PendingOrder.count", created_count do
      CreatePendingOrdersJob.perform_now
    end
  end
end
