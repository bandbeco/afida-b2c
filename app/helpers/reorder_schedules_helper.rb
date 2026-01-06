# frozen_string_literal: true

module ReorderSchedulesHelper
  # Returns a compact summary of order items for the reorder setup page
  # Example: "3 items · £114.99 per delivery"
  def order_items_summary(order)
    count = order.order_items.size
    total = number_to_currency(order.total_amount, unit: "£")
    "#{pluralize(count, 'item')} · #{total} per delivery"
  end
end
