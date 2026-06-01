require "test_helper"

class WorkingDayCalendarTest < ActiveSupport::TestCase
  setup do
    # Holiday dates are cached; clear so each test sees its own data. No-op
    # under null_store, but keeps the tests correct if the cache store changes.
    Rails.cache.clear
  end

  test "current returns a calendar where weekends are not business days" do
    calendar = WorkingDayCalendar.current

    assert calendar.business_day?(Date.new(2026, 6, 1))      # Monday
    assert_not calendar.business_day?(Date.new(2026, 6, 6))  # Saturday
    assert_not calendar.business_day?(Date.new(2026, 6, 7))  # Sunday
  end

  test "current treats stored bank holidays as non-business days" do
    BankHoliday.replace_division("england-and-wales", [ Date.new(2026, 4, 3) ]) # Good Friday

    calendar = WorkingDayCalendar.current

    assert_not calendar.business_day?(Date.new(2026, 4, 3))
  end

  test "current degrades to a weekend-only calendar when holiday lookup fails" do
    BankHoliday.stubs(:dates).raises(ActiveRecord::StatementInvalid, "boom")

    calendar = WorkingDayCalendar.current

    # Weekends still excluded; weekdays still business days. No raise, no holidays.
    assert calendar.business_day?(Date.new(2026, 4, 3))      # would be a holiday if loaded
    assert_not calendar.business_day?(Date.new(2026, 6, 6))  # Saturday
  end
end
