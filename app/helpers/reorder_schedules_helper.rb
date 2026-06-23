# frozen_string_literal: true

module ReorderSchedulesHelper
  # Returns a compact summary of order items for the reorder setup page
  # Example: "3 items · £114.99 per delivery"
  def order_items_summary(order)
    count = order.order_items.size
    total = number_to_currency(order.total_amount, unit: "£")
    "#{pluralize(count, 'item')} · #{total} per delivery"
  end

  # The order totals shown on a reorder schedule's preview. Sums the schedule's
  # items into a subtotal, then derives VAT and total through OrderTotals so the
  # formula matches the cart rather than the view hardcoding the VAT rate.
  # :deferred — the preview shows shipping as "calculated at checkout".
  def reorder_schedule_totals(schedule)
    subtotal = schedule.reorder_schedule_items.sum { |item| item.price * item.quantity }
    OrderTotals.for(subtotal, shipping: :deferred)
  end
end
