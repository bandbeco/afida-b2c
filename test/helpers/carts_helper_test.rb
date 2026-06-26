require "test_helper"

class CartsHelperTest < ActionView::TestCase
  # =============================================================================
  # Welcome discount (first-order) — single source of truth
  # =============================================================================

  test "welcome_discount_percentage is 10" do
    assert_equal 10, welcome_discount_percentage
  end

  test "welcome_discount_rate is the percentage as a fraction" do
    assert_in_delta 0.10, welcome_discount_rate, 0.0001
  end

  # The "you'll save £X" estimate must equal what Stripe actually discounts. The
  # welcome coupon is whole-order, so the saving is the cart's own discount_amount
  # (rate applied to subtotal + shipping), not a re-derived subtotal-only figure.
  # This keeps the success-box copy and the cart-summary discount line in lockstep.
  test "welcome_discount_savings is the cart's whole-order discount amount" do
    cart = Struct.new(:discount_amount).new(BigDecimal("9.27"))

    assert_equal BigDecimal("9.27"), welcome_discount_savings(cart)
  end

  # =============================================================================
  # cart_shipping_display: the cart preview's shipping line
  # =============================================================================

  test "cart_shipping_display shows the currency amount when shipping is charged" do
    cart = Struct.new(:shipping_amount).new(BigDecimal("6.99"))

    assert_equal number_to_currency(BigDecimal("6.99")), cart_shipping_display(cart)
  end

  test "cart_shipping_display shows Free when shipping is zero" do
    cart = Struct.new(:shipping_amount).new(BigDecimal("0"))

    assert_equal "Free", cart_shipping_display(cart)
  end

  test "cart_shipping_display falls back to Calculate at checkout when shipping is unknown" do
    cart = Struct.new(:shipping_amount).new(nil)

    assert_equal "Calculate at checkout", cart_shipping_display(cart)
  end

  # =============================================================================
  # cart_discount_display: the cart preview's discount line (shown when relevant)
  # =============================================================================

  test "cart_discount_display shows the discount as a negative currency amount" do
    cart = Struct.new(:discount_amount).new(BigDecimal("2.00"))

    assert_equal "-#{number_to_currency(BigDecimal('2.00'), unit: '£')}", cart_discount_display(cart)
  end

  test "cart_has_discount? is true only for a positive discount" do
    assert cart_has_discount?(Struct.new(:discount_amount).new(BigDecimal("2.00")))
    assert_not cart_has_discount?(Struct.new(:discount_amount).new(BigDecimal("0")))
  end
end
