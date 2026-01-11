require "test_helper"

class ReorderScheduleTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @schedule = ReorderSchedule.new(
      user: @user,
      frequency: :every_month,
      next_scheduled_date: 1.month.from_now.to_date,
      stripe_payment_method_id: "pm_test_123"
    )
  end

  # ==========================================================================
  # Associations
  # ==========================================================================

  test "belongs to user" do
    assert_respond_to @schedule, :user
    assert_equal @user, @schedule.user
  end

  test "has many reorder_schedule_items" do
    assert_respond_to @schedule, :reorder_schedule_items
  end

  test "has many products through reorder_schedule_items" do
    assert_respond_to @schedule, :products
  end

  test "has many pending_orders" do
    assert_respond_to @schedule, :pending_orders
  end

  test "has many orders" do
    assert_respond_to @schedule, :orders
  end

  # ==========================================================================
  # Validations
  # ==========================================================================

  test "valid with all required attributes" do
    assert @schedule.valid?
  end

  test "invalid without user" do
    @schedule.user = nil
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:user], "must exist"
  end

  test "invalid without next_scheduled_date" do
    @schedule.next_scheduled_date = nil
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:next_scheduled_date], "can't be blank"
  end

  test "invalid without stripe_payment_method_id" do
    @schedule.stripe_payment_method_id = nil
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:stripe_payment_method_id], "can't be blank"
  end

  test "invalid with invalid frequency" do
    @schedule.frequency = :invalid_frequency
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:frequency], "is not included in the list"
  end

  test "invalid with invalid status" do
    @schedule.status = :invalid_status
    assert_not @schedule.valid?
    assert_includes @schedule.errors[:status], "is not included in the list"
  end

  test "active schedule requires at least one item on update" do
    @schedule.save!
    product_variant = products(:one)
    item = @schedule.reorder_schedule_items.create!(
      product: product_variant,
      quantity: 1,
      price: product_variant.price
    )

    # Simulate nested attributes removing the item
    @schedule.reorder_schedule_items_attributes = [
      { id: item.id, _destroy: "1" }
    ]

    assert_not @schedule.valid?
    assert_includes @schedule.errors[:base], "Schedule must have at least one item. Pause or cancel instead."
  end

  test "paused schedule can have zero items" do
    @schedule.save!
    @schedule.pause!

    # Paused schedules don't need the item check
    assert @schedule.valid?
  end

  test "new schedule does not require items" do
    # On create, we don't require items (they're added after setup)
    assert @schedule.valid?
  end

  # ==========================================================================
  # Enums
  # ==========================================================================

  test "frequency enum values" do
    assert_equal({ "every_week" => 0, "every_two_weeks" => 1, "every_month" => 2, "every_3_months" => 3 },
                 ReorderSchedule.frequencies)
  end

  test "status enum values" do
    assert_equal({ "active" => 0, "paused" => 1, "cancelled" => 2 },
                 ReorderSchedule.statuses)
  end

  test "default status is active" do
    assert_equal "active", @schedule.status
  end

  # ==========================================================================
  # Scopes
  # ==========================================================================

  test "active scope returns only active schedules" do
    @schedule.save!
    paused_schedule = ReorderSchedule.create!(
      user: @user,
      frequency: :every_week,
      status: :paused,
      next_scheduled_date: 1.week.from_now.to_date,
      stripe_payment_method_id: "pm_test_456"
    )

    active_schedules = ReorderSchedule.active
    assert_includes active_schedules, @schedule
    assert_not_includes active_schedules, paused_schedule
  end

  test "due_in_days scope returns schedules due in specified days" do
    @schedule.next_scheduled_date = 3.days.from_now.to_date
    @schedule.save!

    due_schedule = ReorderSchedule.create!(
      user: @user,
      frequency: :every_week,
      next_scheduled_date: 5.days.from_now.to_date,
      stripe_payment_method_id: "pm_test_456"
    )

    due_in_3_days = ReorderSchedule.due_in_days(3)
    due_in_5_days = ReorderSchedule.due_in_days(5)

    assert_includes due_in_3_days, @schedule
    assert_not_includes due_in_3_days, due_schedule
    assert_includes due_in_5_days, due_schedule
    assert_not_includes due_in_5_days, @schedule
  end

  # ==========================================================================
  # State Methods
  # ==========================================================================

  test "pause! changes status to paused and sets paused_at" do
    @schedule.save!
    freeze_time do
      @schedule.pause!

      assert @schedule.paused?
      assert_equal Time.current, @schedule.paused_at
    end
  end

  test "resume! changes status to active and clears paused_at" do
    @schedule.status = :paused
    @schedule.paused_at = 1.day.ago
    @schedule.save!

    @schedule.resume!

    assert @schedule.active?
    assert_nil @schedule.paused_at
    assert @schedule.next_scheduled_date >= Date.current
  end

  test "resume! with asap calculates next date from today" do
    @schedule.frequency = :every_month
    @schedule.status = :paused
    @schedule.next_scheduled_date = 2.months.ago.to_date
    @schedule.paused_at = 2.months.ago
    @schedule.save!

    @schedule.resume!(resume_type: :asap)

    assert @schedule.active?
    assert_equal Date.current + 1.month, @schedule.next_scheduled_date
  end

  test "resume! with original_schedule advances until future date" do
    @schedule.frequency = :every_month
    @schedule.status = :paused
    @schedule.next_scheduled_date = 2.months.ago.to_date
    @schedule.paused_at = 2.months.ago
    @schedule.save!

    original_date = @schedule.next_scheduled_date

    @schedule.resume!(resume_type: :original_schedule)

    assert @schedule.active?
    # Should advance the original schedule forward until it's in the future
    # 2 months ago + 3 months = 1 month from now
    expected_date = original_date + 3.months
    assert_equal expected_date, @schedule.next_scheduled_date
    assert @schedule.next_scheduled_date > Date.current
  end

  test "resume! with original_schedule keeps date if already in future" do
    @schedule.frequency = :every_month
    @schedule.status = :paused
    @schedule.next_scheduled_date = 1.week.from_now.to_date
    @schedule.paused_at = 1.day.ago
    @schedule.save!

    original_date = @schedule.next_scheduled_date

    @schedule.resume!(resume_type: :original_schedule)

    assert @schedule.active?
    # Date was already in the future, so it should advance by one interval
    # (since the condition is date <= Date.current)
    assert_equal original_date, @schedule.next_scheduled_date
  end

  test "cancel! changes status to cancelled and sets cancelled_at" do
    @schedule.save!
    freeze_time do
      @schedule.cancel!

      assert @schedule.cancelled?
      assert_equal Time.current, @schedule.cancelled_at
    end
  end

  # ==========================================================================
  # Schedule Advancement
  # ==========================================================================

  test "advance_schedule! moves next_scheduled_date by one interval for every_week" do
    @schedule.frequency = :every_week
    @schedule.next_scheduled_date = Date.current
    @schedule.save!

    @schedule.advance_schedule!

    assert_equal Date.current + 1.week, @schedule.next_scheduled_date
  end

  test "advance_schedule! moves next_scheduled_date by one interval for every_two_weeks" do
    @schedule.frequency = :every_two_weeks
    @schedule.next_scheduled_date = Date.current
    @schedule.save!

    @schedule.advance_schedule!

    assert_equal Date.current + 2.weeks, @schedule.next_scheduled_date
  end

  test "advance_schedule! moves next_scheduled_date by one interval for every_month" do
    @schedule.frequency = :every_month
    @schedule.next_scheduled_date = Date.current
    @schedule.save!

    @schedule.advance_schedule!

    assert_equal Date.current + 1.month, @schedule.next_scheduled_date
  end

  test "advance_schedule! moves next_scheduled_date by one interval for every_3_months" do
    @schedule.frequency = :every_3_months
    @schedule.next_scheduled_date = Date.current
    @schedule.save!

    @schedule.advance_schedule!

    assert_equal Date.current + 3.months, @schedule.next_scheduled_date
  end
end
