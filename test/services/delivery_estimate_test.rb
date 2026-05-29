require "test_helper"

class DeliveryEstimateTest < ActiveSupport::TestCase
  # Cutoff is 2pm. Order before cutoff on a working day ships that day for
  # next-working-day delivery. Weekends are skipped (no Sat/Sun delivery).

  test "weekday before 2pm delivers next working day" do
    # Monday 12:00 -> cutoff today (Mon) -> delivery Tuesday
    estimate = DeliveryEstimate.new(Time.zone.local(2026, 6, 1, 12, 0, 0))
    assert_equal Date.new(2026, 6, 2), estimate.delivery_date
  end

  test "weekday after 2pm delivers the working day after next" do
    # Monday 15:00 -> cutoff Tuesday -> delivery Wednesday
    estimate = DeliveryEstimate.new(Time.zone.local(2026, 6, 1, 15, 0, 0))
    assert_equal Date.new(2026, 6, 3), estimate.delivery_date
  end

  test "weekday exactly at 2pm has missed the cutoff" do
    # Monday 14:00 -> cutoff is missed -> cutoff Tuesday -> delivery Wednesday
    estimate = DeliveryEstimate.new(Time.zone.local(2026, 6, 1, 14, 0, 0))
    assert_equal Date.new(2026, 6, 3), estimate.delivery_date
  end

  test "friday before 2pm delivers monday (skips weekend)" do
    # Friday 12:00 -> cutoff Fri -> delivery Monday, not Saturday
    estimate = DeliveryEstimate.new(Time.zone.local(2026, 6, 5, 12, 0, 0))
    assert_equal Date.new(2026, 6, 8), estimate.delivery_date
  end

  test "friday after 2pm delivers tuesday" do
    # Friday 15:00 -> cutoff Monday -> delivery Tuesday
    estimate = DeliveryEstimate.new(Time.zone.local(2026, 6, 5, 15, 0, 0))
    assert_equal Date.new(2026, 6, 9), estimate.delivery_date
  end

  test "saturday delivers tuesday" do
    # Saturday -> cutoff Monday -> delivery Tuesday
    estimate = DeliveryEstimate.new(Time.zone.local(2026, 6, 6, 10, 0, 0))
    assert_equal Date.new(2026, 6, 9), estimate.delivery_date
  end

  test "sunday delivers tuesday" do
    # Sunday -> cutoff Monday -> delivery Tuesday
    estimate = DeliveryEstimate.new(Time.zone.local(2026, 6, 7, 10, 0, 0))
    assert_equal Date.new(2026, 6, 9), estimate.delivery_date
  end

  test "formatted renders day, date and month" do
    estimate = DeliveryEstimate.new(Time.zone.local(2026, 6, 1, 12, 0, 0))
    assert_equal "Tuesday, 2 June", estimate.formatted
  end

  test "for_order builds from the order's created_at" do
    order = orders(:one)
    order.update_columns(created_at: Time.zone.local(2026, 6, 1, 12, 0, 0))
    assert_equal Date.new(2026, 6, 2), DeliveryEstimate.for_order(order).delivery_date
  end
end
