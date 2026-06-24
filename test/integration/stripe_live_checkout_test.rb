# frozen_string_literal: true

require "test_helper"

# Live integration test against Stripe's TEST API. It creates a REAL Checkout
# Session (no money moves; test mode) and asserts what Stripe ACTUALLY computes
# for tax, which is the one thing stubs cannot tell us: that under our MANUAL tax
# rates, shipping sent as a taxed line item is genuinely charged VAT.
#
# This is the test that would have caught the earlier tax_code-on-shipping_options
# no-op automatically.
#
# Skipped unless STRIPE_TEST_SECRET_KEY is set, so the normal suite and CI are
# unaffected. To run it:
#
#   STRIPE_TEST_SECRET_KEY=sk_test_xxx bin/rails test \
#     test/integration/stripe_live_checkout_test.rb
#
# It makes real network calls and may create a UK VAT TaxRate in the test account
# on first run (Stripe has no uniqueness constraint, so reruns reuse it via the
# provider's lookup).
class StripeLiveCheckoutTest < ActionDispatch::IntegrationTest
  setup do
    @test_key = ENV["STRIPE_TEST_SECRET_KEY"]
    skip "set STRIPE_TEST_SECRET_KEY to run live Stripe tests" if @test_key.blank?

    @original_api_key = Stripe.api_key
    Stripe.api_key = @test_key
    # The provider memoises the VAT rate id in Rails.cache; clear it so the lookup
    # runs against the test account rather than a cached production/CI value.
    Rails.cache.delete(Checkout::StripeTaxRateProvider::UK_VAT_RATE_ID_CACHE_KEY)
  end

  teardown do
    Stripe.api_key = @original_api_key if defined?(@original_api_key)
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

  private

  def build_session(cart)
    Checkout::SessionBuilder.new(
      cart: cart,
      user: nil,
      address_id: nil,
      discount_code: nil,
      datafast_visitor_id: nil,
      datafast_session_id: nil,
      success_url: "https://example.com/success?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "https://example.com/cancel"
    ).create
  end
end
