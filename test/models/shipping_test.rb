require "test_helper"

class ShippingTest < ActiveSupport::TestCase
  test "STANDARD_COST is 699 pence by default" do
    assert_equal 699, Shipping::STANDARD_COST
  end

  test "FREE_SHIPPING_THRESHOLD is 100 pounds by default" do
    assert_equal BigDecimal("100"), Shipping::FREE_SHIPPING_THRESHOLD
  end

  test "standard_cost_in_pounds converts STANDARD_COST pence to pounds" do
    assert_equal 6.99, Shipping.standard_cost_in_pounds
  end

  test "formatted_standard_cost renders STANDARD_COST as a GBP string" do
    assert_equal "£6.99", Shipping.formatted_standard_cost
  end

  test "formatted_free_shipping_threshold renders FREE_SHIPPING_THRESHOLD as a whole-pound GBP string" do
    assert_equal "£100", Shipping.formatted_free_shipping_threshold
  end

  test "ALLOWED_COUNTRIES includes only GB" do
    assert_equal %w[GB], Shipping::ALLOWED_COUNTRIES
  end

  # ==========================================================================
  # shipping_line_item — shipping is charged as a taxed Stripe line item so that,
  # under manual tax rates, Stripe applies VAT to the delivery charge too.
  # ==========================================================================

  test "shipping_line_item charges STANDARD_COST in the configured currency" do
    item = Shipping.shipping_line_item(tax_rate_id: "txr_123")

    assert_equal 1, item[:quantity]
    assert_equal Shipping::STANDARD_COST, item[:price_data][:unit_amount]
    assert_equal Shipping::CURRENCY, item[:price_data][:currency]
  end

  test "shipping_line_item is taxed exclusively at the given VAT rate" do
    item = Shipping.shipping_line_item(tax_rate_id: "txr_123")

    assert_equal "exclusive", item[:price_data][:tax_behavior]
    assert_equal [ "txr_123" ], item[:tax_rates]
  end

  test "shipping_line_item carries product metadata that identifies it on read-back" do
    item = Shipping.shipping_line_item(tax_rate_id: "txr_123")

    assert_equal "true", item[:price_data][:product_data][:metadata][:shipping_line]
  end

  test "shipping_line_item has a human-readable product name" do
    item = Shipping.shipping_line_item(tax_rate_id: "txr_123")

    assert_equal "Shipping", item[:price_data][:product_data][:name]
  end
end
