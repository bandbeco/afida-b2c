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
    assert_nil captured_params[:metadata][:discount_code]
  end

  private

  def build_session(discount_code: nil)
    Checkout::SessionBuilder.new(
      cart: @cart,
      user: nil,
      address_id: nil,
      discount_code: discount_code,
      datafast_visitor_id: nil,
      datafast_session_id: nil,
      success_url: @success_url,
      cancel_url: @cancel_url
    ).create
  end
end
