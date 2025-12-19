require "test_helper"

class CartTest < ActiveSupport::TestCase
  setup do
    @cart = carts(:one)
    @empty_cart = Cart.create
    @guest_cart = Cart.create
    @user_cart = Cart.create(user: users(:one))
  end

  test "items_count returns total quantity across all cart items" do
    assert_equal 2, @cart.items_count  # Cart :one has 1 item with quantity: 2
    assert_equal 0, @empty_cart.items_count
  end

  test "subtotal_amount calculates sum before VAT" do
    assert_equal 20.0, @cart.subtotal_amount
    assert_equal 0, @empty_cart.subtotal_amount
  end

  test "vat_amount calculates 20% VAT on subtotal" do
    assert_equal 4.0, @cart.vat_amount
    assert_equal 0, @empty_cart.vat_amount
  end

  test "total_amount includes subtotal plus VAT" do
    assert_equal 24.0, @cart.total_amount
    assert_equal 0, @empty_cart.total_amount
  end

  test "VAT_RATE constant is set to 20%" do
    assert_equal 0.2, VAT_RATE
  end

  test "items_count is memoized within request" do
    # First call caches the value
    count1 = @cart.items_count

    # Add a new item directly to the association without reloading cart
    @cart.cart_items.create!(
      product_variant: product_variants(:two),
      quantity: 5,
      price: 10.0
    )

    # Second call returns cached value (doesn't reflect new item)
    count2 = @cart.items_count
    assert_equal count1, count2

    # After reload, count is recalculated (sum of quantities: 2 + 5 = 7)
    @cart.reload
    assert_equal 7, @cart.items_count
  end

  test "subtotal_amount is memoized within request" do
    # First call caches the value
    subtotal1 = @cart.subtotal_amount

    # Add a new item directly to the association
    @cart.cart_items.create!(
      product_variant: product_variants(:two),
      quantity: 1,
      price: 100.0
    )

    # Second call returns cached value
    subtotal2 = @cart.subtotal_amount
    assert_equal subtotal1, subtotal2

    # After reload, subtotal is recalculated
    @cart.reload
    assert_equal subtotal1 + 100.0, @cart.subtotal_amount
  end

  test "line_items_count is memoized within request" do
    # First call caches the value (cart :one has 1 distinct cart_item)
    count1 = @cart.line_items_count
    assert_equal 1, count1

    # Add a new item directly to the association without reloading cart
    @cart.cart_items.create!(
      product_variant: product_variants(:two),
      quantity: 5,
      price: 10.0
    )

    # Second call returns cached value (doesn't reflect new distinct item)
    count2 = @cart.line_items_count
    assert_equal count1, count2

    # After reload, count is recalculated (now 2 distinct cart_items)
    @cart.reload
    assert_equal 2, @cart.line_items_count
  end

  test "reload clears memoized values" do
    # Trigger memoization
    @cart.items_count
    @cart.line_items_count
    @cart.subtotal_amount

    # Reload should clear instance variables
    @cart.reload

    # Values should be recalculated on next access
    assert_equal 2, @cart.items_count  # Sum of quantities (cart :one has qty: 2)
    assert_equal 1, @cart.line_items_count
    assert_equal 20.0, @cart.subtotal_amount
  end

  test "guest_cart? returns true when user is nil" do
    assert @guest_cart.guest_cart?
  end

  test "guest_cart? returns false when user is present" do
    assert_not @user_cart.guest_cart?
  end

  test "cart belongs to user optionally" do
    assert_nil @guest_cart.user
    assert_equal users(:one), @user_cart.user
  end

  test "cart has many cart_items" do
    assert_respond_to @cart, :cart_items
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @cart.cart_items
  end

  test "destroying cart destroys associated cart_items" do
    cart_with_items = Cart.create
    cart_with_items.cart_items.create(
      product_variant: product_variants(:one),
      quantity: 1,
      price: 10.0
    )

    assert_difference "CartItem.count", -1 do
      cart_with_items.destroy
    end
  end

  # Pack-based pricing tests
  # Note: quantity in cart_items represents number of PACKS, not units
  # subtotal_amount = price (per pack) × quantity (packs)
  test "subtotal_amount calculates correctly for standard product with pack pricing" do
    cart = Cart.create
    product = products(:one)

    # Create variant with pack pricing: £100 per pack of 1000 units
    variant = ProductVariant.create!(
      product: product,
      name: "1000 pack",
      sku: "TEST-CART-PACK-1000",
      price: 100.00,
      pac_size: 1000,
      active: true
    )

    # Add 2 packs to cart
    cart.cart_items.create!(
      product_variant: variant,
      quantity: 2,
      price: variant.price
    )

    # Should calculate: 2 packs × £100 = £200
    assert_equal 200.00, cart.subtotal_amount
    assert_equal 40.00, cart.vat_amount  # 20% of £200
    assert_equal 240.00, cart.total_amount
  end

  test "subtotal_amount with multiple pack-based products" do
    cart = Cart.create

    # First standard product with pack pricing
    product1 = products(:one)
    variant1 = ProductVariant.create!(
      product: product1,
      name: "500 pack",
      sku: "TEST-CART-PACK-500",
      price: 50.00,
      pac_size: 500,
      active: true
    )

    # Second standard product with different pack pricing
    product2 = products(:two)
    variant2 = ProductVariant.create!(
      product: product2,
      name: "1000 pack",
      sku: "TEST-CART-PACK-1000",
      price: 80.00,
      pac_size: 1000,
      active: true
    )

    # Add first product: 2 packs × £50 = £100
    cart.cart_items.create!(
      product_variant: variant1,
      quantity: 2,
      price: variant1.price
    )

    # Add second product: 3 packs × £80 = £240
    cart.cart_items.create!(
      product_variant: variant2,
      quantity: 3,
      price: variant2.price
    )

    # Total: £100 + £240 = £340
    assert_equal 340.00, cart.subtotal_amount
    assert_equal 68.00, cart.vat_amount  # 20% of £340
    assert_equal 408.00, cart.total_amount
  end

  # Sample tracking tests
  test "SAMPLE_LIMIT constant is 5" do
    assert_equal 5, Cart::SAMPLE_LIMIT
  end

  test "sample_items returns cart items for sample-eligible variants" do
    cart = Cart.create

    # Create sample-eligible variant
    sample_variant = ProductVariant.create!(
      product: products(:one),
      name: "Sample Variant",
      sku: "SAMPLE-CART-TEST-1",
      price: 10.0,
      sample_eligible: true,
      active: true
    )

    # Create non-sample variant
    regular_variant = ProductVariant.create!(
      product: products(:one),
      name: "Regular Variant",
      sku: "REGULAR-CART-TEST-1",
      price: 20.0,
      sample_eligible: false,
      active: true
    )

    # Add both to cart (sample with is_sample: true, regular with is_sample: false)
    sample_item = cart.cart_items.create!(product_variant: sample_variant, quantity: 1, price: 0, is_sample: true)
    regular_item = cart.cart_items.create!(product_variant: regular_variant, quantity: 2, price: 20.0, is_sample: false)

    sample_items = cart.sample_items
    assert_equal 1, sample_items.count
    assert_includes sample_items, sample_item
    assert_not_includes sample_items, regular_item
  end

  test "sample_count returns count of sample items" do
    cart = Cart.create

    # Create sample-eligible variants
    3.times do |i|
      variant = ProductVariant.create!(
        product: products(:one),
        name: "Sample Variant #{i}",
        sku: "SAMPLE-COUNT-TEST-#{i}",
        price: 10.0,
        sample_eligible: true,
        active: true
      )
      cart.cart_items.create!(product_variant: variant, quantity: 1, price: 0, is_sample: true)
    end

    assert_equal 3, cart.sample_count
  end

  test "only_samples? returns true when cart has only sample items" do
    cart = Cart.create

    sample_variant = ProductVariant.create!(
      product: products(:one),
      name: "Only Samples Test",
      sku: "ONLY-SAMPLES-TEST-1",
      price: 10.0,
      sample_eligible: true,
      active: true
    )

    cart.cart_items.create!(product_variant: sample_variant, quantity: 1, price: 0, is_sample: true)

    assert cart.only_samples?
  end

  test "only_samples? returns false when cart has paid items" do
    cart = Cart.create

    sample_variant = ProductVariant.create!(
      product: products(:one),
      name: "Mixed Cart Sample",
      sku: "MIXED-SAMPLE-TEST-1",
      price: 10.0,
      sample_eligible: true,
      active: true
    )

    regular_variant = ProductVariant.create!(
      product: products(:one),
      name: "Mixed Cart Regular",
      sku: "MIXED-REGULAR-TEST-1",
      price: 20.0,
      sample_eligible: false,
      active: true
    )

    cart.cart_items.create!(product_variant: sample_variant, quantity: 1, price: 0, is_sample: true)
    cart.cart_items.create!(product_variant: regular_variant, quantity: 1, price: 20.0, is_sample: false)

    assert_not cart.only_samples?
  end

  test "only_samples? returns false for empty cart" do
    cart = Cart.create

    assert_not cart.only_samples?
  end

  test "at_sample_limit? returns true when sample_count equals SAMPLE_LIMIT" do
    cart = Cart.create

    Cart::SAMPLE_LIMIT.times do |i|
      variant = ProductVariant.create!(
        product: products(:one),
        name: "Limit Test Variant #{i}",
        sku: "LIMIT-TEST-#{i}",
        price: 10.0,
        sample_eligible: true,
        active: true
      )
      cart.cart_items.create!(product_variant: variant, quantity: 1, price: 0, is_sample: true)
    end

    assert cart.at_sample_limit?
  end

  test "at_sample_limit? returns false when under limit" do
    cart = Cart.create

    2.times do |i|
      variant = ProductVariant.create!(
        product: products(:one),
        name: "Under Limit Variant #{i}",
        sku: "UNDER-LIMIT-#{i}",
        price: 10.0,
        sample_eligible: true,
        active: true
      )
      cart.cart_items.create!(product_variant: variant, quantity: 1, price: 0, is_sample: true)
    end

    assert_not cart.at_sample_limit?
  end
end
