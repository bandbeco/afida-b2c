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


  # The £100 minimum is enforced by Stripe (restrictions.minimum_amount on the
  # WELCOME10 promotion code). The copy must quote the same figure, so it is
  # derived from the shared threshold constant rather than typed into each view.
  test "welcome_discount_minimum is the formatted free-shipping threshold" do
    assert_equal Shipping.formatted_free_shipping_threshold, welcome_discount_minimum
  end

  test "welcome_discount_minimum reads as a whole-pound figure" do
    assert_match(/\A£\d+\z/, welcome_discount_minimum)
  end

  # The condition sentence used under the signup form and in the success box.
  test "welcome_discount_terms names both the minimum and first-order-only rule" do
    assert_equal "On first orders over £100.", welcome_discount_terms
  end

  # The cart preview must not promise a discount Stripe will refuse. Below the
  # minimum the cart still carries the claimed code, so the copy has to say the
  # order does not qualify yet rather than show a saving.
  test "welcome_discount_qualifies? is false below the minimum" do
    cart = Struct.new(:subtotal_amount).new(BigDecimal("99.99"))

    assert_not welcome_discount_qualifies?(cart)
  end

  test "welcome_discount_qualifies? is true at the minimum" do
    cart = Struct.new(:subtotal_amount).new(BigDecimal("100"))

    assert welcome_discount_qualifies?(cart)
  end

  test "welcome_discount_qualifies? is false for a nil cart" do
    assert_not welcome_discount_qualifies?(nil)
  end

  # How much more the customer must add to unlock the discount, for the nudge.
  test "welcome_discount_shortfall is the gap to the minimum" do
    cart = Struct.new(:subtotal_amount).new(BigDecimal("72.50"))

    assert_equal BigDecimal("27.50"), welcome_discount_shortfall(cart)
  end

  test "welcome_discount_shortfall is zero once qualified" do
    cart = Struct.new(:subtotal_amount).new(BigDecimal("120"))

    assert_equal 0, welcome_discount_shortfall(cart)
  end

  # The shipping-display, discount-amount and discount-visibility rules these helpers
  # used to own now live in CartSummary (see test/services/cart_summary_test.rb), the
  # single source for both cart surfaces.
end
