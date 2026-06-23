# frozen_string_literal: true

module ReorderSchedulesHelper
  # Returns a compact summary of order items for the reorder setup page
  # Example: "3 items · £114.99 per delivery"
  def order_items_summary(order)
    count = order.order_items.size
    total = number_to_currency(order.total_amount, unit: "£")
    "#{pluralize(count, 'item')} · #{total} per delivery"
  end

  # The order totals shown on a reorder schedule's preview. The schedule owns
  # summing its items into a subtotal; OrderTotals derives VAT and total so the
  # formula matches the cart rather than the view hardcoding the VAT rate.
  # :deferred — the preview shows shipping as "calculated at checkout".
  def reorder_schedule_totals(schedule)
    OrderTotals.for(schedule.subtotal_amount, shipping: :deferred)
  end
end
