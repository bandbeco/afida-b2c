require "test_helper"

class DeliveryEstimateTest < ActiveSupport::TestCase
  # Cutoff is 2pm. Order before cutoff on a working day ships that day for
  # next-working-day delivery. Weekends and bank holidays are skipped.

  # Weekend-only calendar (no bank holidays) for the baseline cases.
  def calendar(holidays = [])
    Business::Calendar.new(working_days: %w[mon tue wed thu fri], holidays: holidays)
  end

  def estimate(time, holidays = [])
    DeliveryEstimate.new(time, calendar: calendar(holidays))
  end

  test "weekday before 2pm delivers next working day" do
    # Monday 12:00 -> dispatch Mon -> delivery Tuesday
    assert_equal Date.new(2026, 6, 2), estimate(Time.zone.local(2026, 6, 1, 12, 0, 0)).delivery_date
  end

  test "weekday after 2pm delivers the working day after next" do
    # Monday 15:00 -> dispatch Tuesday -> delivery Wednesday
    assert_equal Date.new(2026, 6, 3), estimate(Time.zone.local(2026, 6, 1, 15, 0, 0)).delivery_date
  end

  test "weekday exactly at 2pm has missed the cutoff" do
    # Monday 14:00 -> cutoff missed -> dispatch Tuesday -> delivery Wednesday
    assert_equal Date.new(2026, 6, 3), estimate(Time.zone.local(2026, 6, 1, 14, 0, 0)).delivery_date
  end

  test "friday before 2pm delivers monday (skips weekend)" do
    # Friday 12:00 -> dispatch Fri -> delivery Monday, not Saturday
    assert_equal Date.new(2026, 6, 8), estimate(Time.zone.local(2026, 6, 5, 12, 0, 0)).delivery_date
  end

  test "friday after 2pm delivers tuesday" do
    # Friday 15:00 -> dispatch Monday -> delivery Tuesday
    assert_equal Date.new(2026, 6, 9), estimate(Time.zone.local(2026, 6, 5, 15, 0, 0)).delivery_date
  end

  test "saturday delivers tuesday" do
    # Saturday -> dispatch Monday -> delivery Tuesday
    assert_equal Date.new(2026, 6, 9), estimate(Time.zone.local(2026, 6, 6, 10, 0, 0)).delivery_date
  end

  test "sunday delivers tuesday" do
    # Sunday -> dispatch Monday -> delivery Tuesday
    assert_equal Date.new(2026, 6, 9), estimate(Time.zone.local(2026, 6, 7, 10, 0, 0)).delivery_date
  end

  test "skips bank holidays between dispatch and delivery" do
    # Good Friday 2026-04-03 and Easter Monday 2026-04-06 are holidays.
    # Thursday 2 Apr 12:00 -> dispatch Thu -> delivery skips Good Friday,
    # the weekend, and Easter Monday -> Tuesday 7 Apr.
    holidays = [ Date.new(2026, 4, 3), Date.new(2026, 4, 6) ]
    result = estimate(Time.zone.local(2026, 4, 2, 12, 0, 0), holidays).delivery_date
    assert_equal Date.new(2026, 4, 7), result
  end

  test "skips a mid-week bank holiday between dispatch and delivery" do
    # Christmas Day Thu 25 Dec 2025 and Boxing Day Fri 26 Dec 2025 are holidays.
    # Wednesday 24 Dec 12:00 -> dispatch Wed -> delivery skips both holidays and
    # the weekend -> Monday 29 Dec.
    holidays = [ Date.new(2025, 12, 25), Date.new(2025, 12, 26) ]
    result = estimate(Time.zone.local(2025, 12, 24, 12, 0, 0), holidays).delivery_date
    assert_equal Date.new(2025, 12, 29), result
  end

  test "cutoff is evaluated in UK local time during BST" do
    # 14:30 BST is after the 2pm cutoff (it is 13:30 UTC). Monday 1 June is BST.
    # After cutoff -> dispatch Tuesday -> delivery Wednesday.
    assert_equal Date.new(2026, 6, 3), estimate(Time.zone.local(2026, 6, 1, 14, 30, 0)).delivery_date
  end

  test "formatted renders day, date and month" do
    assert_equal "Tuesday, 2 June", estimate(Time.zone.local(2026, 6, 1, 12, 0, 0)).formatted
  end

  test "for_order builds from the order's created_at" do
    order = orders(:one)
    order.update_columns(created_at: Time.zone.local(2026, 6, 1, 12, 0, 0))
    assert_equal Date.new(2026, 6, 2), DeliveryEstimate.for_order(order).delivery_date
  end
end
