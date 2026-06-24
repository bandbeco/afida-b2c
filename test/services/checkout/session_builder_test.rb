require "test_helper"

class Checkout::SessionBuilderTest < ActiveSupport::TestCase
  include StripeTestHelper

  setup do
    @cart = Cart.create!
    @success_url = "https://example.com/checkout/success?session_id={CHECKOUT_SESSION_ID}"
    @cancel_url = "https://example.com/checkout/cancel"
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

    line_item = captured_params[:line_items].first
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

    line_item = captured_params[:line_items].first
    assert_equal 1, line_item[:quantity]
    assert_equal 100_000, line_item[:price_data][:unit_amount]
    assert_match "12oz (5,000 units)", line_item[:price_data][:product_data][:name]
  end

  test "builds guest checkout session without customer details" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    result = build_session

    assert_nil result.selected_address_id
    assert_nil captured_params[:customer]
    assert_nil captured_params[:customer_email]
    assert_nil captured_params[:client_reference_id]
  end

  test "marks invalid session discount while still allowing customer promotion codes" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
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

  test "appends a taxed shipping line item for sub-threshold carts" do
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    build_session

    shipping_line = captured_params[:line_items].find do |li|
      li.dig(:price_data, :product_data, :metadata, :shipping_line) == "true"
    end
    assert shipping_line, "expected a shipping line item"
    assert_equal Shipping::STANDARD_COST, shipping_line[:price_data][:unit_amount]
    assert_equal "exclusive", shipping_line[:price_data][:tax_behavior]
    assert_equal 1, shipping_line[:tax_rates].length
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
      li.dig(:price_data, :product_data, :metadata, :shipping_line) == "true"
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
      li.dig(:price_data, :product_data, :metadata, :shipping_line) == "true"
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

  test "does not expose intermediate checkout state readers" do
    builder = build_session_builder(discount_code: "WELCOME5")

    assert_respond_to builder, :invalid_discount?
    assert_not_respond_to builder, :invalid_discount_code
    assert_not_respond_to builder, :selected_address_id
  end

  test "uses selected saved address as Stripe customer for logged-in checkout" do
    user = users(:one)
    address = addresses(:office)
    user.update!(stripe_customer_id: "cus_saved_address")
    user.expects(:sync_stripe_customer!).with(address: address).once
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)

    captured_params = nil
    Stripe::Checkout::Session.stubs(:create).with do |params|
      captured_params = params
      true
    end.returns(build_stripe_session)

    result = build_session_builder(user: user, address_id: address.id).create

    assert_equal address.id, result.selected_address_id
    assert_equal "cus_saved_address", captured_params[:customer]
    assert_nil captured_params[:customer_email]
  end

  private

  def build_session(discount_code: nil)
    build_session_builder(discount_code: discount_code).create
  end

  def build_session_builder(user: nil, address_id: nil, discount_code: nil)
    Checkout::SessionBuilder.new(
      cart: @cart,
      user: user,
      address_id: address_id,
      discount_code: discount_code,
      datafast_visitor_id: nil,
      datafast_session_id: nil,
      success_url: @success_url,
      cancel_url: @cancel_url
    )
  end
end
