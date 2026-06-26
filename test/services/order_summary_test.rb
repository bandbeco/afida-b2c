# frozen_string_literal: true

require "test_helper"

# OrderSummary is the single source of truth for the order-totals lines rendered
# across every order surface (storefront pages, admin page, confirmation emails,
# PDF). These tests pin the line order, labels, money format and the
# discount-visibility rule so no surface can drift.
class OrderSummaryTest < ActiveSupport::TestCase
  # A no-discount order omits the discount line and keeps the canonical order:
  # Subtotal -> Shipping -> VAT -> Total (matching the cart summary).
  test "without a discount lists subtotal, shipping, vat, total in order" do
    kinds = OrderSummary.lines(orders(:one)).map { |l| l[:kind] }
    assert_equal %i[subtotal shipping vat total], kinds
  end

  test "formats each amount as GBP currency" do
    order = orders(:one) # subtotal 9.99, shipping 2.99, vat 1.99, total 14.97

    by_kind = OrderSummary.lines(order).index_by { |l| l[:kind] }
    assert_equal "£9.99", by_kind[:subtotal][:amount]
    assert_equal "£2.99", by_kind[:shipping][:amount]
    assert_equal "£1.99", by_kind[:vat][:amount]
    assert_equal "£14.97", by_kind[:total][:amount]
  end

  test "labels subtotal, shipping and total plainly and vat with the rate" do
    by_kind = OrderSummary.lines(orders(:one)).index_by { |l| l[:kind] }
    assert_equal "Subtotal", by_kind[:subtotal][:label]
    assert_equal "Shipping", by_kind[:shipping][:label]
    assert_equal "VAT (20%)", by_kind[:vat][:label]
    assert_equal "Total", by_kind[:total][:label]
  end

  # A discounted order inserts the discount line AFTER shipping and BEFORE vat,
  # so the discount visibly applies to subtotal + shipping (whole-order coupon).
  test "with a discount inserts the discount line after shipping, before vat" do
    kinds = OrderSummary.lines(build_discounted_order).map { |l| l[:kind] }
    assert_equal %i[subtotal shipping discount vat total], kinds
  end

  test "shows the discount as a negative GBP amount and flags it negative" do
    discount = OrderSummary.lines(build_discounted_order).find { |l| l[:kind] == :discount }
    assert_equal "-£9.27", discount[:amount]
    assert_equal true, discount[:negative]
  end

  test "appends the discount code to the discount label when present" do
    discount = OrderSummary.lines(build_discounted_order).find { |l| l[:kind] == :discount }
    assert_equal "Discount (WELCOME10)", discount[:label]
  end

  test "omits the code from the discount label when blank" do
    discount = OrderSummary.lines(build_discounted_order(code: nil)).find { |l| l[:kind] == :discount }
    assert_equal "Discount", discount[:label]
  end

  # Guards the boundary: a zero discount must not render a "-£0.00" line, even if
  # a code is somehow recorded.
  test "omits the discount line when the amount is zero" do
    order = orders(:one)
    order.discount_amount = 0
    order.discount_code = "WELCOME10"

    kinds = OrderSummary.lines(order).map { |l| l[:kind] }
    assert_not_includes kinds, :discount
  end

  test "flags only the discount line as negative" do
    non_discount = OrderSummary.lines(build_discounted_order).reject { |l| l[:kind] == :discount }
    assert non_discount.none? { |l| l[:negative] }, "only the discount line should be negative"
  end

  private

  def build_discounted_order(code: "WELCOME10")
    # Mirrors a whole-order welcome-coupon order: subtotal 85.70 + shipping 6.99,
    # 10% off (9.27), VAT on the post-discount amount (16.68), total 100.10.
    orders(:one).tap do |o|
      o.subtotal_amount = 85.70
      o.shipping_amount = 6.99
      o.discount_amount = 9.27
      o.discount_code = code
      o.vat_amount = 16.68
      o.total_amount = 100.10
    end
  end
end
