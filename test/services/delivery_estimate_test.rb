require "test_helper"

class DeliveryEstimateTest < ActiveSupport::TestCase
  # Cutoff is 2pm. Order before cutoff on a working day ships that day for
  # next-working-day delivery. Weekends and bank holidays are skipped.

  # Weekend-only calendar (no bank holidays) for the baseline cases.
  def calendar(holidays = [])
    Business::Calendar.new(working_days: %w[mon tue wed thu fri], holidays: holidays)
  end

  def estimate(time, holidays = [], zone: :mainland)
    DeliveryEstimate.new(time, calendar: calendar(holidays), zone: zone)
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

  # cutoff_at: the 2pm instant the live countdown ticks toward (2pm on the
  # dispatch day, which is the day the order ships if placed in time).

  test "cutoff_at is 2pm today when placed on a working day before cutoff" do
    assert_equal Time.zone.local(2026, 6, 1, 14, 0, 0),
                 estimate(Time.zone.local(2026, 6, 1, 12, 0, 0)).cutoff_at
  end

  test "cutoff_at rolls to the next working day's 2pm when past cutoff" do
    # Monday 15:00 -> next cutoff is Tuesday 2pm
    assert_equal Time.zone.local(2026, 6, 2, 14, 0, 0),
                 estimate(Time.zone.local(2026, 6, 1, 15, 0, 0)).cutoff_at
  end

  test "cutoff_at skips the weekend" do
    # Saturday -> next cutoff is Monday 2pm
    assert_equal Time.zone.local(2026, 6, 8, 14, 0, 0),
                 estimate(Time.zone.local(2026, 6, 6, 10, 0, 0)).cutoff_at
  end

  test "cutoff_at is the dispatch day, distinct from the delivery day" do
    # Good Friday 3 Apr + Easter Monday 6 Apr are holidays. Thursday 2 Apr 12:00
    # is a working day before cutoff, so the cutoff is Thursday 2pm even though
    # delivery rolls all the way to Tuesday 7 Apr.
    holidays = [ Date.new(2026, 4, 3), Date.new(2026, 4, 6) ]
    est = estimate(Time.zone.local(2026, 4, 2, 12, 0, 0), holidays)
    assert_equal Time.zone.local(2026, 4, 2, 14, 0, 0), est.cutoff_at
    assert_equal Date.new(2026, 4, 7), est.delivery_date
  end

  # ==========================================================================
  # Delivery zone. DPD rates the Highlands and Northern Ireland at 2 days and
  # HS/ZE/KW15-17 at 2-4 days, so those destinations cannot be promised
  # next-working-day at any price. A real order to Stornoway was sold exactly
  # that promise, which is what these cases exist to prevent.
  # ==========================================================================

  test "zone defaults to mainland, keeping the next-working-day promise" do
    # Monday 12:00 -> dispatch Mon -> delivery Tuesday, unchanged.
    assert_equal Date.new(2026, 6, 2), estimate(Time.zone.local(2026, 6, 1, 12, 0, 0)).delivery_date
  end

  test "every off-mainland zone is planned to the same day" do
    # Afida leadership set one off-mainland service level (2-4 working days,
    # planned to day 4), so no zone is promised sooner than another.
    placed = Time.zone.local(2026, 6, 1, 12, 0, 0) # Monday
    dates = (ShippingZone::ZONES - [ :mainland ]).map do |zone|
      estimate(placed, zone: zone).delivery_date
    end

    assert_equal 1, dates.uniq.size, "expected one off-mainland promise, got #{dates.uniq.inspect}"
  end

  test "off-mainland lands on the fourth working day after dispatch" do
    # Monday 12:00 -> dispatch Mon -> +4 working days -> Friday 5 June.
    assert_equal Date.new(2026, 6, 5),
                 estimate(Time.zone.local(2026, 6, 1, 12, 0, 0), zone: :highlands).delivery_date
  end

  test "off-mainland transit skips weekends like every other working-day hop" do
    # Thursday 12:00 -> dispatch Thu -> +4 working days, hopping the weekend,
    # lands Wednesday 10 June rather than counting calendar days.
    assert_equal Date.new(2026, 6, 10),
                 estimate(Time.zone.local(2026, 6, 4, 12, 0, 0), zone: :highlands).delivery_date
  end

  test "off-mainland transit skips bank holidays too" do
    # Monday 1 June 12:00 with Tuesday 2 June a holiday: dispatch Mon, then four
    # working days stepping over the holiday lands Monday 8 June.
    holidays = [ Date.new(2026, 6, 2) ]
    assert_equal Date.new(2026, 6, 8),
                 estimate(Time.zone.local(2026, 6, 1, 12, 0, 0), holidays, zone: :highlands).delivery_date
  end

  test "an unknown zone falls back to the mainland promise" do
    assert_equal estimate(Time.zone.local(2026, 6, 1, 12, 0, 0)).delivery_date,
                 estimate(Time.zone.local(2026, 6, 1, 12, 0, 0), zone: :unknown).delivery_date
  end

  test "the zone never moves the dispatch cutoff" do
    # The cutoff is about when we hand the parcel over, which does not change
    # with the destination; only the transit after dispatch does.
    mainland = estimate(Time.zone.local(2026, 6, 1, 12, 0, 0))
    islands = estimate(Time.zone.local(2026, 6, 1, 12, 0, 0), zone: :remote_islands)

    assert_equal mainland.cutoff_at, islands.cutoff_at
  end

  test "for_order derives the zone from the order's shipping postcode" do
    # The order records where it actually shipped, so the promise shown on the
    # confirmation reflects that destination rather than assuming mainland.
    order = orders(:one)
    order.update_columns(created_at: Time.zone.local(2026, 6, 1, 12, 0, 0),
                         shipping_postal_code: "IV51 9YB")

    assert_equal :highlands, DeliveryEstimate.for_order(order).zone
  end

  test "for_order falls back to mainland when the stored postcode is unusable" do
    # shipping_postal_code is NOT NULL, but Stripe can hand back something we
    # can't parse. The confirmation page must still show a date.
    order = orders(:one)
    order.update_columns(created_at: Time.zone.local(2026, 6, 1, 12, 0, 0),
                         shipping_postal_code: "")

    assert_equal :mainland, DeliveryEstimate.for_order(order).zone
    assert_equal Date.new(2026, 6, 2), DeliveryEstimate.for_order(order).delivery_date
  end
end
