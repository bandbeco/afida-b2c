require "test_helper"

class CartsHelperTest < ActionView::TestCase
  # =============================================================================
  # Welcome discount (first-order) — single source of truth
  # =============================================================================

  test "welcome_discount_percentage is 10" do
    assert_equal 10, welcome_discount_percentage
  end

  # The "you'll save £X" estimate must equal what Stripe actually discounts. The
  # welcome coupon is whole-order, so the saving is the cart's own discount_amount
  # (rate applied to subtotal + shipping), not a re-derived subtotal-only figure.
  # This keeps the success-box copy and the cart-summary discount line in lockstep.
  test "welcome_discount_savings is the cart's whole-order discount amount" do
    cart = Struct.new(:discount_amount).new(BigDecimal("9.27"))

    assert_equal BigDecimal("9.27"), welcome_discount_savings(cart)
  end

  # The shipping-display, discount-amount and discount-visibility rules these helpers
  # used to own now live in CartSummary (see test/services/cart_summary_test.rb), the
  # single source for both cart surfaces.
end
