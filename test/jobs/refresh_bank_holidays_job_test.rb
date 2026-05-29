require "test_helper"

class RefreshBankHolidaysJobTest < ActiveJob::TestCase
  test "persists fetched holidays" do
    BankHolidaysFetcher.stubs(:fetch).returns([ Date.new(2026, 1, 1), Date.new(2026, 12, 25) ])

    RefreshBankHolidaysJob.perform_now

    assert_equal [ Date.new(2026, 1, 1), Date.new(2026, 12, 25) ], BankHoliday.dates("england-and-wales")
  end

  test "leaves existing holidays untouched when the fetch fails" do
    BankHoliday.replace_division("england-and-wales", [ Date.new(2026, 1, 1) ])
    BankHolidaysFetcher.stubs(:fetch).returns(nil)

    RefreshBankHolidaysJob.perform_now

    assert_equal [ Date.new(2026, 1, 1) ], BankHoliday.dates("england-and-wales")
  end

  test "invalidates the cached holiday dates after a successful refresh" do
    BankHolidaysFetcher.stubs(:fetch).returns([ Date.new(2026, 1, 1) ])
    Rails.cache.expects(:delete).with(WorkingDayCalendar::CACHE_KEY)

    RefreshBankHolidaysJob.perform_now
  end

  test "does not touch the cache when the fetch fails" do
    BankHolidaysFetcher.stubs(:fetch).returns(nil)
    Rails.cache.expects(:delete).never

    RefreshBankHolidaysJob.perform_now
  end
end
