require "test_helper"

class Checkout::SessionBuilderTest < ActiveSupport::TestCase
  include StripeTestHelper

  setup do
    @cart = Cart.create!
    @success_url = "https://example.com/checkout/success?session_id={CHECKOUT_SESSION_ID}"
    @cancel_url = "https://example.com/checkout/cancel"
    @return_url = "https://example.com/checkout/success?session_id={CHECKOUT_SESSION_ID}"
    stub_stripe_tax_rate_list
  end

  test "builds pack-priced line items with pack count folded into one Stripe subtotal" do
    @cart.cart_items.create!(product: products(:paper_lid_80mm), quantity: 2, price: 45.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session

    line_item = product_line_item(captured_params)
    assert_equal 1, line_item[:quantity]
    assert_equal 9000, line_item[:price_data][:unit_amount]
    assert_match "(2 packs)", line_item[:price_data][:product_data][:name]
  end

  test "builds configured line items as one Stripe subtotal with units in product name" do
    cart_item = @cart.cart_items.build(
      product: products(:branded_template_variant),
      quantity: 5000,
      price: 0.20,
      configuration: { size: "12oz", quantity: 5000 },
      calculated_price: 1000.00
    )
    cart_item.design.attach(
      io: StringIO.new("fake design content"),
      filename: "design.pdf",
      content_type: "application/pdf"
    )
    cart_item.save!

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session

    line_item = product_line_item(captured_params)
    assert_equal 1, line_item[:quantity]
    assert_equal 100_000, line_item[:price_data][:unit_amount]
    assert_match "12oz (5,000 units)", line_item[:price_data][:product_data][:name]
  end

  # A guest still carries no pre-known identity (Stripe collects the email on its own
  # page), but the session MUST ask Stripe to persist a Customer for whoever pays.
  # Without one, every guest checkout looks like a brand-new party to Stripe, so the
  # welcome coupon's first_time_transaction restriction matches nothing and a guest can
  # redeem a one-time code repeatedly (three live orders did exactly this).
  test "builds guest checkout session without customer details but asks Stripe to create a customer" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session

    assert_nil captured_params[:customer]
    assert_nil captured_params[:customer_email]
    assert_nil captured_params[:client_reference_id]
    assert_equal "always", captured_params[:customer_creation]
  end

  # A logged-in customer with no Stripe Customer yet checks out via customer_email,
  # but must still ask Stripe to persist a Customer so coupon restrictions have an
  # identity to key on. Their Customer id is minted elsewhere (the default-address
  # sync job); once present, the next checkout attaches it directly.
  test "asks stripe to create a customer for a logged-in checkout without a stripe customer" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
    user = users(:one)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session_builder(user: user).create

    assert_equal user.email_address, captured_params[:customer_email]
    assert_equal "always", captured_params[:customer_creation]
    # customer and customer_email are mutually exclusive in the Stripe API, and an
    # explicit customer would prefill the address this branch deliberately leaves blank.
    assert_nil captured_params[:customer]
  end

  # The welcome coupon is injected into the session at signup and can sit there for the
  # cookie's lifetime, so eligibility must be re-checked when it is actually spent, not
  # only when it was granted. A logged-in customer who has since ordered is no longer a
  # first-time customer, and the session coupon must not still discount their order.
  # Guests are covered by Stripe's first_time_transaction restriction instead, since
  # their email is unknown until Stripe collects it.
  test "refuses the session welcome coupon for a customer who already has an order" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
    user = users(:one)
    user.update!(stripe_customer_id: "cus_known")
    user.stubs(:sync_stripe_customer!)
    # users(:one) OWNS orders(:one), but that order was placed under a different email
    # (user1@example.com). A repeat customer must be recognised by either signal:
    # matching on the account email alone would miss their own order history.
    assert Order.exists?(user_id: user.id)
    assert_not Order.exists?(email: user.email_address)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    result = build_session_builder(user: user, discount_code: "coupon_abc").create

    assert_nil captured_params[:discounts]
    assert_nil captured_params[:metadata][:discount_code]
    # Reported as not applied so the controller clears it from the session, exactly as
    # it does for an invalid coupon.
    assert result.invalid_discount?
  end

  # Refusing the stale welcome coupon must not also take away the promo-code field.
  # allow_promotion_codes governs EVERY code, so a repeat customer who is (correctly)
  # denied the welcome coupon must still be able to type a current campaign code.
  test "still offers the promo code field when the welcome coupon is refused" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
    user = users(:one)
    user.stubs(:sync_stripe_customer!)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session_builder(user: user, discount_code: "coupon_abc").create

    assert_nil captured_params[:discounts]
    assert captured_params[:allow_promotion_codes],
      "a refused welcome coupon must not withdraw the promo-code field"
  end

  # A cancelled or refunded order is not a purchase kept, and a pending one never paid
  # at all. Counting them would permanently burn a legitimately claimed discount for
  # someone whose first attempt fell through.
  test "an unpaid or reversed order does not burn the welcome coupon" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
    user = users(:user_without_orders)
    user.stubs(:sync_stripe_customer!)
    %w[cancelled refunded pending].each_with_index do |status, i|
      Order.create!(
        user: user, email: user.email_address, status: status,
        stripe_session_id: "sess_reversed_#{i}", order_number: "ORDER-REV-#{i}",
        subtotal_amount: 10, vat_amount: 2, shipping_amount: 3, total_amount: 15,
        shipping_name: "Test", shipping_address_line1: "1 Test St",
        shipping_city: "London", shipping_postal_code: "SW1A 1AA", shipping_country: "GB"
      )
    end
    Stripe::PromotionCode.stubs(:list)
      .with(has_entries(coupon: "coupon_abc"))
      .returns(stub(data: [ stub(id: "promo_welcome", code: "WELCOME10") ]))

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    result = build_session_builder(user: user, discount_code: "coupon_abc").create

    assert_equal [ { promotion_code: "promo_welcome" } ], captured_params[:discounts]
    assert_not result.invalid_discount?
  end

  # The signup form stamps discount_claimed_at the moment the coupon is GRANTED, which
  # is always before the order that spends it. The spend-time guard must therefore not
  # treat "claimed" as "used up", or no one could ever redeem a coupon they just
  # claimed. Only a completed ORDER ends eligibility.
  test "applies the session welcome coupon to the very order that claims it" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
    user = users(:user_without_orders)
    user.stubs(:sync_stripe_customer!)
    EmailSubscription.create!(email: user.email_address, source: "cart_discount",
                              discount_claimed_at: Time.current)
    Stripe::PromotionCode.stubs(:list)
      .with(has_entries(coupon: "coupon_abc"))
      .returns(stub(data: [ stub(id: "promo_welcome", code: "WELCOME10") ]))

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    result = build_session_builder(user: user, discount_code: "coupon_abc").create

    assert_equal [ { promotion_code: "promo_welcome" } ], captured_params[:discounts]
    assert_not result.invalid_discount?
  end

  # Eligibility is only re-checked for someone we can identify. A first-time logged-in
  # customer must still get the coupon they legitimately claimed.
  test "applies the session welcome coupon for a logged-in customer with no prior orders" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
    user = users(:user_without_orders)
    user.stubs(:sync_stripe_customer!)
    assert_not Order.exists?(email: user.email_address)
    Stripe::PromotionCode.stubs(:list)
      .with(has_entries(coupon: "coupon_abc"))
      .returns(stub(data: [ stub(id: "promo_welcome", code: "WELCOME10") ]))

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    result = build_session_builder(user: user, discount_code: "coupon_abc").create

    assert_equal [ { promotion_code: "promo_welcome" } ], captured_params[:discounts]
    assert_not result.invalid_discount?
  end

  test "resolves the coupon id to its promotion code, applies it, and records the code name" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
    # The session carries the coupon id; SessionBuilder looks up the coupon's
    # promotion code, applies it, and rewrites the metadata to the promotion code's
    # customer-facing name so the order records "WELCOME10" rather than the coupon id.
    Stripe::PromotionCode.stubs(:list)
      .with(has_entries(coupon: "coupon_abc"))
      .returns(stub(data: [ stub(id: "promo_welcome", code: "WELCOME10") ]))

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    result = build_session(discount_code: "coupon_abc")

    assert_not result.invalid_discount?
    assert_equal [ { promotion_code: "promo_welcome" } ], captured_params[:discounts]
    assert_nil captured_params[:allow_promotion_codes]
    assert_equal "WELCOME10", captured_params[:metadata][:discount_code]
  end

  test "marks invalid session discount while still allowing customer promotion codes" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
    # No promotion code for the coupon, and the raw-coupon-id fallback also misses.
    Stripe::PromotionCode.stubs(:list).returns(stub(data: []))
    Stripe::Coupon.stubs(:retrieve).raises(Stripe::InvalidRequestError.new("No such coupon", nil))

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    result = build_session(discount_code: "WELCOME5")

    assert result.invalid_discount?
    assert_equal true, captured_params[:allow_promotion_codes]
    assert_not captured_params[:metadata].key?(:discount_code)
  end


  # --- WHY a discount was dropped ---
  #
  # The controller can only explain the refusal to the customer if it is told the
  # reason, and the amount case in particular is worth saying out loud: "spend £X
  # more" is a nudge, whereas the old blanket "could not be applied" reads as a
  # fault and gives them nothing to act on.

  test "reports the reason when the order is below the coupon minimum" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
    stub_welcome_promotion_code
    Stripe::Checkout::Session.stubs(:create)
      .raises(amount_insufficient_error)
      .then.returns(build_stripe_session)

    result = build_session(discount_code: "WELCOME5")

    assert_equal :below_minimum, result.discount_refusal_reason
  end

  test "reports the reason when the cart holds only samples" do
    @cart.cart_items.create!(product: products(:sample_cup_8oz), quantity: 1, price: 0, is_sample: true)
    Stripe::Checkout::Session.stubs(:create).returns(build_stripe_session)

    result = build_session(discount_code: "WELCOME5")

    assert_equal :samples_only, result.discount_refusal_reason
  end

  test "reports the reason when the customer has already had a first order" do
    # orders(:one) is already a PAID order for this user, which is what
    # welcome_discount_allowed? refuses on.
    user = users(:one)
    assert_includes Order::COMPLETED_STATUSES, orders(:one).status
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
    Stripe::Checkout::Session.stubs(:create).returns(build_stripe_session)

    result = build_session_builder(user: user, discount_code: "WELCOME5").create

    assert_equal :not_first_order, result.discount_refusal_reason
  end

  test "reports the reason when the code itself does not resolve" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
    Stripe::PromotionCode.stubs(:list).returns(stub(data: []))
    Stripe::Coupon.stubs(:retrieve).raises(Stripe::InvalidRequestError.new("No such coupon", nil))
    Stripe::Checkout::Session.stubs(:create).returns(build_stripe_session)

    result = build_session(discount_code: "WELCOME5")

    assert_equal :unusable_code, result.discount_refusal_reason
  end

  test "reports no refusal reason when the discount applies" do
    @cart.cart_items.create!(product: products(:one), quantity: 11, price: 10.00)
    stub_welcome_promotion_code
    Stripe::Checkout::Session.stubs(:create).returns(build_stripe_session)

    result = build_session(discount_code: "WELCOME5")

    assert_not result.invalid_discount?
    assert_nil result.discount_refusal_reason
  end

  # --- the coupon's own conditions failing at Session.create ---
  #
  # apply_discount only checks the things the app can know: samples, and whether
  # this customer has already had a first order. The coupon's RESTRICTIONS
  # (minimum_amount, first_time_transaction) live in Stripe and are only
  # evaluated when the session is actually created, so a code that resolves
  # perfectly can still be refused one call later.
  #
  # That refusal used to kill the whole checkout: the raise escaped, and because
  # the lookup had SUCCEEDED, invalid_discount? was false, so nothing cleared the
  # code from the session. The customer bounced back to the cart with Stripe's raw
  # error and hit the identical wall on every retry, with no way to drop the code.
  # A sub-£100 basket carrying the welcome code was simply unable to check out.
  #
  # So an unusable coupon is dropped and the sale proceeds: buying is worth more
  # than the discount, and the customer keeps the code for a qualifying order.
  test "drops a coupon Stripe refuses at session creation and completes the checkout" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
    stub_welcome_promotion_code

    attempts = 0
    Stripe::Checkout::Session.stubs(:create).with do |_params|
      attempts += 1
      true
    end.raises(amount_insufficient_error).then.returns(build_stripe_session)

    result = build_session(discount_code: "WELCOME5")

    assert_equal 2, attempts, "the session should be retried once without the coupon"
    assert_not_nil result.session, "the customer should still get a checkout session"
    assert result.invalid_discount?, "the dropped code must be reported so the controller clears it"
  end

  test "retries without the discount but keeps the rest of the session identical" do
    # Only the coupon is given up. Line items, shipping and the customer wiring
    # must survive, or the retry would quietly sell a different order.
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
    stub_welcome_promotion_code

    seen = []
    attempts = 0
    Stripe::Checkout::Session.stubs(:create).with do |params|
      seen << params.deep_dup
      attempts += 1
      true
    end.raises(amount_insufficient_error).then.returns(build_stripe_session)

    build_session(discount_code: "WELCOME5")

    first, second = seen
    assert_equal first[:line_items], second[:line_items]
    assert_nil second[:discounts], "the refused coupon must not be re-sent"
    assert_not second[:metadata].key?(:discount_code)
    assert_equal true, second[:allow_promotion_codes],
                 "dropping this coupon must not withdraw the promo-code field"
  end

  test "does not retry a Stripe failure unrelated to the discount" do
    # A card/network/config failure is a real error and must still surface;
    # swallowing it behind a retry would hide genuine breakage.
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
    stub_welcome_promotion_code

    attempts = 0
    Stripe::Checkout::Session.stubs(:create).with do |_params|
      attempts += 1
      true
    end.raises(Stripe::InvalidRequestError.new("Something else broke", nil))

    assert_raises(Stripe::InvalidRequestError) do
      build_session(discount_code: "WELCOME5")
    end
    assert_equal 1, attempts, "only a discount refusal should be retried"
  end

  test "does not retry when the session carried no discount at all" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    attempts = 0
    Stripe::Checkout::Session.stubs(:create).with do |_params|
      attempts += 1
      true
    end.raises(amount_insufficient_error)

    assert_raises(Stripe::InvalidRequestError) { build_session }
    assert_equal 1, attempts
  end

  test "does not apply a discount code to a samples-only cart" do
    # Samples are free; a samples-only order pays only shipping. A coupon would
    # discount (or zero) that shipping, so discounts are refused entirely.
    @cart.cart_items.create!(product: products(:sample_cup_8oz), quantity: 1, price: 0, is_sample: true)
    Stripe::PromotionCode.expects(:list).never
    Stripe::Coupon.expects(:retrieve).never

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    result = build_session(discount_code: "WELCOME5")

    assert_nil captured_params[:discounts], "no coupon should be applied to a samples-only cart"
    assert_not captured_params[:metadata].key?(:discount_code)
    assert result.invalid_discount?, "the discount should be reported as not applied"
  end

  test "does not allow customer promotion codes on a samples-only cart" do
    @cart.cart_items.create!(product: products(:sample_cup_8oz), quantity: 1, price: 0, is_sample: true)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session

    assert_not_equal true, captured_params[:allow_promotion_codes],
      "samples-only carts must not let customers enter a promo code at Stripe"
  end

  test "appends a taxed shipping line item for sub-threshold carts" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session

    shipping_line = captured_params[:line_items].find do |li|
      li.dig(:price_data, :product_data, :metadata, "shipping_line") == "true"
    end
    assert shipping_line, "expected a shipping line item"
    assert_equal Shipping::STANDARD_COST, shipping_line[:price_data][:unit_amount]
    assert_equal "exclusive", shipping_line[:price_data][:tax_behavior]
    assert_equal 1, shipping_line[:tax_rates].length
  end

  test "puts the shipping line item first so it survives Stripe's 10-item line_items pagination" do
    # Stripe::Checkout::Session.retrieve returns only the first 10 line_items by
    # default. SessionAmounts must find the shipping line on page 1, so it has to
    # be created first - otherwise a cart with 10+ products drops it and records
    # shipping as £0 with an inflated subtotal.
    # 11 distinct products (carts allow one line per product) kept cheap so the
    # subtotal stays under the £100 free-shipping threshold while still exceeding
    # Stripe's 10-item page size.
    11.times do |i|
      product = Product.create!(
        name: "Bulk Product #{i}",
        sku: "BULK-#{i}",
        slug: "bulk-product-#{i}",
        category: categories(:one),
        price: 1.00,
        product_type: "standard"
      )
      @cart.cart_items.create!(product: product, quantity: 1, price: 1.00)
    end

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session

    first_line = captured_params[:line_items].first
    assert_equal "true", first_line.dig(:price_data, :product_data, :metadata, "shipping_line"),
      "shipping line item must be first so it is never paginated off page 1"
  end

  test "omits the shipping line item when the subtotal qualifies for free shipping" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 150.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session

    shipping_line = captured_params[:line_items].find do |li|
      li.dig(:price_data, :product_data, :metadata, "shipping_line") == "true"
    end
    assert_nil shipping_line, "expected no shipping line item for free shipping"
    assert_equal 1, captured_params[:line_items].length
  end

  test "appends a taxed shipping line item for a samples-only cart" do
    @cart.cart_items.create!(product: products(:sample_cup_8oz), quantity: 1, price: 0, is_sample: true)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session

    shipping_line = captured_params[:line_items].find do |li|
      li.dig(:price_data, :product_data, :metadata, "shipping_line") == "true"
    end
    assert shipping_line, "expected a shipping line item for samples-only cart"
    assert_equal Shipping::STANDARD_COST, shipping_line[:price_data][:unit_amount]
  end

  test "does not send shipping_options to Stripe but still collects the address" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session

    assert_nil captured_params[:shipping_options]
    assert captured_params[:shipping_address_collection]
  end

  test "collects a required billing address in hosted mode" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session

    assert_equal "required", captured_params[:billing_address_collection]
  end

  test "collects a required billing address in custom mode" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_custom_session

    assert_equal "required", captured_params[:billing_address_collection]
  end

  test "does not expose intermediate checkout state readers" do
    builder = build_session_builder(discount_code: "WELCOME5")

    assert_respond_to builder, :invalid_discount?
    assert_not_respond_to builder, :invalid_discount_code
  end

  # Attaching the known Customer is what makes Stripe offer "Use a saved address"
  # on the checkout page (the cart no longer collects an address), and what coupon
  # restrictions key on. The customer's shipping address is synced by the
  # default-address callback (StripeCustomerSyncJob), never at checkout time.
  test "attaches the known stripe customer for a logged-in checkout" do
    user = users(:one)
    user.update!(stripe_customer_id: "cus_known")
    user.expects(:sync_stripe_customer!).never
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session_builder(user: user).create

    assert_equal "cus_known", captured_params[:customer]
    assert_equal user.id, captured_params[:client_reference_id]
    assert_nil captured_params[:customer_email]
    assert_nil captured_params[:customer_creation]
  end

  # ==========================================================================
  # Delivery zone. The customer's postcode is captured on the cart page, before
  # the session is built, because line-item prices are fixed here and Stripe
  # only collects the address on the next screen. These assertions must mirror
  # OrderTotals; the displayed total and the charged total are the pair that
  # has drifted before.
  # ==========================================================================

  test "charges the zone surcharge for a non-mainland postcode" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session_builder(delivery_postcode: "BT1 6EE").create

    assert_equal Shipping.cost_for_zone(:northern_ireland), shipping_line_item(captured_params)[:price_data][:unit_amount]
  end

  test "still charges shipping above the free-shipping threshold for a non-mainland postcode" do
    # The live bug: a £145 order to BT1 6EE and a £449 order to Skye both shipped
    # free, because the threshold took no account of the destination.
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 450.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session_builder(delivery_postcode: "IV51 9YB").create

    shipping_line = shipping_line_item(captured_params)
    assert shipping_line, "expected an over-threshold Highlands order to still pay shipping"
    assert_equal Shipping.cost_for_zone(:highlands), shipping_line[:price_data][:unit_amount]
  end

  test "still ships free above the threshold for a mainland postcode" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 450.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session_builder(delivery_postcode: "WD18 9SB").create

    assert_nil shipping_line_item(captured_params), "mainland free shipping must be unchanged"
  end

  test "prices as mainland when no delivery postcode was captured" do
    # Guests who skip the cart-page postcode field keep today's behaviour rather
    # than being blocked; Stripe still collects the real address afterwards.
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session

    assert_equal Shipping::STANDARD_COST, shipping_line_item(captured_params)[:price_data][:unit_amount]
  end

  test "prices as mainland when the delivery postcode cannot be parsed" do
    # An unparseable postcode is not a pricing signal. It must not raise on a
    # paying customer, and Stripe still collects the real address next.
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session_builder(delivery_postcode: "not a postcode").create

    assert_equal Shipping::STANDARD_COST, shipping_line_item(captured_params)[:price_data][:unit_amount]
  end

  test "names the zone's transit time on the shipping line so Stripe shows the real promise" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session_builder(delivery_postcode: "HS1 2DD").create

    assert_equal "Shipping (2-4 working days)",
                 shipping_line_item(captured_params).dig(:price_data, :product_data, :name)
  end

  test "records the priced zone in Stripe metadata" do
    # The order must be able to record the zone it was CHARGED for, which is not
    # necessarily the zone of the address Stripe later collects: a customer can
    # type a mainland postcode to price delivery and then enter a Highlands
    # address at Stripe. Metadata is how the priced zone survives the round trip.
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session_builder(delivery_postcode: "BT1 6EE").create

    assert_equal "northern_ireland", captured_params[:metadata][:shipping_zone]
  end

  test "records the mainland zone in metadata when no postcode was captured" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session

    assert_equal "mainland", captured_params[:metadata][:shipping_zone]
  end

  test "the charged shipping matches what OrderTotals displays for the same zone" do
    # These two rules mirror each other by hand, so pin them together: a
    # customer must never be shown one delivery price and charged another.
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 450.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session_builder(delivery_postcode: "BT1 6EE").create

    displayed = OrderTotals.for(@cart.subtotal_amount, shipping: :charged, zone: :northern_ireland).shipping
    charged_pence = shipping_line_item(captured_params)[:price_data][:unit_amount]
    assert_equal displayed, BigDecimal(charged_pence.to_s) / 100
  end

  private

  # The first non-shipping line item. The shipping line is now prepended, so
  # tests must select the product line by content rather than by position.
  # --- custom (on-site) mode ---

  test "custom mode differs from hosted only in ui_mode, URLs, and payment methods" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured = []
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured << params
      true
    end.returns(build_stripe_session)

    build_session
    build_custom_session

    hosted, custom = captured

    assert_equal "custom", custom[:ui_mode]
    assert_equal @return_url, custom[:return_url]
    assert_nil custom[:success_url]
    assert_nil custom[:cancel_url]
    assert_equal [ "card", "link" ], custom[:payment_method_types]

    # Everything else must be identical - this is the parity contract the
    # hosted fallback depends on. Shipping line item drift here costs money.
    mode_keys = [ :ui_mode, :return_url, :success_url, :cancel_url, :payment_method_types ]
    assert_equal hosted.except(*mode_keys), custom.except(*mode_keys)
  end

  # permissions.update_shipping_details=server_only must never come back: the
  # clover elements SDK applies defaultValues (and contact picks) by calling
  # updateShippingAddress internally, which that permission forbids - init
  # throws and the checkout page dies for every customer.
  test "neither mode restricts shipping-details updates" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured = []
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured << params
      true
    end.returns(build_stripe_session)

    build_session
    build_custom_session

    captured.each { |params| assert_nil params[:permissions] }
  end

  test "custom mode pins the shipping line item exactly as hosted does" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_custom_session(delivery_postcode: "IV51 9XX")

    shipping_line = shipping_line_item(captured_params)
    assert_equal Shipping::LINE_ITEM_FLAG, shipping_line[:price_data][:product_data][:metadata]
    assert_equal Shipping.cost_for_zone(:highlands), shipping_line[:price_data][:unit_amount]
    assert_equal "highlands", captured_params[:metadata][:shipping_zone]
  end

  test "custom mode keeps allow_promotion_codes on the no-code path" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_custom_session

    assert_equal true, captured_params[:allow_promotion_codes]
  end

  test "result exposes the priced zone" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
    Stripe::Checkout::Session.stubs(:create).returns(build_stripe_session)

    assert_equal :highlands, build_session(delivery_postcode: "IV51 9XX").zone
    assert_equal :mainland, build_session(delivery_postcode: "WD18 9SB").zone
  end

  def product_line_item(captured_params)
    captured_params[:line_items].find do |li|
      li.dig(:price_data, :product_data, :metadata, "shipping_line") != "true"
    end
  end

  def shipping_line_item(captured_params)
    captured_params[:line_items].find do |li|
      li.dig(:price_data, :product_data, :metadata, "shipping_line") == "true"
    end
  end

  # A resolvable promotion code for the coupon, so apply_discount succeeds and
  # the refusal happens where it really does: at Session.create.
  def stub_welcome_promotion_code
    Stripe::PromotionCode.stubs(:list)
      .returns(stub(data: [ stub(id: "promo_test", code: "WELCOME10") ]))
  end

  # Stripe's refusal when a coupon's restrictions.minimum_amount is not met.
  # The code is what identifies it; the message is Stripe's own wording.
  def amount_insufficient_error
    Stripe::InvalidRequestError.new(
      "This promotion code cannot be redeemed because the order amount is too low.",
      :promotion_code,
      code: "promotion_code_amount_insufficient"
    )
  end

  def build_session(discount_code: nil, delivery_postcode: nil, ui_mode: :hosted, return_url: nil)
    build_session_builder(
      discount_code: discount_code, delivery_postcode: delivery_postcode,
      ui_mode: ui_mode, return_url: return_url
    ).create
  end

  def build_custom_session(**kwargs)
    build_session(ui_mode: :custom, return_url: @return_url, **kwargs)
  end

  def build_session_builder(user: nil, discount_code: nil, delivery_postcode: nil, ui_mode: :hosted, return_url: nil)
    Checkout::SessionBuilder.new(
      cart: @cart,
      user: user,
      discount_code: discount_code,
      delivery_postcode: delivery_postcode,
      datafast_visitor_id: nil,
      datafast_session_id: nil,
      success_url: @success_url,
      cancel_url: @cancel_url,
      ui_mode: ui_mode,
      return_url: return_url
    )
  end
end
