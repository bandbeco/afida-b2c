require "test_helper"

class ShippingTest < ActiveSupport::TestCase
  test "STANDARD_COST is 699 pence by default" do
    assert_equal 699, Shipping::STANDARD_COST
  end

  test "FREE_SHIPPING_THRESHOLD is 100 pounds by default" do
    assert_equal BigDecimal("100"), Shipping::FREE_SHIPPING_THRESHOLD
  end

  test "ALLOWED_COUNTRIES includes only GB" do
    assert_equal %w[GB], Shipping::ALLOWED_COUNTRIES
  end

  test "shipping_options_for_subtotal returns free shipping for orders >= £100" do
    options = Shipping.shipping_options_for_subtotal(BigDecimal("100"))

    assert_equal 1, options.length
    assert_equal 0, options.first[:shipping_rate_data][:fixed_amount][:amount]
    assert_equal "Free Shipping", options.first[:shipping_rate_data][:display_name]
  end

  test "shipping_options_for_subtotal returns free shipping for orders > £100" do
    options = Shipping.shipping_options_for_subtotal(BigDecimal("150"))

    assert_equal 0, options.first[:shipping_rate_data][:fixed_amount][:amount]
    assert_equal "Free Shipping", options.first[:shipping_rate_data][:display_name]
  end

  test "shipping_options_for_subtotal returns standard shipping for orders < £100" do
    options = Shipping.shipping_options_for_subtotal(BigDecimal("99.99"))

    assert_equal 1, options.length
    assert_equal 699, options.first[:shipping_rate_data][:fixed_amount][:amount]
    assert_equal "Standard Shipping", options.first[:shipping_rate_data][:display_name]
  end

  test "standard_shipping_option returns correct structure" do
    option = Shipping.standard_shipping_option

    assert_equal "fixed_amount", option[:shipping_rate_data][:type]
    assert_equal 699, option[:shipping_rate_data][:fixed_amount][:amount]
    assert_equal "gbp", option[:shipping_rate_data][:fixed_amount][:currency]
    assert_equal "Standard Shipping", option[:shipping_rate_data][:display_name]
    assert_equal Shipping::STANDARD_MIN_DAYS, option[:shipping_rate_data][:delivery_estimate][:minimum][:value]
    assert_equal Shipping::STANDARD_MAX_DAYS, option[:shipping_rate_data][:delivery_estimate][:maximum][:value]
  end

  test "free_shipping_option returns correct structure" do
    option = Shipping.free_shipping_option

    assert_equal "fixed_amount", option[:shipping_rate_data][:type]
    assert_equal 0, option[:shipping_rate_data][:fixed_amount][:amount]
    assert_equal "gbp", option[:shipping_rate_data][:fixed_amount][:currency]
    assert_equal "Free Shipping", option[:shipping_rate_data][:display_name]
  end

  test "sample_only_shipping_option uses same cost as standard shipping" do
    sample_option = Shipping.sample_only_shipping_option
    standard_option = Shipping.standard_shipping_option

    assert_equal standard_option[:shipping_rate_data][:fixed_amount][:amount],
                 sample_option[:shipping_rate_data][:fixed_amount][:amount]
  end

  test "sample_only_shipping_option uses same delivery estimate as standard shipping" do
    sample_option = Shipping.sample_only_shipping_option
    standard_option = Shipping.standard_shipping_option

    assert_equal standard_option[:shipping_rate_data][:delivery_estimate],
                 sample_option[:shipping_rate_data][:delivery_estimate]
  end

  test "sample_only_shipping_option displays as Standard Shipping" do
    option = Shipping.sample_only_shipping_option

    assert_equal "Standard Shipping", option[:shipping_rate_data][:display_name]
  end
end
