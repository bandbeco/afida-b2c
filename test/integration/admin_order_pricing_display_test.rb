require "test_helper"

class AdminOrderPricingDisplayTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:acme_admin)
    @order = orders(:acme_order)
  end

  test "admin order show page displays pack pricing format for pack-priced items" do
    # Create a pack-priced order item
    order_item = OrderItem.create!(
      order: @order,
      product: products(:one),
      product_name: "Paper Cups 500 Pack",
      product_sku: "CUP-500PK",
      price: 16.00,
      pac_size: 500,
      quantity: 2,
      line_total: 32.00,
      configuration: {}
    )

    sign_in_as(@admin)
    get admin_order_path(@order)

    assert_response :success
    # Pack-priced item should show "£16.00 / pack" format (unit price not shown inline)
    assert_match /£16\.00 \/ pack/, response.body
    # Verify it shows quantity in packs format
    assert_match /2 packs/, response.body
  end

  test "admin order show page displays unit pricing format for branded/configured items" do
    # Create a unit-priced (configured) order item
    order_item = OrderItem.create!(
      order: @order,
      product: products(:one),
      product_name: "Custom Branded Cup",
      product_sku: "BRAND-CUP-12OZ",
      price: 0.18,
      pac_size: 500,
      quantity: 5000,
      line_total: 900.00,
      configuration: { size: "12oz", quantity: 5000 }
    )

    sign_in_as(@admin)
    get admin_order_path(@order)

    assert_response :success
    # Unit-priced item should show "£0.1800 / unit" (no pack price)
    assert_match /£0\.1800 \/ unit/, response.body
    # Should NOT show "/ pack" format for configured items
    refute_match /£0\.1800 \/ pack/, response.body
  end

  private

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
    follow_redirect!
  end
end
