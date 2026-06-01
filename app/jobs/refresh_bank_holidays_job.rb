# Refreshes the stored UK bank holidays from the GOV.UK API.
#
# Scheduled daily (see config/recurring.yml). On a fetch failure the existing
# rows are left untouched, so a GOV.UK outage never empties the holiday table.
class RefreshBankHolidaysJob < ApplicationJob
  queue_as :default

  def perform
    dates = BankHolidaysFetcher.fetch
    return if dates.nil?

    BankHoliday.replace_division(BankHolidaysFetcher::DIVISION, dates)
    # Drop the cached holiday list so renders pick up the refresh before the
    # 6-hour TTL would otherwise expire.
    Rails.cache.delete(WorkingDayCalendar::CACHE_KEY)
  end
end
