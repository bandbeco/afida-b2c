require "test_helper"

class CartTest < ActiveSupport::TestCase
  setup do
    @cart = carts(:one)
    @empty_cart = Cart.create
    @guest_cart = Cart.create
    @user_cart = Cart.create(user: users(:one))
  end

  test "items_count returns number of distinct cart items" do
    assert_equal 1, @cart.items_count  # Changed: counts distinct items, not quantity sum
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

    # After reload, count is recalculated (distinct items, not quantity sum)
    @cart.reload
    assert_equal 2, @cart.items_count  # Changed: 2 distinct items total
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

  test "reload clears memoized values" do
    # Trigger memoization
    @cart.items_count
    @cart.subtotal_amount

    # Reload should clear instance variables
    @cart.reload

    # Values should be recalculated on next access
    assert_equal 1, @cart.items_count  # Changed: counts distinct items
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

    # Add 1500 units to cart (requires 2 packs)
    cart.cart_items.create!(
      product_variant: variant,
      quantity: 1500,
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

    # Add first product: 750 units (needs 2 packs) = £100
    cart.cart_items.create!(
      product_variant: variant1,
      quantity: 750,
      price: variant1.price
    )

    # Add second product: 2500 units (needs 3 packs) = £240
    cart.cart_items.create!(
      product_variant: variant2,
      quantity: 2500,
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

  # ==========================================================================
  # has_configured_items? tests
  # ==========================================================================

  test "has_configured_items? returns true when cart has configured item" do
    cart = Cart.create

    variant = ProductVariant.create!(
      product: products(:one),
      name: "Configured Test Variant",
      sku: "CONFIGURED-TEST-1",
      price: 0.18,
      active: true
    )

    # Build item with configuration and attach design before saving
    item = cart.cart_items.build(
      product_variant: variant,
      quantity: 5000,
      price: 0.18,
      configuration: { design_id: "test_design" },
      calculated_price: 0.18
    )
    item.design.attach(
      io: StringIO.new("fake design"),
      filename: "design.pdf",
      content_type: "application/pdf"
    )
    item.save!

    assert cart.has_configured_items?
  end

  test "has_configured_items? returns false when cart has only standard items" do
    cart = Cart.create

    variant = ProductVariant.create!(
      product: products(:one),
      name: "Standard Test Variant",
      sku: "STANDARD-TEST-1",
      price: 10.0,
      active: true
    )

    cart.cart_items.create!(product_variant: variant, quantity: 2, price: 10.0)

    assert_not cart.has_configured_items?
  end

  test "has_configured_items? returns false for empty cart" do
    cart = Cart.create

    assert_not cart.has_configured_items?
  end

  # ==========================================================================
  # configured_items tests
  # ==========================================================================

  test "configured_items returns cart items with configuration" do
    cart = Cart.create

    # Add a configured item
    variant = ProductVariant.create!(
      product: products(:one),
      name: "Configured Item Test",
      sku: "CONFIGURED-ITEMS-TEST-1",
      price: 0.18,
      active: true
    )

    item = cart.cart_items.build(
      product_variant: variant,
      quantity: 5000,
      price: 0.18,
      configuration: { design_id: "test_design" },
      calculated_price: 0.18
    )
    item.design.attach(
      io: StringIO.new("fake design"),
      filename: "design.pdf",
      content_type: "application/pdf"
    )
    item.save!

    # Add a standard item
    standard_variant = ProductVariant.create!(
      product: products(:one),
      name: "Standard Item",
      sku: "STANDARD-ITEMS-TEST-1",
      price: 10.0,
      active: true
    )
    cart.cart_items.create!(product_variant: standard_variant, quantity: 2, price: 10.0)

    configured = cart.configured_items
    assert_equal 1, configured.count
    assert_includes configured, item
  end

  # ==========================================================================
  # subscription_eligible_items tests
  # ==========================================================================

  test "subscription_eligible_items returns standard items only" do
    cart = Cart.create

    # Add standard item
    standard_variant = ProductVariant.create!(
      product: products(:one),
      name: "Standard Eligible Item",
      sku: "STANDARD-ELIGIBLE-1",
      price: 10.0,
      active: true
    )
    standard_item = cart.cart_items.create!(product_variant: standard_variant, quantity: 2, price: 10.0)

    # Add sample item
    sample_variant = ProductVariant.create!(
      product: products(:one),
      name: "Sample Eligible Item",
      sku: "SAMPLE-ELIGIBLE-1",
      price: 10.0,
      sample_eligible: true,
      active: true
    )
    cart.cart_items.create!(product_variant: sample_variant, quantity: 1, price: 0, is_sample: true)

    # Add configured item
    configured_variant = ProductVariant.create!(
      product: products(:one),
      name: "Configured Eligible Item",
      sku: "CONFIGURED-ELIGIBLE-1",
      price: 0.18,
      active: true
    )
    item = cart.cart_items.build(
      product_variant: configured_variant,
      quantity: 5000,
      price: 0.18,
      configuration: { design_id: "test_design" },
      calculated_price: 0.18
    )
    item.design.attach(io: StringIO.new("fake design"), filename: "design.pdf", content_type: "application/pdf")
    item.save!

    eligible = cart.subscription_eligible_items
    assert_equal 1, eligible.count
    assert_includes eligible, standard_item
  end

  # ==========================================================================
  # one_time_items tests
  # ==========================================================================

  test "one_time_items returns samples and configured items" do
    cart = Cart.create

    # Add standard item (not one-time)
    standard_variant = ProductVariant.create!(
      product: products(:one),
      name: "Standard One-Time Test",
      sku: "STANDARD-ONETIME-1",
      price: 10.0,
      active: true
    )
    cart.cart_items.create!(product_variant: standard_variant, quantity: 2, price: 10.0)

    # Add sample item (one-time)
    sample_variant = ProductVariant.create!(
      product: products(:one),
      name: "Sample One-Time Test",
      sku: "SAMPLE-ONETIME-1",
      price: 10.0,
      sample_eligible: true,
      active: true
    )
    sample_item = cart.cart_items.create!(product_variant: sample_variant, quantity: 1, price: 0, is_sample: true)

    # Add configured item (one-time)
    configured_variant = ProductVariant.create!(
      product: products(:one),
      name: "Configured One-Time Test",
      sku: "CONFIGURED-ONETIME-1",
      price: 0.18,
      active: true
    )
    configured_item = cart.cart_items.build(
      product_variant: configured_variant,
      quantity: 5000,
      price: 0.18,
      configuration: { design_id: "test_design" },
      calculated_price: 0.18
    )
    configured_item.design.attach(io: StringIO.new("fake design"), filename: "design.pdf", content_type: "application/pdf")
    configured_item.save!

    one_time = cart.one_time_items
    assert_equal 2, one_time.count
    assert_includes one_time, sample_item
    assert_includes one_time, configured_item
  end

  # ==========================================================================
  # has_mixed_subscription_items? tests
  # ==========================================================================

  test "has_mixed_subscription_items? returns true for cart with standard and sample items" do
    cart = Cart.create

    # Add standard item
    standard_variant = ProductVariant.create!(
      product: products(:one),
      name: "Standard Mixed Test",
      sku: "STANDARD-MIXED-TEST-1",
      price: 10.0,
      active: true
    )
    cart.cart_items.create!(product_variant: standard_variant, quantity: 2, price: 10.0)

    # Add sample item
    sample_variant = ProductVariant.create!(
      product: products(:one),
      name: "Sample Mixed Test",
      sku: "SAMPLE-MIXED-TEST-1",
      price: 10.0,
      sample_eligible: true,
      active: true
    )
    cart.cart_items.create!(product_variant: sample_variant, quantity: 1, price: 0, is_sample: true)

    assert cart.has_mixed_subscription_items?
  end

  test "has_mixed_subscription_items? returns false for cart with only standard items" do
    cart = Cart.create

    variant = ProductVariant.create!(
      product: products(:one),
      name: "Standard Only Mixed Test",
      sku: "STANDARD-ONLY-MIXED-1",
      price: 10.0,
      active: true
    )
    cart.cart_items.create!(product_variant: variant, quantity: 2, price: 10.0)

    assert_not cart.has_mixed_subscription_items?
  end

  test "has_mixed_subscription_items? returns false for cart with only samples" do
    cart = Cart.create

    sample_variant = ProductVariant.create!(
      product: products(:one),
      name: "Sample Only Mixed Test",
      sku: "SAMPLE-ONLY-MIXED-1",
      price: 10.0,
      sample_eligible: true,
      active: true
    )
    cart.cart_items.create!(product_variant: sample_variant, quantity: 1, price: 0, is_sample: true)

    assert_not cart.has_mixed_subscription_items?
  end

  # ==========================================================================
  # subscription_eligible? tests (updated semantics)
  # ==========================================================================

  test "subscription_eligible? returns true for cart with standard items" do
    cart = Cart.create

    variant = ProductVariant.create!(
      product: products(:one),
      name: "Subscription Eligible Variant",
      sku: "SUB-ELIGIBLE-1",
      price: 10.0,
      active: true
    )

    cart.cart_items.create!(product_variant: variant, quantity: 2, price: 10.0)

    assert cart.subscription_eligible?
  end

  test "subscription_eligible? returns false for empty cart" do
    cart = Cart.create

    assert_not cart.subscription_eligible?
  end

  test "subscription_eligible? returns false for samples-only cart" do
    cart = Cart.create

    sample_variant = ProductVariant.create!(
      product: products(:one),
      name: "Sample Only Subscription Test",
      sku: "SAMPLE-SUB-TEST-1",
      price: 10.0,
      sample_eligible: true,
      active: true
    )

    cart.cart_items.create!(product_variant: sample_variant, quantity: 1, price: 0, is_sample: true)

    assert_not cart.subscription_eligible?
  end

  test "subscription_eligible? returns false for cart with only configured items" do
    cart = Cart.create

    variant = ProductVariant.create!(
      product: products(:one),
      name: "Configured Subscription Test",
      sku: "CONFIGURED-SUB-TEST-1",
      price: 0.18,
      active: true
    )

    # Build item with configuration and attach design before saving
    item = cart.cart_items.build(
      product_variant: variant,
      quantity: 5000,
      price: 0.18,
      configuration: { design_id: "test_design" },
      calculated_price: 0.18
    )
    item.design.attach(
      io: StringIO.new("fake design"),
      filename: "design.pdf",
      content_type: "application/pdf"
    )
    item.save!

    assert_not cart.subscription_eligible?
  end

  test "subscription_eligible? returns true for mixed cart with standard and configured items" do
    cart = Cart.create

    # Add standard item
    standard_variant = ProductVariant.create!(
      product: products(:one),
      name: "Standard Mixed Variant",
      sku: "STANDARD-MIXED-1",
      price: 10.0,
      active: true
    )
    cart.cart_items.create!(product_variant: standard_variant, quantity: 2, price: 10.0)

    # Add configured item - build and attach design before saving
    configured_variant = ProductVariant.create!(
      product: products(:one),
      name: "Configured Mixed Variant",
      sku: "CONFIGURED-MIXED-1",
      price: 0.18,
      active: true
    )
    item = cart.cart_items.build(
      product_variant: configured_variant,
      quantity: 5000,
      price: 0.18,
      configuration: { design_id: "test_design" },
      calculated_price: 0.18
    )
    item.design.attach(
      io: StringIO.new("fake design"),
      filename: "design.pdf",
      content_type: "application/pdf"
    )
    item.save!

    # Mixed carts ARE now subscription eligible (standard items become recurring)
    assert cart.subscription_eligible?
  end

  test "subscription_eligible? returns true for mixed cart with standard and sample items" do
    cart = Cart.create

    # Add standard item
    standard_variant = ProductVariant.create!(
      product: products(:one),
      name: "Standard Mixed Sample Variant",
      sku: "STANDARD-MIXED-SAMPLE-1",
      price: 10.0,
      active: true
    )
    cart.cart_items.create!(product_variant: standard_variant, quantity: 2, price: 10.0)

    # Add sample item
    sample_variant = ProductVariant.create!(
      product: products(:one),
      name: "Sample Mixed Standard Variant",
      sku: "SAMPLE-MIXED-STANDARD-1",
      price: 10.0,
      sample_eligible: true,
      active: true
    )
    cart.cart_items.create!(product_variant: sample_variant, quantity: 1, price: 0, is_sample: true)

    # Mixed carts ARE subscription eligible (samples become one-time)
    assert cart.subscription_eligible?
  end
end
