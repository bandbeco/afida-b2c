# Single source of truth for the next-working-day delivery promise.
#
# Orders placed before the 2pm cutoff on a working day are dispatched that day
# for next-working-day delivery. Orders after the cutoff (or on a non-working
# day) roll to the next working day's cutoff. Weekends and UK bank holidays are
# never working days.
#
# Working-day maths is delegated to a Business::Calendar (see
# WorkingDayCalendar); the 2pm cutoff lives here because the calendar is
# date-only. This is the single source of truth for the delivery promise: the
# product page (via cutoff_at + a dumb JS countdown) and the order confirmation
# both derive their dates from here, so there is no client-side logic to drift.
class DeliveryEstimate
  CUTOFF_HOUR = 14 # 2pm, evaluated in the app time zone (London)

  # Display format for a delivery date, e.g. "Tuesday, 2 June".
  DISPLAY_FORMAT = "%A, %-d %B"

  def self.for_order(order)
    new(order.created_at)
  end

  # Format a stored/computed delivery date for display.
  def self.format(date)
    date.strftime(DISPLAY_FORMAT)
  end

  def initialize(placed_at, calendar: WorkingDayCalendar.current)
    @placed_at = placed_at.in_time_zone
    @calendar = calendar
  end

  # The date the order is expected to be delivered.
  def delivery_date
    @calendar.add_business_days(dispatch_date, 1)
  end

  # The 2pm cutoff instant the order is racing against: 2pm on the dispatch day.
  # The product-page countdown ticks toward this; once it passes, a reload
  # recomputes a later dispatch day.
  def cutoff_at
    dispatch_date.in_time_zone.change(hour: CUTOFF_HOUR)
  end

  # e.g. "Tuesday, 2 June"
  def formatted
    self.class.format(delivery_date)
  end

  private

  # The working day on which the order is dispatched. If placed on a working
  # day before the cutoff, that's today; otherwise the next working day.
  #
  # In the else branch we advance one day before rolling forward so we never
  # dispatch on the placed-on day itself (it's either a non-working day or
  # past the cutoff). roll_forward then snaps to the next business day, skipping
  # any run of weekends/holidays, so the result is always a valid working day.
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
