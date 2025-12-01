require "test_helper"

class CartItemTest < ActiveSupport::TestCase
  setup do
    @cart = Cart.create
    @product_variant = product_variants(:one)
  end

  # Validation tests
  test "should not be valid without a cart" do
    cart_item = CartItem.new(product_variant: @product_variant)
    assert_not cart_item.valid?
    assert_includes cart_item.errors[:cart], "must exist"
  end

  test "should not be valid without a product_variant" do
    cart_item = CartItem.new(cart: @cart)
    assert_not cart_item.valid?
    assert_includes cart_item.errors[:product_variant], "must exist"
  end

  test "validates quantity is present" do
    cart_item = CartItem.new(cart: @cart, product_variant: @product_variant, quantity: nil)
    assert_not cart_item.valid?
    assert_includes cart_item.errors[:quantity], "can't be blank"
  end

  test "validates quantity is greater than zero" do
    cart_item = CartItem.new(cart: @cart, product_variant: @product_variant, quantity: 0)
    assert_not cart_item.valid?
    assert_includes cart_item.errors[:quantity], "must be greater than 0"
  end

  test "validates price is greater than zero for non-sample-eligible variant" do
    # @product_variant is not sample-eligible, so price=0 should be invalid
    assert_not @product_variant.sample_eligible?, "Test requires non-sample-eligible variant"
    cart_item = CartItem.new(cart: @cart, product_variant: @product_variant, quantity: 1, price: 0)
    assert_not cart_item.valid?
    assert_includes cart_item.errors[:price], "must be greater than 0"
  end

  test "allows price of zero for sample-eligible variant" do
    sample_variant = product_variants(:sample_cup_8oz)
    assert sample_variant.sample_eligible?, "Test requires sample-eligible variant"

    cart_item = CartItem.new(cart: @cart, product_variant: sample_variant, quantity: 1, price: 0)
    assert cart_item.valid?, "Sample with price=0 should be valid: #{cart_item.errors.full_messages}"
  end

  test "validates uniqueness of product_variant per cart" do
    cart_item = CartItem.new(cart: carts(:one), product_variant: product_variants(:one), quantity: 1, price: 10)
    assert_not cart_item.valid?
    assert_includes cart_item.errors[:product_variant], "has already been taken"
  end

  test "allows same product_variant in different carts" do
    cart1 = Cart.create
    cart2 = Cart.create

    cart_item1 = CartItem.create(cart: cart1, product_variant: @product_variant, quantity: 1, price: 10)
    cart_item2 = CartItem.new(cart: cart2, product_variant: @product_variant, quantity: 1, price: 10)

    assert cart_item2.valid?
  end

  test "allows same variant as both sample and regular item in same cart" do
    sample_variant = product_variants(:sample_cup_8oz)

    # Add as sample (price=0)
    sample_item = CartItem.create!(
      cart: @cart,
      product_variant: sample_variant,
      quantity: 1,
      price: 0
    )

    # Add as regular item (price>0) - should be allowed
    regular_item = CartItem.new(
      cart: @cart,
      product_variant: sample_variant,
      quantity: 2,
      price: sample_variant.price
    )

    assert regular_item.valid?, "Same variant at different prices should be allowed: #{regular_item.errors.full_messages}"
    regular_item.save!

    # Verify both exist
    assert_equal 2, @cart.cart_items.where(product_variant: sample_variant).count
  end

  test "prevents duplicate samples of same variant in same cart" do
    sample_variant = product_variants(:sample_cup_8oz)

    # Add first sample
    CartItem.create!(cart: @cart, product_variant: sample_variant, quantity: 1, price: 0)

    # Try to add duplicate sample - should fail uniqueness validation
    duplicate = CartItem.new(cart: @cart, product_variant: sample_variant, quantity: 1, price: 0)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:product_variant], "has already been taken"
  end

  test "enforces sample limit at model level" do
    sample_variant = product_variants(:sample_cup_8oz)

    # Fill cart to sample limit
    Cart::SAMPLE_LIMIT.times do |i|
      variant = ProductVariant.create!(
        product: sample_variant.product,
        name: "Sample Variant #{i}",
        sku: "SAMPLE-LIMIT-#{i}-#{SecureRandom.hex(4)}",
        price: 10.0,
        stock_quantity: 100,
        active: true,
        sample_eligible: true
      )
      @cart.cart_items.create!(product_variant: variant, quantity: 1, price: 0)
    end

    assert @cart.at_sample_limit?, "Cart should be at sample limit"

    # Try to add one more sample - should fail validation
    extra_sample = @cart.cart_items.build(
      product_variant: sample_variant,
      quantity: 1,
      price: 0
    )
    assert_not extra_sample.valid?
    assert extra_sample.errors[:base].any? { |e| e.include?("Sample limit") }
  end

  # Sample scope tests
  test "samples scope returns only price=0 items" do
    sample_variant = product_variants(:sample_cup_8oz)

    # Add sample and regular items
    @cart.cart_items.create!(product_variant: sample_variant, quantity: 1, price: 0)
    @cart.cart_items.create!(product_variant: @product_variant, quantity: 1, price: @product_variant.price)

    samples = @cart.cart_items.samples
    assert_equal 1, samples.count
    assert samples.all? { |item| item.price.zero? }
  end

  test "non_samples scope excludes price=0 items" do
    sample_variant = product_variants(:sample_cup_8oz)

    # Add sample and regular items
    @cart.cart_items.create!(product_variant: sample_variant, quantity: 1, price: 0)
    @cart.cart_items.create!(product_variant: @product_variant, quantity: 1, price: @product_variant.price)

    non_samples = @cart.cart_items.non_samples
    assert_equal 1, non_samples.count
    assert non_samples.none? { |item| item.price.zero? }
  end

  test "sample? returns true for free sample-eligible variant" do
    sample_variant = product_variants(:sample_cup_8oz)
    cart_item = CartItem.new(cart: @cart, product_variant: sample_variant, quantity: 1, price: 0)

    assert cart_item.sample?
  end

  test "sample? returns false for priced item" do
    sample_variant = product_variants(:sample_cup_8oz)
    cart_item = CartItem.new(cart: @cart, product_variant: sample_variant, quantity: 1, price: sample_variant.price)

    assert_not cart_item.sample?
  end

  test "sample? returns false for price=0 on non-sample-eligible variant" do
    # This scenario shouldn't happen due to validation, but test the method directly
    cart_item = CartItem.new(cart: @cart, product_variant: @product_variant, quantity: 1, price: 0)

    assert_not cart_item.sample?
  end

  # Method tests
  test "subtotal_amount calculates price times quantity" do
    cart_item = CartItem.new(cart: @cart, product_variant: @product_variant, quantity: 3, price: 10.50)
    assert_equal 31.50, cart_item.subtotal_amount
  end

  test "subtotal_amount handles different quantities" do
    cart_item = CartItem.new(cart: @cart, product_variant: @product_variant, quantity: 1, price: 5.99)
    assert_equal 5.99, cart_item.subtotal_amount
  end

  test "VAT_RATE constant is set" do
    assert_equal 0.2, VAT_RATE
  end

  # Callback tests
  test "automatically sets price from product_variant if blank" do
    cart_item = CartItem.create(cart: @cart, product_variant: @product_variant, quantity: 1)
    assert_equal @product_variant.price, cart_item.price
  end

  test "does not override manually set price" do
    custom_price = 99.99
    cart_item = CartItem.create(cart: @cart, product_variant: @product_variant, quantity: 1, price: custom_price)
    assert_equal custom_price, cart_item.price
  end

  # Association tests
  test "belongs to cart" do
    cart_item = cart_items(:one)
    assert_respond_to cart_item, :cart
    assert_kind_of Cart, cart_item.cart
  end

  test "belongs to product_variant" do
    cart_item = cart_items(:one)
    assert_respond_to cart_item, :product_variant
    assert_kind_of ProductVariant, cart_item.product_variant
  end

  test "has one product through product_variant" do
    cart_item = cart_items(:one)
    assert_respond_to cart_item, :product
    assert_kind_of Product, cart_item.product
  end

  # Configuration tests
  test "cart item can store configuration for customizable products" do
    cart_item = cart_items(:branded_configuration)
    assert_equal "12oz", cart_item.configuration["size"]
    assert_equal "5000", cart_item.configuration["quantity"]  # Changed: stored as string from params
  end

  test "cart item with configuration uses calculated_price" do
    cart_item = cart_items(:branded_configuration)
    assert_equal 900.00, cart_item.calculated_price
    # With new approach: line_total = price * quantity = 0.18 * 5000 = 900
    assert_equal 900.00, cart_item.line_total
  end

  test "cart item without configuration uses variant price" do
    cart_item = cart_items(:one)
    expected = cart_item.price * cart_item.quantity  # Changed: uses price directly
    assert_equal expected, cart_item.line_total
  end

  test "cart item unit price for configured product" do
    cart_item = cart_items(:branded_configuration)
    # With new approach: unit_price = price (already stored as unit price)
    assert_equal 0.18, cart_item.unit_price
  end

  test "cart item unit price for standard product" do
    cart_item = cart_items(:one)
    # For standard products, unit_price delegates to product_variant.unit_price
    # which divides by pac_size if present, or returns price if not
    assert_equal cart_item.product_variant.unit_price, cart_item.unit_price
  end

  test "configured cart item validates calculated_price presence" do
    cart_item = CartItem.new(
      cart: carts(:one),
      product_variant: product_variants(:one),
      quantity: 1,
      configuration: { size: "8oz", quantity: 1000 },
      calculated_price: nil
    )
    assert_not cart_item.valid?
    assert_includes cart_item.errors[:calculated_price], "can't be blank"
  end

  test "cart item can have design attachment" do
    cart_item = cart_items(:branded_configuration)
    # We'll attach actual file in integration test
    assert_respond_to cart_item, :design
  end

  # Pack-based pricing tests
  # New model: quantity = packs for standard products, price = pack price
  # subtotal = price * quantity

  test "subtotal_amount for standard product with pack pricing" do
    product = products(:one)
    variant = ProductVariant.create!(
      product: product,
      name: "1000 pack",
      sku: "TEST-PACK-1000",
      price: 100.00,  # £100 per pack
      pac_size: 1000,  # 1000 units per pack
      active: true
    )

    # User orders 2 packs (2000 units)
    cart_item = CartItem.create!(
      cart: @cart,
      product_variant: variant,
      quantity: 2,  # 2 packs
      price: variant.price  # pack price
    )

    # Should calculate: 2 packs * £100 = £200
    assert_equal 200.00, cart_item.subtotal_amount
    assert_equal 0.10, cart_item.unit_price  # £100/1000 = £0.10 per unit
  end

  test "subtotal_amount for standard product with exact pack quantity" do
    product = products(:one)
    variant = ProductVariant.create!(
      product: product,
      name: "500 pack",
      sku: "TEST-PACK-500",
      price: 50.00,  # £50 per pack
      pac_size: 500,  # 500 units per pack
      active: true
    )

    # User orders 2 packs (1000 units)
    cart_item = CartItem.create!(
      cart: @cart,
      product_variant: variant,
      quantity: 2,  # 2 packs
      price: variant.price  # pack price
    )

    # Should calculate: 2 packs * £50 = £100
    assert_equal 100.00, cart_item.subtotal_amount
    assert_equal 0.10, cart_item.unit_price  # £50/500 = £0.10 per unit
  end

  test "subtotal_amount for standard product with single pack" do
    product = products(:one)
    variant = ProductVariant.create!(
      product: product,
      name: "100 pack",
      sku: "TEST-PACK-100",
      price: 10.00,  # £10 per pack
      pac_size: 100,  # 100 units per pack
      active: true
    )

    # User orders 1 pack
    cart_item = CartItem.create!(
      cart: @cart,
      product_variant: variant,
      quantity: 1,  # 1 pack
      price: variant.price  # pack price
    )

    # Should calculate: 1 pack * £10 = £10
    assert_equal 10.00, cart_item.subtotal_amount
    assert_equal 0.10, cart_item.unit_price  # £10/100 = £0.10 per unit
  end

  # Pack pricing display tests for pricing display consolidation
  test "pack_priced? returns true for standard product with pac_size > 1" do
    product = products(:one)
    variant = ProductVariant.create!(
      product: product,
      name: "500 pack",
      sku: "TEST-PACK-PRICED-500",
      price: 15.99,
      pac_size: 500,
      active: true
    )

    cart_item = CartItem.create!(
      cart: @cart,
      product_variant: variant,
      quantity: 500,
      price: variant.price
    )

    assert cart_item.pack_priced?
  end

  test "pack_priced? returns false for branded/configured product" do
    cart_item = cart_items(:branded_configuration)
    assert_not cart_item.pack_priced?
  end

  test "pack_priced? returns false when pac_size is nil" do
    product = products(:one)
    variant = ProductVariant.create!(
      product: product,
      name: "No pack size",
      sku: "TEST-NO-PAC-SIZE",
      price: 15.99,
      pac_size: nil,
      active: true
    )

    cart_item = CartItem.create!(
      cart: @cart,
      product_variant: variant,
      quantity: 1,
      price: variant.price
    )

    assert_not cart_item.pack_priced?
  end

  test "pack_priced? returns false when pac_size is 1" do
    product = products(:one)
    variant = ProductVariant.create!(
      product: product,
      name: "Single unit",
      sku: "TEST-SINGLE-UNIT",
      price: 15.99,
      pac_size: 1,
      active: true
    )

    cart_item = CartItem.create!(
      cart: @cart,
      product_variant: variant,
      quantity: 1,
      price: variant.price
    )

    assert_not cart_item.pack_priced?
  end

  test "pack_price returns price for pack-priced items" do
    product = products(:one)
    variant = ProductVariant.create!(
      product: product,
      name: "500 pack for pack_price test",
      sku: "TEST-PACK-PRICE-500",
      price: 15.99,
      pac_size: 500,
      active: true
    )

    cart_item = CartItem.create!(
      cart: @cart,
      product_variant: variant,
      quantity: 500,
      price: variant.price
    )

    assert_equal 15.99, cart_item.pack_price
  end

  test "pack_price returns nil for unit-priced items" do
    cart_item = cart_items(:branded_configuration)
    assert_nil cart_item.pack_price
  end
end
