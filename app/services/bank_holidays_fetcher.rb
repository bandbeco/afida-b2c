# frozen_string_literal: true

require "http"

# Fetches UK bank holidays from the GOV.UK API.
#
# Returns the holiday dates for the England & Wales division, or nil on any
# failure (network, non-200, malformed payload). It never raises and never
# writes; persistence is the caller's job (see RefreshBankHolidaysJob), so a
# transient GOV.UK outage can never empty the stored holidays.
#
# API reference: https://www.gov.uk/bank-holidays.json
class BankHolidaysFetcher
  ENDPOINT = "https://www.gov.uk/bank-holidays.json"
  DIVISION = "england-and-wales"
  TIMEOUT_SECONDS = 5

  class << self
    # @return [Array<Date>, nil] holiday dates, or nil on failure
    def fetch
      new.fetch
    end
  end

  def fetch
    response = HTTP.timeout(TIMEOUT_SECONDS).get(ENDPOINT)
    return log_failure("status #{response.status}") unless response.status.success?

    events = JSON.parse(response.body.to_s).dig(DIVISION, "events")
    return log_failure("no events for #{DIVISION}") if events.blank?

    events.map { |event| Date.iso8601(event.fetch("date")) }
  rescue HTTP::Error, JSON::ParserError, KeyError, ArgumentError => e
    log_failure("#{e.class}: #{e.message}")
  end

  private

  def log_failure(message)
    Rails.logger.warn("[BankHolidaysFetcher] #{message}")
    nil
  end
end
