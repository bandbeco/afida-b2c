require "test_helper"

class ExpirePendingOrdersJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @user.update!(stripe_customer_id: "cus_test_123")
    @product_variant = product_variants(:one)

    @schedule = ReorderSchedule.create!(
      user: @user,
      frequency: :every_month,
      status: :active,
      next_scheduled_date: Date.current,
      stripe_payment_method_id: "pm_test_456"
    )
  end

  # ==========================================================================
  # Basic Expiration
  # ==========================================================================

  test "expires pending orders past expiration window" do
    # Create pending order that is past expiration (8+ days old)
    pending_order = create_pending_order(scheduled_for: 10.days.ago.to_date)
    assert pending_order.pending?

    ExpirePendingOrdersJob.perform_now

    pending_order.reload
    assert pending_order.expired?
  end

  test "does not expire recently created pending orders" do
    # Create pending order within expiration window (less than 7 days)
    pending_order = create_pending_order(scheduled_for: 3.days.ago.to_date)
    assert pending_order.pending?

    ExpirePendingOrdersJob.perform_now

    pending_order.reload
    assert pending_order.pending?
  end

  test "does not expire already confirmed pending orders" do
    pending_order = create_pending_order(scheduled_for: 10.days.ago.to_date)
    pending_order.update!(status: :confirmed, confirmed_at: Time.current)

    ExpirePendingOrdersJob.perform_now

    pending_order.reload
    assert pending_order.confirmed?
  end

  test "does not expire already expired pending orders" do
    pending_order = create_pending_order(scheduled_for: 10.days.ago.to_date)
    pending_order.expire!

    ExpirePendingOrdersJob.perform_now

    pending_order.reload
    assert pending_order.expired?
  end

  # ==========================================================================
  # Email Notifications
  # ==========================================================================

  test "sends expiration email when pending order expires" do
    create_pending_order(scheduled_for: 10.days.ago.to_date)

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      ExpirePendingOrdersJob.perform_now
    end
  end

  test "does not send email for already expired orders" do
    pending_order = create_pending_order(scheduled_for: 10.days.ago.to_date)
    pending_order.expire!

    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      ExpirePendingOrdersJob.perform_now
    end
  end

  # ==========================================================================
  # Edge Cases
  # ==========================================================================

  test "handles multiple pending orders from different schedules" do
    other_schedule = ReorderSchedule.create!(
      user: users(:two),
      frequency: :every_week,
      status: :active,
      next_scheduled_date: Date.current,
      stripe_payment_method_id: "pm_test_789"
    )

    old_pending1 = create_pending_order(scheduled_for: 10.days.ago.to_date)
    old_pending2 = create_pending_order_for_schedule(other_schedule, scheduled_for: 10.days.ago.to_date)
    recent_pending = create_pending_order(scheduled_for: 2.days.ago.to_date)

    ExpirePendingOrdersJob.perform_now

    old_pending1.reload
    old_pending2.reload
    recent_pending.reload

    assert old_pending1.expired?
    assert old_pending2.expired?
    assert recent_pending.pending?
  end

  test "job is idempotent - running twice has same effect" do
    pending_order = create_pending_order(scheduled_for: 10.days.ago.to_date)

    ExpirePendingOrdersJob.perform_now
    ExpirePendingOrdersJob.perform_now

    pending_order.reload
    assert pending_order.expired?
  end

  private

  def create_pending_order(scheduled_for:)
    create_pending_order_for_schedule(@schedule, scheduled_for: scheduled_for)
  end

  def create_pending_order_for_schedule(schedule, scheduled_for:)
    PendingOrder.create!(
      reorder_schedule: schedule,
      scheduled_for: scheduled_for,
      items_snapshot: {
        "items" => [
          {
            "product_variant_id" => @product_variant.id,
            "product_name" => "Test Product",
            "variant_name" => "Pack of 500",
            "quantity" => 2,
            "price" => "10.00",
            "available" => true
          }
        ],
        "subtotal" => "20.00",
        "vat" => "4.00",
        "shipping" => "0.00",
        "total" => "24.00",
        "unavailable_items" => []
      }
    )
  end
end
