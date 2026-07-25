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
  # shipping_line_item: shipping is charged as a taxed Stripe line item so that,
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

    assert_equal "true", item[:price_data][:product_data][:metadata]["shipping_line"]
  end

  test "LINE_ITEM_FLAG is keyed by the exposed string key the reader references" do
    # SessionAmounts identifies the shipping line via Shipping::LINE_ITEM_FLAG_KEY /
    # _VALUE; pin that the written flag is keyed by exactly that string, so looking
    # it up by the key works and the writer and reader cannot silently desync.
    assert_equal({ Shipping::LINE_ITEM_FLAG_KEY => Shipping::LINE_ITEM_FLAG_VALUE }, Shipping::LINE_ITEM_FLAG)
    assert_equal Shipping::LINE_ITEM_FLAG_VALUE, Shipping::LINE_ITEM_FLAG[Shipping::LINE_ITEM_FLAG_KEY]
  end

  test "shipping_line_item names the delivery promise so the Stripe modal shows it" do
    # Line items can't carry a delivery_estimate (the old shipping_options did),
    # so the next-working-day promise is surfaced in the line item's name instead.
    item = Shipping.shipping_line_item(tax_rate_id: "txr_123")

    assert_equal "Shipping (next working day)", item[:price_data][:product_data][:name]
  end

  # ==========================================================================
  # Zone surcharges. The delivery cost is the standard cost plus the zone's
  # surcharge, so a non-mainland order stops being priced as if it were local.
  # ==========================================================================

  test "shipping_line_item with no zone charges the standard cost" do
    # Callers that don't know the destination (no postcode captured) keep the
    # existing behaviour rather than guessing a surcharge.
    item = Shipping.shipping_line_item(tax_rate_id: "txr_123")

    assert_equal Shipping::STANDARD_COST, item[:price_data][:unit_amount]
  end

  test "shipping_line_item with the mainland zone charges the standard cost" do
    item = Shipping.shipping_line_item(tax_rate_id: "txr_123", zone: :mainland)

    assert_equal Shipping::STANDARD_COST, item[:price_data][:unit_amount]
  end

  test "shipping_line_item adds the zone surcharge for a surcharged zone" do
    item = Shipping.shipping_line_item(tax_rate_id: "txr_123", zone: :highlands)

    expected = Shipping::STANDARD_COST + (ShippingZone.surcharge(:highlands) * 100).to_i
    assert_equal expected, item[:price_data][:unit_amount]
    assert_operator item[:price_data][:unit_amount], :>, Shipping::STANDARD_COST
  end

  test "shipping_line_item surcharges remote islands more than the highlands" do
    highlands = Shipping.shipping_line_item(tax_rate_id: "txr_123", zone: :highlands)
    islands = Shipping.shipping_line_item(tax_rate_id: "txr_123", zone: :remote_islands)

    assert_operator islands[:price_data][:unit_amount], :>, highlands[:price_data][:unit_amount]
  end

  test "shipping_line_item names the zone's real transit time, not next working day" do
    # The blanket "next working day" name was a promise we cannot keep to the
    # islands, so the name follows the zone's transit time.
    item = Shipping.shipping_line_item(tax_rate_id: "txr_123", zone: :remote_islands)

    assert_equal "Shipping (4 working days)", item[:price_data][:product_data][:name]
  end

  test "shipping_line_item keeps the VAT rate and read-back flag for a surcharged zone" do
    # The surcharge must not cost us the two properties the line item exists for:
    # VAT on delivery, and identifiability in SessionAmounts.
    item = Shipping.shipping_line_item(tax_rate_id: "txr_123", zone: :northern_ireland)

    assert_equal "exclusive", item[:price_data][:tax_behavior]
    assert_equal [ "txr_123" ], item[:tax_rates]
    assert_equal "true", item[:price_data][:product_data][:metadata]["shipping_line"]
  end
end
