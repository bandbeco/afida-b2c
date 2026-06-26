# frozen_string_literal: true

require "test_helper"

class OrdersHelperTest < ActionView::TestCase
  # order_summary_lines is the view-layer entry point to the order totals; the
  # canonical behaviour (order, labels, money format, discount rule) is owned and
  # tested by OrderSummary. Here we only assert the helper delegates to it, so
  # templates and the PORO can never diverge.
  test "order_summary_lines delegates to OrderSummary" do
    order = orders(:one)

    assert_equal OrderSummary.lines(order), order_summary_lines(order)
  end
end
