# Single source of truth for the next-working-day delivery promise.
#
# Orders placed before the 2pm cutoff on a working day are dispatched that day
# for next-working-day delivery. Orders after the cutoff (or on a non-working
# day) roll to the next working day's cutoff. Weekends and UK bank holidays are
# never working days.
#
# Working-day maths is delegated to a Business::Calendar (see
# WorkingDayCalendar); the 2pm cutoff lives here because the calendar is
# date-only. This mirrors the customer-facing countdown shown on the product
# page (delivery_countdown_controller.js) so the promise stays consistent from
# product page through to order confirmation.
class DeliveryEstimate
  CUTOFF_HOUR = 14 # 2pm, evaluated in the app time zone (London)

  def self.for_order(order)
    new(order.created_at)
  end

  def initialize(placed_at, calendar: WorkingDayCalendar.current)
    @placed_at = placed_at.in_time_zone
    @calendar = calendar
  end

  # The date the order is expected to be delivered.
  def delivery_date
    @calendar.add_business_days(dispatch_date, 1)
  end

  # e.g. "Tuesday, 2 June"
  def formatted
    delivery_date.strftime("%A, %-d %B")
  end

  private

  # The working day on which the order is dispatched. If placed on a working
  # day before the cutoff, that's today; otherwise the next working day.
  def dispatch_date
    date = @placed_at.to_date

    if @calendar.business_day?(date) && before_cutoff?
      date
    else
      @calendar.roll_forward(date + 1.day)
    end
  end

  def before_cutoff?
    @placed_at.hour < CUTOFF_HOUR
  end
end
