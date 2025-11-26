require "test_helper"

class OrderItemTest < ActiveSupport::TestCase
  setup do
    @order = orders(:one)
    @product_variant = product_variants(:one)
    @valid_attributes = {
      order: @order,
      product_variant: @product_variant,
      product_name: "Test Product",
      product_sku: "TEST-SKU",
      price: 10.99,
      quantity: 2
    }
  end

  # Validation tests
  test "validates presence of product_name" do
    order_item = OrderItem.new(@valid_attributes.except(:product_name))
    assert_not order_item.valid?
    assert_includes order_item.errors[:product_name], "can't be blank"
  end

  test "validates presence of price" do
    order_item = OrderItem.new(@valid_attributes.except(:price))
    assert_not order_item.valid?
    assert_includes order_item.errors[:price], "can't be blank"
  end

  test "validates price is greater than zero" do
    order_item = OrderItem.new(@valid_attributes.merge(price: 0))
    assert_not order_item.valid?
    assert_includes order_item.errors[:price], "must be greater than 0"
  end

  test "validates price is numeric" do
    order_item = OrderItem.new(@valid_attributes.merge(price: -5))
    assert_not order_item.valid?
    assert_includes order_item.errors[:price], "must be greater than 0"
  end

  test "validates presence of quantity" do
    order_item = OrderItem.new(@valid_attributes.except(:quantity))
    assert_not order_item.valid?
    assert_includes order_item.errors[:quantity], "can't be blank"
  end

  test "validates quantity is greater than zero" do
    order_item = OrderItem.new(@valid_attributes.merge(quantity: 0))
    assert_not order_item.valid?
    assert_includes order_item.errors[:quantity], "must be greater than 0"
  end

  test "validates quantity is numeric" do
    order_item = OrderItem.new(@valid_attributes.merge(quantity: -1))
    assert_not order_item.valid?
    assert_includes order_item.errors[:quantity], "must be greater than 0"
  end

  test "validates presence of line_total after calculation" do
    order_item = OrderItem.new(@valid_attributes.merge(line_total: nil))
    order_item.valid?
    assert_not_nil order_item.line_total
  end

  test "validates line_total is non-negative when manually set" do
    # Note: The callback recalculates line_total, so we need to stub the callback
    # or create a specific scenario where it would be negative
    order_item = order_items(:one)

    # Temporarily disable the callback to test validation
    order_item.define_singleton_method(:calculate_line_total) { }
    order_item.line_total = -5

    assert_not order_item.valid?
    assert_includes order_item.errors[:line_total], "must be greater than or equal to 0"
  end

  # Callback tests
  test "calculate_line_total sets line_total before validation" do
    order_item = OrderItem.new(@valid_attributes.merge(price: 10.99, quantity: 3))
    order_item.valid?
    assert_equal 32.97, order_item.line_total
  end

  test "calculate_line_total handles decimal prices correctly" do
    order_item = OrderItem.new(@valid_attributes.merge(price: 5.50, quantity: 4))
    order_item.valid?
    assert_equal 22.0, order_item.line_total
  end

  test "calculate_line_total does not run if price is blank" do
    order_item = OrderItem.new(@valid_attributes.merge(price: nil, quantity: 2, line_total: 100))
    order_item.valid?
    assert_equal 100, order_item.line_total
  end

  test "calculate_line_total does not run if quantity is blank" do
    order_item = OrderItem.new(@valid_attributes.merge(price: 10, quantity: nil, line_total: 100))
    order_item.valid?
    assert_equal 100, order_item.line_total
  end

  # Method tests
  test "subtotal calculates price times quantity" do
    order_item = OrderItem.new(@valid_attributes.merge(price: 15.99, quantity: 3))
    assert_equal 47.97, order_item.subtotal
  end

  test "subtotal handles single quantity" do
    order_item = OrderItem.new(@valid_attributes.merge(price: 9.99, quantity: 1))
    assert_equal 9.99, order_item.subtotal
  end

  test "product_display_name returns variant name when available" do
    order_item = order_items(:one)
    assert_equal order_item.product_variant.name, order_item.product_display_name
  end

  test "product_display_name returns fallback when variant is nil" do
    # product_variant_id is NOT NULL in schema, so this test documents behavior
    # but cannot actually test nil variant due to database constraint
    order_item = order_items(:one)
    # Simulate nil by stubbing the association
    order_item.define_singleton_method(:product_variant) { nil }
    assert_equal "Product Unavailable", order_item.product_display_name
  end

  test "product_still_available? returns true when product exists and is active" do
    order_item = order_items(:one)
    order_item.product.update(active: true)
    assert order_item.product_still_available?
  end

  test "product_still_available? returns false when product is inactive" do
    order_item = order_items(:one)
    order_item.product.update(active: false)
    assert_not order_item.product_still_available?
  end

  # Scope tests
  test "for_product scope filters by product" do
    product = products(:one)
    items = OrderItem.for_product(product)

    # Should return order_items for this product
    assert items.count > 0
    items.each do |item|
      assert_equal product, item.product
    end
  end

  # Association tests
  test "belongs to order" do
    order_item = order_items(:one)
    assert_respond_to order_item, :order
    assert_kind_of Order, order_item.order
  end

  test "belongs to product optionally" do
    order_item = order_items(:one)
    assert_respond_to order_item, :product
    assert_kind_of Product, order_item.product
  end

  test "belongs to product_variant" do
    order_item = order_items(:one)
    assert_respond_to order_item, :product_variant
    assert_kind_of ProductVariant, order_item.product_variant
    # Note: Model says optional: true but schema has NOT NULL constraint
    # Schema constraint prevents actual nil values
  end

  test "order_item requires an order" do
    order_item = OrderItem.new(@valid_attributes.except(:order))
    assert_not order_item.valid?
    assert_includes order_item.errors[:order], "must exist"
  end

  # Configuration tests
  test "order item stores configuration from cart item" do
    cart_item = cart_items(:branded_configuration)
    order = orders(:acme_order)

    order_item = OrderItem.create_from_cart_item(cart_item, order)

    assert_equal cart_item.configuration["size"], order_item.configuration["size"]
    assert_equal cart_item.configuration["quantity"], order_item.configuration["quantity"]
  end

  test "order item has design attachment" do
    order_item = order_items(:acme_branded_item)
    assert_respond_to order_item, :design
  end

  test "configured order item" do
    order_item = order_items(:acme_branded_item)
    assert order_item.configured?
    assert_equal "12oz", order_item.configuration["size"]
  end

  # Pack pricing tests for pricing display consolidation
  test "pack_priced? returns true for standard product with pac_size > 1" do
    order_item = OrderItem.new(
      @valid_attributes.merge(
        price: 15.99,
        pac_size: 500,
        configuration: {}
      )
    )
    assert order_item.pack_priced?
  end

  test "pack_priced? returns false for branded/configured product" do
    order_item = OrderItem.new(
      @valid_attributes.merge(
        price: 0.032,
        pac_size: 500,
        configuration: { size: "12oz", quantity: 5000 }
      )
    )
    assert_not order_item.pack_priced?
  end

  test "pack_priced? returns false when pac_size is nil" do
    order_item = OrderItem.new(
      @valid_attributes.merge(
        price: 15.99,
        pac_size: nil,
        configuration: {}
      )
    )
    assert_not order_item.pack_priced?
  end

  test "pack_priced? returns false when pac_size is 1" do
    order_item = OrderItem.new(
      @valid_attributes.merge(
        price: 15.99,
        pac_size: 1,
        configuration: {}
      )
    )
    assert_not order_item.pack_priced?
  end

  test "pack_price returns price for pack-priced items" do
    order_item = OrderItem.new(
      @valid_attributes.merge(
        price: 15.99,
        pac_size: 500,
        configuration: {}
      )
    )
    assert_equal 15.99, order_item.pack_price
  end

  test "pack_price returns nil for unit-priced items" do
    order_item = OrderItem.new(
      @valid_attributes.merge(
        price: 0.032,
        pac_size: nil,
        configuration: {}
      )
    )
    assert_nil order_item.pack_price
  end

  test "unit_price derives from pack price for pack-priced items" do
    order_item = OrderItem.new(
      @valid_attributes.merge(
        price: 16.00,
        pac_size: 500,
        configuration: {}
      )
    )
    assert_equal 0.032, order_item.unit_price
  end

  test "unit_price returns price directly for unit-priced items" do
    order_item = OrderItem.new(
      @valid_attributes.merge(
        price: 5.50,
        pac_size: nil,
        configuration: {}
      )
    )
    assert_equal 5.50, order_item.unit_price
  end

  test "unit_price returns price for branded/configured items" do
    order_item = OrderItem.new(
      @valid_attributes.merge(
        price: 0.18,
        pac_size: 500,
        configuration: { size: "12oz" }
      )
    )
    assert_equal 0.18, order_item.unit_price
  end

  # Edge case tests for pac_size validation and handling
  test "validates pac_size must be greater than zero when present" do
    order_item = OrderItem.new(@valid_attributes.merge(pac_size: 0))
    assert_not order_item.valid?
    assert_includes order_item.errors[:pac_size], "must be greater than 0"
  end

  test "validates pac_size rejects negative values" do
    order_item = OrderItem.new(@valid_attributes.merge(pac_size: -1))
    assert_not order_item.valid?
    assert_includes order_item.errors[:pac_size], "must be greater than 0"
  end

  test "validates pac_size allows nil" do
    order_item = OrderItem.new(@valid_attributes.merge(pac_size: nil))
    assert order_item.valid?
  end

  test "pack_priced? returns false when pac_size is zero" do
    order_item = OrderItem.new(
      @valid_attributes.merge(
        price: 15.99,
        pac_size: 0,
        configuration: {}
      )
    )
    # Note: pac_size=0 is invalid, but testing the method behavior
    assert_not order_item.pack_priced?
  end

  test "unit_price handles very large pac_size correctly" do
    order_item = OrderItem.new(
      @valid_attributes.merge(
        price: 100.00,
        pac_size: 10000,
        configuration: {}
      )
    )
    # £100.00 / 10000 = £0.01 per unit
    assert_equal 0.01, order_item.unit_price
    assert order_item.pack_priced?
  end

  test "unit_price formats correctly with very small unit price" do
    order_item = OrderItem.new(
      @valid_attributes.merge(
        price: 50.00,
        pac_size: 50000,
        configuration: {}
      )
    )
    # £50.00 / 50000 = £0.001 per unit
    assert_equal 0.001, order_item.unit_price
  end

  # Historical data preservation test - verifies order uses captured pac_size
  test "unit_price uses captured pac_size not live variant value" do
    # Create an order item with pac_size captured at order time
    order = orders(:one)
    variant = product_variants(:one)
    original_pac_size = 500

    order_item = OrderItem.create!(
      order: order,
      product_variant: variant,
      product_name: "Test Product",
      product_sku: "TEST-HISTORICAL",
      price: 16.00,
      pac_size: original_pac_size,
      quantity: 1000,
      line_total: 32.00,
      configuration: {}
    )

    # Verify unit price uses captured pac_size
    assert_equal 0.032, order_item.unit_price

    # Now simulate the product variant's pac_size changing
    variant.update!(pac_size: 1000)

    # Reload the order item to ensure we're testing the persisted data
    order_item.reload

    # OrderItem should still use its captured pac_size (500), not the variant's new value (1000)
    assert_equal original_pac_size, order_item.pac_size
    assert_equal 0.032, order_item.unit_price  # Still £16.00 / 500 = £0.032
    assert_not_equal variant.pac_size, order_item.pac_size
  end
end
