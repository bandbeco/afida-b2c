require "test_helper"
require "ostruct"

class PricingHelperTest < ActionView::TestCase
  # Test format_price_display for pack-priced items
  test "format_price_display returns pack format for pack-priced items" do
    # Create a mock item that responds to pack_priced?, pack_price, unit_price
    item = OpenStruct.new(
      pack_priced?: true,
      pack_price: 15.99,
      unit_price: 0.032
    )

    result = format_price_display(item)

    assert_includes result, "£15.99"
    assert_includes result, "/ pack"
    assert_not_includes result, "/ unit"
  end

  test "format_price_display returns unit format for unit-priced items" do
    item = OpenStruct.new(
      pack_priced?: false,
      pack_price: nil,
      unit_price: 0.032
    )

    result = format_price_display(item)

    assert_includes result, "£0.0320"
    assert_includes result, "/ unit"
    assert_not_includes result, "/ pack"
  end

  test "format_price_display uses 2 decimal precision for pack price" do
    item = OpenStruct.new(
      pack_priced?: true,
      pack_price: 15.90,
      unit_price: 0.0318
    )

    result = format_price_display(item)

    # Pack price should have 2 decimals
    assert_includes result, "£15.90"
  end

  test "format_price_display uses 4 decimal precision for unit price" do
    item = OpenStruct.new(
      pack_priced?: false,
      pack_price: nil,
      unit_price: 0.0318
    )

    result = format_price_display(item)

    # Unit price should have 4 decimals
    assert_includes result, "£0.0318"
  end

  test "format_price_display handles branded product unit pricing" do
    item = OpenStruct.new(
      pack_priced?: false,
      pack_price: nil,
      unit_price: 0.18
    )

    result = format_price_display(item)

    assert_includes result, "£0.1800"
    assert_includes result, "/ unit"
    assert_not_includes result, "/ pack"
  end

  test "format_price_display handles whole number pack price" do
    item = OpenStruct.new(
      pack_priced?: true,
      pack_price: 20.00,
      unit_price: 0.04
    )

    result = format_price_display(item)

    assert_includes result, "£20.00"
    assert_includes result, "/ pack"
  end

  test "format_price_display with real OrderItem" do
    order = orders(:one)
    order_item = OrderItem.new(
      order: order,
      product_variant: product_variants(:one),
      product_name: "Test Product",
      product_sku: "TEST-SKU",
      price: 16.00,
      pac_size: 500,
      quantity: 500,
      configuration: {}
    )

    result = format_price_display(order_item)

    assert_includes result, "£16.00"
    assert_includes result, "/ pack"
    assert_not_includes result, "/ unit"
  end

  test "format_price_display with real CartItem" do
    cart = Cart.create
    product = products(:one)
    variant = ProductVariant.create!(
      product: product,
      name: "Test Variant",
      sku: "TEST-HELPER-VARIANT",
      price: 16.00,
      pac_size: 500,
      active: true
    )

    cart_item = CartItem.create!(
      cart: cart,
      product_variant: variant,
      quantity: 500,
      price: variant.price
    )

    result = format_price_display(cart_item)

    assert_includes result, "£16.00"
    assert_includes result, "/ pack"
    assert_not_includes result, "/ unit"
  end

  # Tests for format_quantity_display
  # New model: quantity = packs for standard products, units for branded

  test "format_quantity_display returns packs format for pack-priced items" do
    # quantity = 30 packs, pac_size = 500 => 15,000 units
    item = OpenStruct.new(
      pack_priced?: true,
      pac_size: 500,
      quantity: 30  # 30 packs
    )

    result = format_quantity_display(item)

    assert_includes result, "30"
    assert_includes result, "packs"
    assert_includes result, "15,000"
    assert_includes result, "units"
  end

  test "format_quantity_display returns units format for unit-priced items" do
    item = OpenStruct.new(
      pack_priced?: false,
      pac_size: nil,
      quantity: 5000  # 5,000 units
    )

    result = format_quantity_display(item)

    assert_includes result, "5,000"
    assert_includes result, "units"
    assert_not_includes result, "packs"
  end

  test "format_quantity_display uses singular pack for 1 pack" do
    # quantity = 1 pack, pac_size = 500 => 500 units
    item = OpenStruct.new(
      pack_priced?: true,
      pac_size: 500,
      quantity: 1  # 1 pack
    )

    result = format_quantity_display(item)

    assert_includes result, "1 pack"
    assert_not_includes result, "packs"
    assert_includes result, "500 units"
  end

  test "format_quantity_display formats large numbers with delimiters" do
    # quantity = 60 packs, pac_size = 500 => 30,000 units
    item = OpenStruct.new(
      pack_priced?: true,
      pac_size: 500,
      quantity: 60  # 60 packs
    )

    result = format_quantity_display(item)

    assert_includes result, "30,000"
  end

  test "format_quantity_display with real OrderItem" do
    order = orders(:one)
    # Standard product: 30 packs of 500 = 15,000 units
    order_item = OrderItem.new(
      order: order,
      product_variant: product_variants(:one),
      product_name: "Test Product",
      product_sku: "TEST-SKU",
      price: 16.00,
      pac_size: 500,
      quantity: 30,  # 30 packs
      configuration: {}
    )

    result = format_quantity_display(order_item)

    assert_includes result, "30"
    assert_includes result, "packs"
    assert_includes result, "15,000"
    assert_includes result, "units"
  end

  test "format_quantity_display with real CartItem" do
    cart = Cart.create
    product = products(:one)
    variant = ProductVariant.create!(
      product: product,
      name: "Test Variant",
      sku: "TEST-QTY-HELPER-VARIANT",
      price: 16.00,
      pac_size: 500,
      active: true
    )

    # Standard product: 30 packs
    cart_item = CartItem.create!(
      cart: cart,
      product_variant: variant,
      quantity: 30,  # 30 packs
      price: variant.price
    )

    result = format_quantity_display(cart_item)

    assert_includes result, "30"
    assert_includes result, "packs"
    assert_includes result, "15,000"
    assert_includes result, "units"
  end
end
