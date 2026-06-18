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
end
