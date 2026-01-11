require "test_helper"

class ReorderSchedulesHelperTest < ActionView::TestCase
  # T004: Tests for order_items_summary helper method

  test "order_items_summary returns correct format for single item" do
    order = orders(:one)
    # Clear existing items and create just one
    order.order_items.destroy_all
    order.order_items.create!(
      product: products(:one),
      product_name: "Test Product",
      product_sku: "TEST-SKU",
      price: 50.00,
      pac_size: 500,
      quantity: 1,
      configuration: {}
    )
    order.reload

    result = order_items_summary(order)

    assert_includes result, "1 item"
    assert_not_includes result, "items" # Should be singular
    assert_includes result, "per delivery"
  end

  test "order_items_summary returns correct format for multiple items" do
    order = orders(:one)
    # Use existing order items from fixture
    order.reload

    result = order_items_summary(order)

    # Should have "items" (plural) if more than one item
    if order.order_items.count > 1
      assert_includes result, "items"
    end
    assert_includes result, "per delivery"
    assert_includes result, "£"
  end

  test "order_items_summary formats currency correctly" do
    order = orders(:one)
    order.reload

    result = order_items_summary(order)

    # Should contain currency symbol and "per delivery"
    assert_match(/£[\d,]+\.\d{2}/, result)
    assert_includes result, "per delivery"
  end

  test "order_items_summary includes item count and total separated by middot" do
    order = orders(:one)
    order.reload

    result = order_items_summary(order)

    # Format: "X items · £Y.YY per delivery"
    assert_includes result, "·"
    assert_match(/\d+ items? · £/, result)
  end
end
