# Single source of truth for the next-working-day delivery promise.
#
# Orders placed before the 2pm cutoff on a working day are dispatched that day
# for next-working-day delivery. Orders after the cutoff (or on a weekend) roll
# to the next working day's cutoff. Weekends are never delivery days.
#
# This mirrors the customer-facing countdown shown on the product page
# (delivery_countdown_controller.js) so the promise stays consistent from
# product page through to order confirmation.
class DeliveryEstimate
  CUTOFF_HOUR = 14 # 2pm

  def self.for_order(order)
    new(order.created_at)
  end

  def initialize(placed_at)
    @placed_at = placed_at.in_time_zone
  end

  # The date the order is expected to be delivered.
  def delivery_date
    next_working_day(cutoff_date)
  end

  # e.g. "Tuesday, 2 June"
  def formatted
    delivery_date.strftime("%A, %-d %B")
  end

  private

  # The working day on which the order is dispatched. If placed on a working
  # day before the cutoff, that's today; otherwise the next working day.
  def cutoff_date
    date = @placed_at.to_date

    if working_day?(date) && before_cutoff?
      date
    else
      next_working_day(date)
    end
  end

  def before_cutoff?
    @placed_at.hour < CUTOFF_HOUR
  end

  def next_working_day(date)
    date += 1.day
    date += 1.day until working_day?(date)
    date
  end

  def working_day?(date)
    !date.saturday? && !date.sunday?
  end
end
