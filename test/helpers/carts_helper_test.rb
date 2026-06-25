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

  test "welcome_discount_savings applies the rate to the cart subtotal" do
    cart = carts(:one)

    assert_in_delta cart.subtotal_amount * welcome_discount_rate,
                    welcome_discount_savings(cart),
                    0.0001
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
end
