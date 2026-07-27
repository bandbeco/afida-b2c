require "test_helper"

class CartTest < ActiveSupport::TestCase
  # A mainland destination on @cart because most tests here are about the pricing
  # maths (shipping, VAT, total, discounts), which needs a KNOWN destination to
  # be quoted at all: Cart defers shipping until the customer says where the
  # order is going. The deferral itself is covered by its own tests below, which
  # deliberately use a cart with no postcode.
  MAINLAND_POSTCODE = "WD18 9SB"

  setup do
    @cart = carts(:one)
    @cart.delivery_postcode = MAINLAND_POSTCODE
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

  # The cart preview charges shipping the same way checkout does (the :charged
  # stance): a sub-threshold subtotal pays STANDARD_COST and VAT is levied on
  # subtotal + shipping, so the preview's VAT/Total match what Stripe charges.
  # Cart :one has a £20 subtotal (below the £100 free-shipping threshold).
  test "shipping_amount charges the standard cost below the free-shipping threshold" do
    assert_equal Shipping.standard_cost_in_pounds, @cart.shipping_amount
  end

  test "vat_amount is 20% of subtotal plus shipping below the threshold" do
    # (20.00 + 6.99) * 0.2 = 5.398, full precision (rounded once at the view).
    cost = BigDecimal(Shipping.standard_cost_in_pounds.to_s)
    assert_equal((BigDecimal("20.0") + cost) * BigDecimal(VAT_RATE.to_s), @cart.vat_amount)
    assert_equal BigDecimal("5.398"), @cart.vat_amount
  end

  test "total_amount includes subtotal, shipping, and VAT below the threshold" do
    # 20.00 + 6.99 + 5.398 = 32.388
    cost = BigDecimal(Shipping.standard_cost_in_pounds.to_s)
    expected = BigDecimal("20.0") + cost + (BigDecimal("20.0") + cost) * BigDecimal(VAT_RATE.to_s)
    assert_equal expected, @cart.total_amount
    assert_equal BigDecimal("32.388"), @cart.total_amount
  end

  # An empty cart ships nothing, so it stays at zero across the board rather than
  # showing a phantom shipping charge.
  test "empty cart has no shipping, VAT, or total" do
    assert_nil @empty_cart.shipping_amount
    assert_equal 0, @empty_cart.vat_amount
    assert_equal 0, @empty_cart.total_amount
  end

  test "VAT_RATE constant is set to 20%" do
    assert_equal 0.2, VAT_RATE
  end

  # --- welcome discount (whole-order, matching the Stripe coupon) ---
  # The cart has no discount until the controller injects the rate (it lives in the
  # session, not on the model). The welcome coupon is a plain Stripe percent_off with
  # no applies_to restriction, so it discounts the WHOLE order: products AND the
  # (taxed) shipping line. discount_amount is therefore a percentage of
  # subtotal + shipping, and the VAT/total drop to match what Stripe charges.

  test "discount_amount is zero by default" do
    assert_equal 0, @cart.discount_amount
  end

  test "discount_amount applies the injected rate to subtotal plus shipping" do
    # cart :one subtotal is £20, shipping £6.99 (below threshold). 10% of 26.99 = 2.699.
    @cart.discount_rate = 0.10
    cost = BigDecimal(Shipping.standard_cost_in_pounds.to_s)

    assert_equal (BigDecimal("20.0") + cost) * BigDecimal("0.1"), @cart.discount_amount
    assert_equal BigDecimal("2.699"), @cart.discount_amount
  end

  test "an injected discount reduces VAT and total but leaves subtotal and shipping" do
    # subtotal 20, shipping 6.99 (below threshold). Whole-order discount = 10% of
    # 26.99 = 2.699. VAT base = 26.99 - 2.699 = 24.291 -> VAT 4.8582;
    # total = 24.291 + 4.8582 = 29.1492.
    @cart.discount_rate = 0.10
    cost = BigDecimal(Shipping.standard_cost_in_pounds.to_s)

    assert_equal BigDecimal("20.0"), @cart.subtotal_amount
    assert_equal cost, @cart.shipping_amount
    assert_equal BigDecimal("4.8582"), @cart.vat_amount
    assert_equal BigDecimal("29.1492"), @cart.total_amount
  end

  test "an injected discount never reintroduces shipping below the threshold" do
    # An above-threshold cart ships free; a discount that drops the discounted
    # subtotal below the threshold must not bring the shipping charge back.
    cart = Cart.create
    variant = Product.create!(
      category: categories(:cups),
      name: "Threshold pack",
      sku: "TEST-CART-DISCOUNT-FREE-SHIP",
      price: Shipping::FREE_SHIPPING_THRESHOLD,
      pac_size: 1,
      active: true
    )
    cart.cart_items.create!(product: variant, quantity: 1, price: variant.price)
    cart.discount_rate = 0.10
    cart.delivery_postcode = MAINLAND_POSTCODE

    assert_equal 0, cart.shipping_amount
  end

  # A samples-only cart pays only shipping (samples are free), and SessionBuilder
  # refuses every discount for such a cart so a coupon can't reduce that shipping
  # charge. The preview must mirror that: an injected rate must NOT discount the
  # shipping line, otherwise the cart promises a discount Stripe will not apply.
  test "an injected discount is ignored for a samples-only cart" do
    cart = Cart.create
    cart.cart_items.create!(product: products(:sample_cup_8oz), quantity: 1, price: 0, is_sample: true)
    cart.discount_rate = 0.10
    cart.delivery_postcode = MAINLAND_POSTCODE

    assert cart.only_samples?
    assert_equal 0, cart.discount_amount
    # Shipping is still charged in full, and VAT/total carry no discount.
    cost = BigDecimal(Shipping.standard_cost_in_pounds.to_s)
    assert_equal cost, cart.shipping_amount
    assert_equal cost * BigDecimal(VAT_RATE.to_s), cart.vat_amount
    assert_equal cost + cost * BigDecimal(VAT_RATE.to_s), cart.total_amount
  end

  # The cart summary shows Subtotal/Shipping/Discount/VAT each rounded to the penny
  # (number_to_currency rounds at the view). If the Total is derived from the
  # full-precision figures it can round to a different penny than the sum of the
  # lines above it (and than Stripe, which rounds per line). display_total_amount is
  # the sum of the 2dp-rounded components, so the Total always reconciles with the
  # visible lines and with the charge.
  test "display_total_amount equals the sum of the rounded summary lines" do
    cart = Cart.create
    # £85.70 subtotal + £6.99 shipping, 10% welcome coupon: the figures from the
    # original bug. Full-precision total 100.1052 would render as £100.11, but the
    # rounded lines (85.70 + 6.99 - 9.27 + 16.68) sum to £100.10, matching Stripe.
    variant = Product.create!(
      category: categories(:cups),
      name: "Penny pack",
      sku: "TEST-CART-DISPLAY-TOTAL",
      price: BigDecimal("85.70"),
      pac_size: 1,
      active: true
    )
    cart.cart_items.create!(product: variant, quantity: 1, price: variant.price)
    cart.discount_rate = 0.10
    cart.delivery_postcode = MAINLAND_POSTCODE

    rounded_lines = cart.subtotal_amount.round(2) +
                    cart.shipping_amount.round(2) -
                    cart.discount_amount.round(2) +
                    cart.vat_amount.round(2)

    assert_equal BigDecimal("100.10"), rounded_lines
    assert_equal BigDecimal("100.10"), cart.display_total_amount
    # The full-precision total still rounds to a different penny, which is the bug
    # display_total_amount exists to avoid showing as the Total line.
    assert_equal BigDecimal("100.11"), cart.total_amount.round(2)
  end

  test "display_total_amount matches the rounded total when there is no rounding drift" do
    # cart :one: £20 + £6.99 shipping, no discount. 20 + 6.99 + 5.40 (5.398->5.40) =
    # 32.39, and the full-precision total 32.388 also rounds to 32.39, so they agree.
    assert_equal @cart.total_amount.round(2), @cart.display_total_amount
    assert_equal BigDecimal("32.39"), @cart.display_total_amount
  end

  test "display_total_amount is zero for an empty cart" do
    assert_equal 0, @empty_cart.display_total_amount
  end

  test "setting discount_rate after totals are memoized recomputes them" do
    # Reading totals first memoizes them at the zero-discount rate; setting the rate
    # must invalidate that so the discount is reflected.
    @cart.total_amount # memoize at 0% discount
    @cart.discount_rate = 0.10

    assert_equal BigDecimal("2.699"), @cart.discount_amount
    assert_equal BigDecimal("29.1492"), @cart.total_amount
  end

  # Regression: the discount rate is injected by the controller from the session,
  # not loaded from the DB, so a reload (which the CartItem sample-limit validator
  # triggers via cart.reload.at_sample_limit?) must NOT wipe it. Otherwise a
  # customer with the welcome discount who adds a sample sees the discount vanish
  # from the cart preview until the next full page load.
  test "reload preserves the injected discount_rate" do
    @cart.discount_rate = 0.10
    @cart.total_amount # memoize totals at the discounted rate

    @cart.reload

    assert_equal 0.10, @cart.discount_rate
    assert_equal BigDecimal("2.699"), @cart.discount_amount
    assert_equal BigDecimal("29.1492"), @cart.total_amount
  end

  test "items_count is memoized within request" do
    # First call caches the value
    count1 = @cart.items_count

    # Add a new item directly to the association without reloading cart
    @cart.cart_items.create!(
      product: products(:two),
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
      product: products(:two),
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
      product: products(:two),
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
      product: products(:one),
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

    # Create variant with pack pricing: £100 per pack of 1000 units
    variant = Product.create!(
      category: categories(:cups),
      name: "1000 pack",
      sku: "TEST-CART-PACK-1000",
      price: 100.00,
      pac_size: 1000,
      active: true
    )

    # Add 2 packs to cart
    cart.cart_items.create!(
      product: variant,
      quantity: 2,
      price: variant.price
    )

    cart.delivery_postcode = MAINLAND_POSTCODE

    # Should calculate: 2 packs × £100 = £200, which is at/above the £100
    # threshold, so shipping is free and VAT is on the subtotal alone.
    assert_equal 200.00, cart.subtotal_amount
    assert_equal 0, cart.shipping_amount
    assert_equal 40.00, cart.vat_amount  # 20% of £200
    assert_equal 240.00, cart.total_amount
  end

  test "subtotal_amount with multiple pack-based products" do
    cart = Cart.create

    # First standard product with pack pricing
    variant1 = Product.create!(
      category: categories(:cups),
      name: "500 pack",
      sku: "TEST-CART-PACK-500",
      price: 50.00,
      pac_size: 500,
      active: true
    )

    # Second standard product with different pack pricing
    variant2 = Product.create!(
      category: categories(:cups),
      name: "1000 pack",
      sku: "TEST-CART-PACK-1000",
      price: 80.00,
      pac_size: 1000,
      active: true
    )

    # Add first product: 2 packs × £50 = £100
    cart.cart_items.create!(
      product: variant1,
      quantity: 2,
      price: variant1.price
    )

    # Add second product: 3 packs × £80 = £240
    cart.cart_items.create!(
      product: variant2,
      quantity: 3,
      price: variant2.price
    )

    cart.delivery_postcode = MAINLAND_POSTCODE

    # Total: £100 + £240 = £340, above the threshold, so shipping is free.
    assert_equal 340.00, cart.subtotal_amount
    assert_equal 0, cart.shipping_amount
    assert_equal 68.00, cart.vat_amount  # 20% of £340
    assert_equal 408.00, cart.total_amount
  end

  test "shipping_amount is free at or above the free-shipping threshold" do
    cart = Cart.create
    variant = Product.create!(
      category: categories(:cups),
      name: "Threshold pack",
      sku: "TEST-CART-FREE-SHIP",
      price: Shipping::FREE_SHIPPING_THRESHOLD,
      pac_size: 1,
      active: true
    )
    cart.cart_items.create!(product: variant, quantity: 1, price: variant.price)
    cart.delivery_postcode = MAINLAND_POSTCODE

    assert_equal 0, cart.shipping_amount
    # VAT is on the subtotal alone when shipping is free.
    assert_equal Shipping::FREE_SHIPPING_THRESHOLD * BigDecimal(VAT_RATE.to_s), cart.vat_amount
  end

  # Sample tracking tests
  test "SAMPLE_LIMIT constant is 5" do
    assert_equal 5, Cart::SAMPLE_LIMIT
  end

  test "sample_items returns cart items for sample-eligible variants" do
    cart = Cart.create

    # Create sample-eligible variant
    sample_variant = Product.create!(
      category: categories(:cups),
      name: "Sample Variant",
      sku: "SAMPLE-CART-TEST-1",
      price: 10.0,
      sample_eligible: true,
      active: true
    )

    # Create non-sample variant
    regular_variant = Product.create!(
      category: categories(:cups),
      name: "Regular Variant",
      sku: "REGULAR-CART-TEST-1",
      price: 20.0,
      sample_eligible: false,
      active: true
    )

    # Add both to cart (sample with is_sample: true, regular with is_sample: false)
    sample_item = cart.cart_items.create!(product: sample_variant, quantity: 1, price: 0, is_sample: true)
    regular_item = cart.cart_items.create!(product: regular_variant, quantity: 2, price: 20.0, is_sample: false)

    sample_items = cart.sample_items
    assert_equal 1, sample_items.count
    assert_includes sample_items, sample_item
    assert_not_includes sample_items, regular_item
  end

  test "sample_count returns count of sample items" do
    cart = Cart.create

    # Create sample-eligible variants
    3.times do |i|
      variant = Product.create!(
        category: categories(:cups),
        name: "Sample Variant #{i}",
        sku: "SAMPLE-COUNT-TEST-#{i}",
        price: 10.0,
        sample_eligible: true,
        active: true
      )
      cart.cart_items.create!(product: variant, quantity: 1, price: 0, is_sample: true)
    end

    assert_equal 3, cart.sample_count
  end

  test "only_samples? returns true when cart has only sample items" do
    cart = Cart.create

    sample_variant = Product.create!(
      category: categories(:cups),
      name: "Only Samples Test",
      sku: "ONLY-SAMPLES-TEST-1",
      price: 10.0,
      sample_eligible: true,
      active: true
    )

    cart.cart_items.create!(product: sample_variant, quantity: 1, price: 0, is_sample: true)

    assert cart.only_samples?
  end

  test "only_samples? returns false when cart has paid items" do
    cart = Cart.create

    sample_variant = Product.create!(
      category: categories(:cups),
      name: "Mixed Cart Sample",
      sku: "MIXED-SAMPLE-TEST-1",
      price: 10.0,
      sample_eligible: true,
      active: true
    )

    regular_variant = Product.create!(
      category: categories(:cups),
      name: "Mixed Cart Regular",
      sku: "MIXED-REGULAR-TEST-1",
      price: 20.0,
      sample_eligible: false,
      active: true
    )

    cart.cart_items.create!(product: sample_variant, quantity: 1, price: 0, is_sample: true)
    cart.cart_items.create!(product: regular_variant, quantity: 1, price: 20.0, is_sample: false)

    assert_not cart.only_samples?
  end

  test "only_samples? returns false for empty cart" do
    cart = Cart.create

    assert_not cart.only_samples?
  end

  test "at_sample_limit? returns true when sample_count equals SAMPLE_LIMIT" do
    cart = Cart.create

    Cart::SAMPLE_LIMIT.times do |i|
      variant = Product.create!(
        category: categories(:cups),
        name: "Limit Test Variant #{i}",
        sku: "LIMIT-TEST-#{i}",
        price: 10.0,
        sample_eligible: true,
        active: true
      )
      cart.cart_items.create!(product: variant, quantity: 1, price: 0, is_sample: true)
    end

    assert cart.at_sample_limit?
  end

  test "at_sample_limit? returns false when under limit" do
    cart = Cart.create

    2.times do |i|
      variant = Product.create!(
        category: categories(:cups),
        name: "Under Limit Variant #{i}",
        sku: "UNDER-LIMIT-#{i}",
        price: 10.0,
        sample_eligible: true,
        active: true
      )
      cart.cart_items.create!(product: variant, quantity: 1, price: 0, is_sample: true)
    end

    assert_not cart.at_sample_limit?
  end

  # --- signed recovery token (cross-device abandoned-cart links) ---

  test "find_by_recovery_token round-trips a cart's signed recovery token" do
    assert_equal @cart, Cart.find_by_recovery_token(@cart.signed_recovery_token)
  end

  test "find_by_recovery_token returns nil for a garbage token" do
    assert_nil Cart.find_by_recovery_token("not-a-real-token")
  end

  test "find_by_recovery_token rejects a token signed for a different purpose" do
    # An order's access token must not be replayable as a cart recovery token.
    order_token = orders(:one).signed_access_token

    assert_nil Cart.find_by_recovery_token(order_token)
  end

  test "recovery_url is an absolute url pointing at the cart resume route" do
    url = @cart.recovery_url

    assert url.start_with?("http"), "expected an absolute url, got #{url.inspect}"
    assert_includes url, "/cart/resume"
  end

  # --- delivery postcode (the cart-page "calculate delivery" field) ---
  # The cart page asks for a postcode so the customer sees a real delivery price
  # before checkout, rather than discovering a surcharge at the payment screen.
  # Like discount_rate this is per-request state injected by the controller, not
  # a column: it belongs to the browsing session, and the order still records the
  # address Stripe collects.

  test "delivery_zone is mainland until a postcode is set" do
    assert_equal :mainland, @cart.delivery_zone
  end

  # Priceable-but-not-quoted. delivery_zone falls back to mainland so nothing
  # downstream has to handle a nil zone, but until the customer tells us where
  # this is going we must not present a mainland price as the quote: the drawer
  # was showing "Shipping Free" and a shipping-inclusive Total on a cart bound
  # anywhere, understating the cost for every off-mainland customer.

  test "shipping is deferred until a delivery postcode is known" do
    assert_nil undestined_cart.shipping_amount,
               "a cart with no destination must not quote a mainland shipping price"
  end

  test "the deferred total excludes shipping rather than assuming mainland" do
    # Otherwise the Total silently contains £0 (or £6.99) of mainland shipping
    # while the Shipping line defers to the postcode field: the customer would
    # be shown a total that no destination actually produces.
    cart = undestined_cart

    assert_equal cart.subtotal_amount + cart.vat_amount, cart.total_amount
  end

  test "the deferred vat is charged on the subtotal alone" do
    cart = undestined_cart
    expected = cart.subtotal_amount * BigDecimal(VAT_RATE.to_s)

    assert_equal expected, cart.vat_amount
  end

  test "setting a delivery postcode starts charging shipping" do
    cart = undestined_cart
    before = cart.shipping_amount
    cart.delivery_postcode = MAINLAND_POSTCODE

    assert_nil before
    assert_not_nil cart.shipping_amount
  end

  test "setting a non-mainland delivery postcode raises the shipping charge" do
    @cart.delivery_postcode = "BT1 6EE"

    assert_equal :northern_ireland, @cart.delivery_zone
    assert_equal Shipping.cost_for_zone_in_pounds(:northern_ireland), @cart.shipping_amount
  end

  test "a large order to a surcharged zone still pays shipping" do
    # The live bug: a £449 order to Skye shipped free.
    cart = Cart.create!
    cart.cart_items.create!(product: products(:one), quantity: 1, price: 450.00)
    cart.delivery_postcode = "IV51 9YB"

    assert_operator cart.subtotal_amount, :>=, Shipping::FREE_SHIPPING_THRESHOLD
    assert_equal Shipping.cost_for_zone_in_pounds(:highlands), cart.shipping_amount
  end

  test "a large mainland order still ships free" do
    cart = Cart.create!
    cart.cart_items.create!(product: products(:one), quantity: 1, price: 450.00)
    cart.delivery_postcode = "WD18 9SB"

    assert_equal 0, cart.shipping_amount
  end

  test "assigning a delivery postcode clears memoized totals" do
    # Mirrors discount_rate=; otherwise the VAT and Total lines would keep their
    # pre-postcode figures while the shipping line changed underneath them.
    before = @cart.total_amount
    @cart.delivery_postcode = "HS1 2DD"

    assert_operator @cart.total_amount, :>, before
  end

  test "an unparseable delivery postcode falls back to mainland" do
    @cart.delivery_postcode = "not a postcode"

    assert_equal :mainland, @cart.delivery_zone
  end

  test "a blank delivery postcode falls back to mainland" do
    @cart.delivery_postcode = "   "

    assert_equal :mainland, @cart.delivery_zone
  end

  test "vat is charged on the surcharged shipping too" do
    @cart.delivery_postcode = "BT1 6EE"

    expected = (@cart.subtotal_amount + @cart.shipping_amount) * BigDecimal(VAT_RATE.to_s)
    assert_equal expected, @cart.vat_amount
  end

  test "reload preserves the injected delivery_postcode" do
    # Same reason as discount_rate: the sample-limit validator reloads the cart
    # mid-request, which must not silently reprice the order back to mainland.
    @cart.delivery_postcode = "BT1 6EE"
    @cart.total_amount

    @cart.reload

    assert_equal :northern_ireland, @cart.delivery_zone
    assert_equal Shipping.cost_for_zone_in_pounds(:northern_ireland), @cart.shipping_amount
  end

  private

  # A cart with items but no delivery destination: the state a customer is in
  # after adding to cart from a product page without opening /cart.
  def undestined_cart
    cart = Cart.create!
    cart.cart_items.create!(product: products(:one), quantity: 2, price: 10.00)
    cart
  end
end
