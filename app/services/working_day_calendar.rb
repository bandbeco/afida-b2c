# Builds the Business::Calendar used for the delivery promise: Monday-Friday
# working days, minus the stored UK bank holidays.
#
# The holiday list is cached so a confirmation/checkout render does not hit the
# database every time. If the calendar can't be built for any reason it falls
# back to a weekend-only calendar, so the delivery promise degrades gracefully
# (never worse than before bank holidays were considered) rather than raising.
class WorkingDayCalendar
  WORKING_DAYS = %w[mon tue wed thu fri].freeze
  CACHE_KEY = "bank_holidays/england-and-wales/v1".freeze
  CACHE_TTL = 6.hours

  class << self
    def current
      build(holiday_dates)
    rescue StandardError => e
      Rails.logger.warn("[WorkingDayCalendar] falling back to weekends-only: #{e.class}: #{e.message}")
      build([])
    end

    private

    def holiday_dates
      Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
        BankHoliday.dates(BankHolidaysFetcher::DIVISION)
      end
    end

    def build(holidays)
      Business::Calendar.new(working_days: WORKING_DAYS, holidays: holidays)
    end
  end
end
