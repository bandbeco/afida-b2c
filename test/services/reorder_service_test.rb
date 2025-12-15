# frozen_string_literal: true

require "test_helper"

class ReorderServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @order = orders(:one)
    # Clear any fixture-created order items for a clean slate
    @order.order_items.destroy_all
    @cart = Cart.create!(user: @user)

    # Create some active product variants for testing
    @active_variant = ProductVariant.create!(
      product: products(:one),
      name: "Reorder Test Active",
      sku: "REORDER-ACTIVE-1",
      price: 16.00,
      active: true
    )

    @inactive_variant = ProductVariant.create!(
      product: products(:one),
      name: "Reorder Test Inactive",
      sku: "REORDER-INACTIVE-1",
      price: 16.00,
      active: false
    )
  end

  # Success scenarios
  test "adds all available items from order to cart" do
    # Create order with available items
    @order.order_items.create!(
      product_variant: @active_variant,
      product: @active_variant.product,
      product_name: @active_variant.name,
      product_sku: @active_variant.sku,
      price: @active_variant.price,
      quantity: 2,
      line_total: @active_variant.price * 2
    )

    result = ReorderService.call(order: @order, cart: @cart)

    assert result.success?
    assert_equal 1, result.added_count
    assert_equal [], result.skipped_items
    assert_equal 1, @cart.reload.cart_items.count
    assert_equal 2, @cart.cart_items.first.quantity
  end

  test "returns added_count for multiple items" do
    variant2 = ProductVariant.create!(
      product: products(:one),
      name: "Reorder Test Second",
      sku: "REORDER-SECOND-1",
      price: 20.00,
      active: true
    )

    @order.order_items.create!(
      product_variant: @active_variant,
      product: @active_variant.product,
      product_name: @active_variant.name,
      product_sku: @active_variant.sku,
      price: @active_variant.price,
      quantity: 1,
      line_total: @active_variant.price
    )
    @order.order_items.create!(
      product_variant: variant2,
      product: variant2.product,
      product_name: variant2.name,
      product_sku: variant2.sku,
      price: variant2.price,
      quantity: 3,
      line_total: variant2.price * 3
    )

    result = ReorderService.call(order: @order, cart: @cart)

    assert result.success?
    assert_equal 2, result.added_count
    assert_equal 2, @cart.reload.cart_items.count
  end

  # Partial success scenarios
  test "skips unavailable items and adds available ones" do
    @order.order_items.create!(
      product_variant: @active_variant,
      product: @active_variant.product,
      product_name: @active_variant.name,
      product_sku: @active_variant.sku,
      price: @active_variant.price,
      quantity: 1,
      line_total: @active_variant.price
    )
    @order.order_items.create!(
      product_variant: @inactive_variant,
      product: @inactive_variant.product,
      product_name: @inactive_variant.name,
      product_sku: @inactive_variant.sku,
      price: @inactive_variant.price,
      quantity: 2,
      line_total: @inactive_variant.price * 2
    )

    result = ReorderService.call(order: @order, cart: @cart)

    assert result.success?
    assert_equal 1, result.added_count
    assert_equal 1, result.skipped_items.length
    assert_equal @inactive_variant.name, result.skipped_items.first[:name]
    assert_equal 1, @cart.reload.cart_items.count
  end

  test "skipped_items includes reason for unavailability" do
    @order.order_items.create!(
      product_variant: @inactive_variant,
      product: @inactive_variant.product,
      product_name: @inactive_variant.name,
      product_sku: @inactive_variant.sku,
      price: @inactive_variant.price,
      quantity: 1,
      line_total: @inactive_variant.price
    )

    result = ReorderService.call(order: @order, cart: @cart)

    skipped = result.skipped_items.first
    assert skipped[:name].present?
    assert skipped[:reason].present?
  end

  # Failure scenarios
  test "returns failure when all items are unavailable" do
    @order.order_items.create!(
      product_variant: @inactive_variant,
      product: @inactive_variant.product,
      product_name: @inactive_variant.name,
      product_sku: @inactive_variant.sku,
      price: @inactive_variant.price,
      quantity: 1,
      line_total: @inactive_variant.price
    )

    result = ReorderService.call(order: @order, cart: @cart)

    assert_not result.success?
    assert_equal 0, result.added_count
    assert_equal 1, result.skipped_items.length
    assert result.error.present?
  end

  test "returns failure for order with no items" do
    @order.order_items.destroy_all

    result = ReorderService.call(order: @order, cart: @cart)

    assert_not result.success?
    assert result.error.present?
  end

  # Cart merging scenarios
  test "merges with existing cart items by updating quantity" do
    # Pre-existing item in cart
    @cart.cart_items.create!(
      product_variant: @active_variant,
      price: @active_variant.price,
      quantity: 1
    )

    @order.order_items.create!(
      product_variant: @active_variant,
      product: @active_variant.product,
      product_name: @active_variant.name,
      product_sku: @active_variant.sku,
      price: @active_variant.price,
      quantity: 2,
      line_total: @active_variant.price * 2
    )

    result = ReorderService.call(order: @order, cart: @cart)

    assert result.success?
    @cart.reload
    assert_equal 1, @cart.cart_items.count
    # Should add to existing: 1 + 2 = 3
    assert_equal 3, @cart.cart_items.first.quantity
  end

  test "adds new items without affecting existing different items" do
    other_variant = ProductVariant.create!(
      product: products(:one),
      name: "Other Item",
      sku: "OTHER-ITEM-1",
      price: 12.00,
      active: true
    )

    # Pre-existing different item in cart
    @cart.cart_items.create!(
      product_variant: other_variant,
      price: other_variant.price,
      quantity: 5
    )

    @order.order_items.create!(
      product_variant: @active_variant,
      product: @active_variant.product,
      product_name: @active_variant.name,
      product_sku: @active_variant.sku,
      price: @active_variant.price,
      quantity: 2,
      line_total: @active_variant.price * 2
    )

    result = ReorderService.call(order: @order, cart: @cart)

    assert result.success?
    @cart.reload
    assert_equal 2, @cart.cart_items.count
    assert_equal 5, @cart.cart_items.find_by(product_variant: other_variant).quantity
    assert_equal 2, @cart.cart_items.find_by(product_variant: @active_variant).quantity
  end

  # Edge cases
  test "handles inactive products gracefully" do
    # Create order item where the product variant's product was deactivated
    inactive_product = Product.create!(
      name: "Inactive Product for Reorder",
      slug: "inactive-product-reorder",
      category: categories(:one),
      active: false
    )
    variant_with_inactive_product = ProductVariant.create!(
      product: inactive_product,
      name: "Variant of Inactive Product",
      sku: "INACTIVE-PROD-VAR",
      price: 10.00,
      active: true
    )

    @order.order_items.create!(
      product_variant: variant_with_inactive_product,
      product: inactive_product,
      product_name: "Inactive Product",
      product_sku: "INACTIVE-PROD-VAR",
      price: 10.00,
      quantity: 1,
      line_total: 10.00
    )

    result = ReorderService.call(order: @order, cart: @cart)

    assert_not result.success? # No available items (product inactive)
    assert result.skipped_items.any? { |item| item[:reason].include?("no longer available") }
  end

  test "skips configured/branded items" do
    # Configured items have custom configurations and shouldn't be reordered
    @order.order_items.create!(
      product_variant: @active_variant,
      product: @active_variant.product,
      product_name: @active_variant.name,
      product_sku: @active_variant.sku,
      price: @active_variant.price,
      quantity: 1000,
      line_total: @active_variant.price * 1000,
      configuration: { "color" => "blue", "design_id" => "123" }
    )

    result = ReorderService.call(order: @order, cart: @cart)

    assert_not result.success?
    assert result.skipped_items.any? { |item| item[:reason].include?("configured") || item[:reason].include?("branded") }
  end

  test "skips sample items from original order" do
    sample_variant = ProductVariant.create!(
      product: products(:one),
      name: "Sample Product",
      sku: "SAMPLE-REORDER-1",
      price: 10.00,
      sample_eligible: true,
      active: true
    )

    @order.order_items.create!(
      product_variant: sample_variant,
      product: sample_variant.product,
      product_name: sample_variant.name,
      product_sku: sample_variant.sku,
      price: 0,  # Samples have 0 price
      quantity: 1,
      line_total: 0,
      is_sample: true
    )

    result = ReorderService.call(order: @order, cart: @cart)

    assert_not result.success?
    # Samples should be skipped (reorder adds regular items, not samples)
    assert result.skipped_items.any? { |item| item[:reason].include?("sample") }
  end

  # Price handling
  test "uses current variant price not historical order price" do
    # Price at order time was 16.00
    @order.order_items.create!(
      product_variant: @active_variant,
      product: @active_variant.product,
      product_name: @active_variant.name,
      product_sku: @active_variant.sku,
      price: 16.00,
      quantity: 1,
      line_total: 16.00
    )

    # Update variant to new price
    @active_variant.update!(price: 20.00)

    result = ReorderService.call(order: @order, cart: @cart)

    assert result.success?
    cart_item = @cart.reload.cart_items.first
    assert_equal 20.00, cart_item.price.to_f
  end

  # Result object interface
  test "result object has expected interface" do
    @order.order_items.create!(
      product_variant: @active_variant,
      product: @active_variant.product,
      product_name: @active_variant.name,
      product_sku: @active_variant.sku,
      price: @active_variant.price,
      quantity: 1,
      line_total: @active_variant.price
    )

    result = ReorderService.call(order: @order, cart: @cart)

    assert_respond_to result, :success?
    assert_respond_to result, :added_count
    assert_respond_to result, :skipped_items
    assert_respond_to result, :error
    assert_respond_to result, :cart
  end
end
