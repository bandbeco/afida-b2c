require "test_helper"

class WorkingDayCalendarTest < ActiveSupport::TestCase
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
end
