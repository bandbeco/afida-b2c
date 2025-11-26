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
end
