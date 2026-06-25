# frozen_string_literal: true

require "test_helper"

# Live integration test against Stripe's TEST API. It creates REAL Checkout
# Sessions (no money moves; test mode) and asserts what Stripe ACTUALLY computes -
# the things stubs cannot tell us: that under our MANUAL tax rates shipping sent as
# a taxed line item is genuinely charged VAT, and how amount_subtotal behaves under
# a discount. This is the test that would have caught the earlier
# tax_code-on-shipping_options no-op automatically.
#
# These make REAL network calls, so they are OPT-IN only: set LIVE_STRIPE_TESTS=1
# and run them in isolation.
#
#   LIVE_STRIPE_TESTS=1 bin/rails test test/integration/stripe_live_checkout_test.rb
#
# They are deliberately excluded from the normal suite and CI: the suite loads the
# webmock gem, which globally disables real HTTP once any webmock test runs, so
# live tests cannot run alongside it. The opt-in flag (never set in CI) keeps the
# suite green; the secret key still comes from credentials.stripe.secret_key, so
# no key env var is needed. The run may create a UK VAT TaxRate in the test
# account on first use (reused on reruns via the provider's lookup).
class StripeLiveCheckoutTest < ActionDispatch::IntegrationTest
  setup do
    skip "set LIVE_STRIPE_TESTS=1 to run live Stripe tests in isolation" unless ENV["LIVE_STRIPE_TESTS"] == "1"

    @test_key = Rails.application.credentials.dig(:stripe, :secret_key)
    skip "no Stripe test key in credentials.stripe.secret_key" if @test_key.blank?
    # Guard: only ever hit Stripe's test mode, never a live account.
    skip "refusing to run live Stripe tests with a non-test key" unless @test_key.start_with?("sk_test_")

    # If webmock loaded (it blocks real HTTP), permit live connections for these.
    WebMock.allow_net_connect! if defined?(WebMock)

    @original_api_key = Stripe.api_key
    Stripe.api_key = @test_key
    # The provider memoises the VAT rate id in Rails.cache; clear it so the lookup
    # runs against the test account rather than a cached production/CI value.
    Rails.cache.delete(Checkout::StripeTaxRateProvider::UK_VAT_RATE_ID_CACHE_KEY)
  end

  teardown do
    # Remove any test-mode coupons created during a test so reruns stay clean.
    @created_coupon_ids&.each do |id|
      Stripe::Coupon.delete(id)
    rescue Stripe::StripeError
      nil
    end
    Stripe.api_key = @original_api_key if defined?(@original_api_key)
    # The session build cached a test-account txr_test_ id; clear it so a later
    # checkout in this process never sends it to the production Stripe API.
    Rails.cache.delete(Checkout::StripeTaxRateProvider::UK_VAT_RATE_ID_CACHE_KEY)
    WebMock.disable_net_connect! if defined?(WebMock)
  end

  test "Stripe charges VAT on subtotal + shipping for a sub-threshold cart" do
    cart = Cart.create!
    # £40 of goods, under the £100 free-shipping threshold, so £6.99 shipping is
    # added as a taxed line item.
    cart.cart_items.create!(product: products(:one), quantity: 4, price: 10.00)

    result = build_session(cart)
    session = Stripe::Checkout::Session.retrieve(
      id: result.session.id,
      expand: [ "line_items.data.price.product", "total_details" ]
    )

    expected_subtotal = 4000 + Shipping::STANDARD_COST          # goods + shipping, pence
    expected_tax = (expected_subtotal * 0.2).round              # VAT on subtotal + shipping

    assert_equal expected_subtotal, session.amount_subtotal,
      "Stripe subtotal should include the shipping line"
    assert_equal expected_tax, session.total_details.amount_tax,
      "Stripe should charge 20% VAT on (goods + shipping), proving shipping is taxed"
    assert_equal expected_subtotal + expected_tax, session.amount_total
  end

  test "Stripe charges no shipping line when the cart qualifies for free shipping" do
    cart = Cart.create!
    cart.cart_items.create!(product: products(:one), quantity: 1, price: 150.00)

    result = build_session(cart)
    session = Stripe::Checkout::Session.retrieve(
      id: result.session.id,
      expand: [ "line_items.data.price.product", "total_details" ]
    )

    shipping_line = session.line_items.data.find do |li|
      li.price.product.respond_to?(:metadata) && li.price.product.metadata["shipping_line"] == "true"
    end
    assert_nil shipping_line, "free-shipping carts should carry no shipping line item"
    assert_equal 15_000, session.amount_subtotal
    assert_equal 3_000, session.total_details.amount_tax # 20% of 150.00, shipping-free
  end

  test "SessionAmounts finds the shipping line when the cart exceeds one line_items page" do
    # Stripe returns at most 10 expanded line items per page and does not promise
    # an order, so a cart with 10+ products can push the shipping line onto a later
    # page. This proves, against the real API, that retrieve reports has_more and
    # that SessionAmounts pages through to recover the shipping charge (rather than
    # recording £0 and folding it into the subtotal).
    cart = Cart.create!
    11.times do |i|
      product = Product.create!(
        name: "Live Bulk #{i}",
        sku: "LIVE-BULK-#{i}-#{cart.id}",
        slug: "live-bulk-#{i}-#{cart.id}",
        category: categories(:one),
        price: 1.00,
        product_type: "standard"
      )
      cart.cart_items.create!(product: product, quantity: 1, price: 1.00)
    end

    result = build_session(cart)
    session = Stripe::Checkout::Session.retrieve(
      id: result.session.id,
      expand: [ "line_items.data.price.product", "total_details" ]
    )

    assert session.line_items.has_more,
      "expected the 11-item session to paginate (proving the has_more path is exercised)"

    amounts = Checkout::SessionAmounts.from(session)

    assert_equal Shipping::STANDARD_COST / 100.0, amounts.shipping,
      "SessionAmounts must page past the first line_items page to find the shipping line"
    assert_equal 11.0, amounts.subtotal, "products subtotal should exclude the shipping line"
  end

  test "a 100%-off coupon zeroes the order total (the no_payment_required trigger)" do
    # A whole-order percentage coupon now discounts the taxed shipping line too,
    # so amount_total reaches 0. Stripe then completes such a session as
    # payment_status "no_payment_required" (not "paid"); this proves the £0 total
    # the gates must accept. (The status itself only appears once the hosted page
    # finalises the session, which can't be driven server-side, so we assert the
    # zero total that produces it.)
    coupon = Stripe::Coupon.create(percent_off: 100, duration: "once", name: "Live Test 100% Off")
    (@created_coupon_ids ||= []) << coupon.id

    cart = Cart.create!
    cart.cart_items.create!(product: products(:one), quantity: 4, price: 10.00) # £40, sub-threshold

    result = build_session(cart, discount_code: coupon.id)
    session = Stripe::Checkout::Session.retrieve(
      id: result.session.id,
      expand: [ "line_items.data.price.product", "total_details" ]
    )

    assert_equal 0, session.amount_total,
      "a 100%-off coupon should zero the whole order, including the shipping line"
    assert_equal 0, session.total_details.amount_tax
  end

  test "SessionAmounts splits subtotal and shipping correctly under a partial whole-order discount" do
    # The discriminating test: a 50%-off coupon. SessionAmounts derives the
    # products subtotal as amount_subtotal - shipping_line.amount_subtotal, which
    # is only correct if BOTH are on the same basis (pre- or post-discount). A
    # partial discount makes pre- and post-discount values differ, so this asserts,
    # against the real Stripe API, what the formula actually produces. The expected
    # values assume Stripe's documented behaviour: amount_subtotal is PRE-discount
    # (amount_total = amount_subtotal + tax - discount), so the split yields the
    # gross figures and the discount is carried separately.
    coupon = Stripe::Coupon.create(percent_off: 50, duration: "once", name: "Live Test 50% Off")
    (@created_coupon_ids ||= []) << coupon.id

    cart = Cart.create!
    cart.cart_items.create!(product: products(:one), quantity: 4, price: 10.00) # £40 goods + £6.99 shipping

    result = build_session(cart, discount_code: coupon.id)
    session = Stripe::Checkout::Session.retrieve(
      id: result.session.id,
      expand: [ "line_items.data.price.product", "total_details" ]
    )

    amounts = Checkout::SessionAmounts.from(session)
    diagnostic = "raw amount_subtotal=#{session.amount_subtotal} amount_discount=#{session.total_details.amount_discount} amount_total=#{session.amount_total}"

    assert_equal 40.0, amounts.subtotal, "products subtotal should be the gross £40 (pre-discount). #{diagnostic}"
    assert_equal 6.99, amounts.shipping, "shipping should be the gross £6.99 (pre-discount). #{diagnostic}"
    # Sanity: the persisted figures reconcile to what Stripe will charge.
    assert_equal (session.amount_total / 100.0).round(2),
                 (amounts.subtotal + amounts.shipping + amounts.vat - amounts.discount).round(2),
                 "subtotal + shipping + vat - discount must equal the charged total. #{diagnostic}"
  end

  private

  def build_session(cart, discount_code: nil)
    Checkout::SessionBuilder.new(
      cart: cart,
      user: nil,
      address_id: nil,
      discount_code: discount_code,
      datafast_visitor_id: nil,
      datafast_session_id: nil,
      success_url: "https://example.com/success?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "https://example.com/cancel"
    ).create
  end
end
