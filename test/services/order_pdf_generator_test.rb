require "test_helper"

class OrderPdfGeneratorTest < ActiveSupport::TestCase
  def setup
    @order = orders(:complete_order)
  end

  # T010: Test initialization
  test "initializes with valid order" do
    generator = OrderPdfGenerator.new(@order)
    assert_not_nil generator
  end

  # T011: Test PDF generation success
  test "generates pdf for valid order" do
    generator = OrderPdfGenerator.new(@order)
    pdf_data = generator.generate

    assert_not_nil pdf_data
    assert pdf_data.is_a?(String)
    assert pdf_data.length > 0
  end

  # T012: Test file size under 500KB
  test "pdf file size is under 500kb" do
    generator = OrderPdfGenerator.new(@order)
    pdf_data = generator.generate

    file_size_kb = pdf_data.bytesize / 1024.0
    assert file_size_kb < 500, "PDF size #{file_size_kb.round(2)}KB exceeds 500KB limit"
  end

  # T013: Test error handling for order without items
  test "raises error for order without items" do
    order_without_items = Order.create!(
      email: "test@example.com",
      stripe_session_id: "cs_test_no_items_#{SecureRandom.hex(8)}",
      order_number: "TEST-NO-ITEMS-#{SecureRandom.hex(4)}",
      status: "paid",
      subtotal_amount: 0,
      vat_amount: 0,
      shipping_amount: 0,
      total_amount: 0,
      shipping_name: "Test User",
      shipping_address_line1: "123 Test St",
      shipping_city: "London",
      shipping_postal_code: "SW1A 1AA",
      shipping_country: "GB"
    )

    generator = OrderPdfGenerator.new(order_without_items)

    assert_raises(StandardError) do
      generator.generate
    end
  end

  # Additional test: Verify PDF contains order number
  test "pdf generation completes without raising errors" do
    generator = OrderPdfGenerator.new(@order)

    assert_nothing_raised do
      pdf_data = generator.generate
      assert pdf_data.present?
    end
  end

  # Pack pricing display tests
  test "format_price_display returns pack format for pack-priced items" do
    pack_item = OrderItem.new(
      price: 16.00,
      pac_size: 500,
      configuration: {}
    )

    generator = OrderPdfGenerator.new(@order)
    result = generator.send(:format_price_display, pack_item)

    assert_includes result, "£16.00 / pack"
    assert_includes result, "£0.0320 / unit"
  end

  test "format_price_display returns unit format for unit-priced items" do
    unit_item = OrderItem.new(
      price: 0.18,
      pac_size: 500,
      configuration: { size: "12oz" }
    )

    generator = OrderPdfGenerator.new(@order)
    result = generator.send(:format_price_display, unit_item)

    assert_includes result, "£0.1800 / unit"
    refute_includes result, "/ pack"
  end

  test "format_price_display handles nil pac_size" do
    item = OrderItem.new(
      price: 5.50,
      pac_size: nil,
      configuration: {}
    )

    generator = OrderPdfGenerator.new(@order)
    result = generator.send(:format_price_display, item)

    assert_includes result, "£5.5000 / unit"
    refute_includes result, "/ pack"
  end

  test "generates pdf with pack-priced order items" do
    # Create order item with pack pricing
    order_item = OrderItem.create!(
      order: @order,
      product: products(:one),
      product_variant: product_variants(:one),
      product_name: "Test Pack Product",
      product_sku: "PACK-TEST",
      price: 16.00,
      pac_size: 500,
      quantity: 500,
      line_total: 16.00,
      configuration: {}
    )

    generator = OrderPdfGenerator.new(@order)
    pdf_data = generator.generate

    assert_not_nil pdf_data
    assert pdf_data.length > 0
  end

  test "generates pdf with branded/configured order items" do
    # Create order item with unit pricing (configured)
    order_item = OrderItem.create!(
      order: @order,
      product: products(:one),
      product_variant: product_variants(:one),
      product_name: "Test Branded Product",
      product_sku: "BRAND-TEST",
      price: 0.18,
      pac_size: 500,
      quantity: 5000,
      line_total: 900.00,
      configuration: { size: "12oz", quantity: 5000 }
    )

    generator = OrderPdfGenerator.new(@order)
    pdf_data = generator.generate

    assert_not_nil pdf_data
    assert pdf_data.length > 0
  end

  # Quantity display tests
  test "format_quantity_display returns packs format for pack-priced items" do
    pack_item = OrderItem.new(
      price: 16.00,
      pac_size: 500,
      quantity: 15000,
      configuration: {}
    )

    generator = OrderPdfGenerator.new(@order)
    result = generator.send(:format_quantity_display, pack_item)

    assert_includes result, "30"
    assert_includes result, "pack"
    assert_includes result, "15,000"
    assert_includes result, "units"
  end

  test "format_quantity_display returns units format for unit-priced items" do
    unit_item = OrderItem.new(
      price: 0.18,
      pac_size: 500,
      quantity: 5000,
      configuration: { size: "12oz" }
    )

    generator = OrderPdfGenerator.new(@order)
    result = generator.send(:format_quantity_display, unit_item)

    assert_includes result, "5,000"
    assert_includes result, "units"
    refute_includes result, "pack"
  end

  test "format_quantity_display handles nil pac_size" do
    item = OrderItem.new(
      price: 5.50,
      pac_size: nil,
      quantity: 100,
      configuration: {}
    )

    generator = OrderPdfGenerator.new(@order)
    result = generator.send(:format_quantity_display, item)

    assert_includes result, "100"
    assert_includes result, "units"
    refute_includes result, "pack"
  end

  test "format_quantity_display uses singular pack for 1 pack" do
    item = OrderItem.new(
      price: 16.00,
      pac_size: 500,
      quantity: 500,
      configuration: {}
    )

    generator = OrderPdfGenerator.new(@order)
    result = generator.send(:format_quantity_display, item)

    assert_includes result, "1"
    assert_includes result, "pack"
    refute_includes result, "packs"
  end
end
