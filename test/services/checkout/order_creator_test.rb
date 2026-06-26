require "test_helper"

class Checkout::OrderCreatorTest < ActiveSupport::TestCase
  include StripeTestHelper

  setup do
    @cart = Cart.create!
    @cart_item = @cart.cart_items.create!(product: products(:one), quantity: 2, price: 10.00)
  end

  test "creates paid order from Stripe amounts and cart items, taxing shipping" do
    # Shipping is a taxed line item, so amount_subtotal includes it (2000 + 699)
    # and amount_tax is VAT on the lot: (20.00 + 6.99) * 0.2 = 5.40.
    stripe_session = build_stripe_session(
      customer_email: "buyer@example.com",
      amount_subtotal: 2699,
      amount_tax: 540,
      amount_total: 3239,
      line_items_data: [
        stripe_product_line_item(amount_subtotal: 2000),
        stripe_shipping_line_item(amount_subtotal: 699)
      ]
    )

    assert_difference [ "Order.count", "OrderItem.count" ], 1 do
      @order = Checkout::OrderCreator.new(stripe_session: stripe_session, cart: @cart).create
    end

    assert_equal "buyer@example.com", @order.email
    assert_equal "paid", @order.status
    assert_equal 20.0, @order.subtotal_amount.to_f
    assert_equal 5.4, @order.vat_amount.to_f
    assert_equal 6.99, @order.shipping_amount.to_f
    assert_equal 32.39, @order.total_amount.to_f

    order_item = @order.order_items.first
    assert_equal @cart_item.product, order_item.product
    assert_equal @cart_item.quantity, order_item.quantity
    assert_equal @cart_item.price, order_item.price
  end

  test "records zero shipping when the session has no shipping line (free shipping)" do
    stripe_session = build_stripe_session(
      customer_email: "buyer@example.com",
      amount_subtotal: 2000,
      amount_tax: 400,
      amount_total: 2400,
      line_items_data: [ stripe_product_line_item(amount_subtotal: 2000) ]
    )

    order = Checkout::OrderCreator.new(stripe_session: stripe_session, cart: @cart).create

    assert_equal 20.0, order.subtotal_amount.to_f
    assert_equal 4.0, order.vat_amount.to_f
    assert_equal 0.0, order.shipping_amount.to_f
    assert_equal 24.0, order.total_amount.to_f
  end

  test "stores promotion code from Stripe discount breakdown" do
    stripe_session = build_stripe_session(
      customer_email: "buyer@example.com",
      amount_discount: 500,
      promotion_code: "SUMMER20"
    )

    order = Checkout::OrderCreator.new(stripe_session: stripe_session, cart: @cart).create

    assert_equal "SUMMER20", order.discount_code
    assert_equal 5.0, order.discount_amount.to_f
  end

  test "marks orders with configured products as design pending" do
    @cart.cart_items.destroy_all
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

    order = Checkout::OrderCreator.new(stripe_session: build_stripe_session, cart: @cart).create

    assert_equal "design_pending", order.branded_order_status
  end

  test "requires shipping details from collected information" do
    stripe_session = build_stripe_session(
      shipping_address: { line1: nil, line2: "Flat 4", city: "London", postal_code: "SW1A 1AA", country: "GB" }
    )

    error = assert_raises(Checkout::MissingShippingDetails) do
      Checkout::OrderCreator.new(stripe_session: stripe_session, cart: @cart).create
    end
    assert_equal "Shipping details are required", error.message
  end

  test "rolls back order when an order item cannot be saved" do
    stripe_session = build_stripe_session(customer_email: "buyer@example.com")
    OrderItem.any_instance.stubs(:save!).raises(ActiveRecord::RecordInvalid.new(OrderItem.new))

    assert_no_difference [ "Order.count", "OrderItem.count" ] do
      assert_raises(ActiveRecord::RecordInvalid) do
        Checkout::OrderCreator.new(stripe_session: stripe_session, cart: @cart).create
      end
    end
  end

  test "propagates unexpected Stripe promotion code shapes" do
    stripe_session = build_stripe_session
    stripe_session.total_details.stubs(:breakdown).raises(NoMethodError.new("unexpected shape"))

    assert_raises(NoMethodError) do
      Checkout::OrderCreator.new(stripe_session: stripe_session, cart: @cart).create
    end
  end
end
