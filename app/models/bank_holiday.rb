# UK bank holidays, sourced from the GOV.UK API and refreshed by
# RefreshBankHolidaysJob. Consumed by WorkingDayCalendar so the delivery
# promise skips non-working days.
class BankHoliday < ApplicationRecord
  DEFAULT_DIVISION = "england-and-wales".freeze

  # All holiday dates for a division, ascending.
  def self.dates(division = DEFAULT_DIVISION)
    where(division: division).order(:date).pluck(:date)
  end

  # Idempotently make the stored holidays for a division exactly match +dates+:
  # insert new ones, prune ones no longer present. Other divisions are untouched.
  def self.replace_division(division, dates)
    dates = dates.map(&:to_date).uniq
    transaction do
      where(division: division).where.not(date: dates).delete_all
      existing = where(division: division).pluck(:date)
      now = Time.current
      rows = (dates - existing).map do |date|
        { division: division, date: date, created_at: now, updated_at: now }
      end
      insert_all(rows) if rows.any?
    end
  end
end
