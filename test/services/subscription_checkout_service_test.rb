# frozen_string_literal: true

require "test_helper"
require "ostruct"

class SubscriptionCheckoutServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @cart = Cart.create!(user: @user)
    @product_variant = product_variants(:single_wall_8oz_white)

    # Add items to cart
    @cart.cart_items.create!(
      product_variant: @product_variant,
      quantity: 2,
      price: @product_variant.price
    )

    @service = SubscriptionCheckoutService.new(
      cart: @cart,
      user: @user,
      frequency: "every_month"
    )
  end

  # ==========================================================================
  # T008: ensure_stripe_customer tests
  # ==========================================================================

  test "ensure_stripe_customer returns existing customer if user has stripe_customer_id" do
    @user.update!(stripe_customer_id: "cus_existing123")

    mock_customer = OpenStruct.new(id: "cus_existing123", email: @user.email_address)
    Stripe::Customer.expects(:retrieve).with("cus_existing123").returns(mock_customer)

    customer = @service.send(:ensure_stripe_customer)

    assert_equal "cus_existing123", customer.id
  end

  test "ensure_stripe_customer creates new customer if user has no stripe_customer_id" do
    @user.update!(stripe_customer_id: nil)

    mock_customer = OpenStruct.new(id: "cus_new123", email: @user.email_address)
    Stripe::Customer.expects(:create).with(
      has_entries(
        email: @user.email_address,
        metadata: has_entries(user_id: @user.id.to_s)
      )
    ).returns(mock_customer)

    customer = @service.send(:ensure_stripe_customer)

    assert_equal "cus_new123", customer.id
    assert_equal "cus_new123", @user.reload.stripe_customer_id
  end

  # ==========================================================================
  # T009: build_line_items tests
  # ==========================================================================

  test "build_line_items creates line items with recurring params" do
    line_items = @service.send(:build_line_items)

    assert_equal 1, line_items.length

    item = line_items.first
    assert_equal 2, item[:quantity]
    assert_equal "gbp", item[:price_data][:currency]
    assert_equal (@product_variant.price * 100).to_i, item[:price_data][:unit_amount]

    # Check recurring params for monthly frequency
    assert_equal "month", item[:price_data][:recurring][:interval]
    assert_equal 1, item[:price_data][:recurring][:interval_count]
  end

  test "build_line_items includes product metadata" do
    line_items = @service.send(:build_line_items)
    product_data = line_items.first[:price_data][:product_data]

    assert_includes product_data[:name], @product_variant.product.name
    assert_equal @product_variant.id.to_s, product_data[:metadata][:product_variant_id]
    assert_equal @product_variant.product_id.to_s, product_data[:metadata][:product_id]
    assert_equal @product_variant.sku, product_data[:metadata][:sku]
  end

  test "build_line_items maps weekly frequency correctly" do
    service = SubscriptionCheckoutService.new(cart: @cart, user: @user, frequency: "every_week")
    line_items = service.send(:build_line_items)

    recurring = line_items.first[:price_data][:recurring]
    assert_equal "week", recurring[:interval]
    assert_equal 1, recurring[:interval_count]
  end

  test "build_line_items maps biweekly frequency correctly" do
    service = SubscriptionCheckoutService.new(cart: @cart, user: @user, frequency: "every_two_weeks")
    line_items = service.send(:build_line_items)

    recurring = line_items.first[:price_data][:recurring]
    assert_equal "week", recurring[:interval]
    assert_equal 2, recurring[:interval_count]
  end

  test "build_line_items maps quarterly frequency correctly" do
    service = SubscriptionCheckoutService.new(cart: @cart, user: @user, frequency: "every_3_months")
    line_items = service.send(:build_line_items)

    recurring = line_items.first[:price_data][:recurring]
    assert_equal "month", recurring[:interval]
    assert_equal 3, recurring[:interval_count]
  end

  # ==========================================================================
  # T010: build_items_snapshot tests
  # ==========================================================================

  test "build_items_snapshot captures cart items in JSONB format" do
    snapshot = @service.send(:build_items_snapshot)

    assert snapshot.is_a?(Hash)
    assert_equal 1, snapshot["items"].length

    item = snapshot["items"].first
    assert_equal @product_variant.id, item["product_variant_id"]
    assert_equal @product_variant.product_id, item["product_id"]
    assert_equal @product_variant.sku, item["sku"]
    assert_equal 2, item["quantity"]
  end

  test "build_items_snapshot uses minor currency units (pence)" do
    snapshot = @service.send(:build_items_snapshot)
    item = snapshot["items"].first

    expected_unit_price_minor = (@product_variant.price * 100).to_i
    assert_equal expected_unit_price_minor, item["unit_price_minor"]

    expected_total_minor = expected_unit_price_minor * 2
    assert_equal expected_total_minor, item["total_minor"]
  end

  test "build_items_snapshot calculates totals with VAT" do
    snapshot = @service.send(:build_items_snapshot)

    subtotal_minor = (@product_variant.price * 100).to_i * 2
    vat_minor = (subtotal_minor * 0.2).to_i

    assert_equal subtotal_minor, snapshot["subtotal_minor"]
    assert_equal vat_minor, snapshot["vat_minor"]
    assert_equal subtotal_minor + vat_minor, snapshot["total_minor"]
    assert_equal "gbp", snapshot["currency"]
  end

  # ==========================================================================
  # T011: build_shipping_snapshot tests
  # ==========================================================================

  test "build_shipping_snapshot captures shipping address from Stripe session" do
    stripe_session = OpenStruct.new(
      customer_details: OpenStruct.new(
        name: "John Smith",
        address: OpenStruct.new(
          line1: "123 Business St",
          line2: "Suite 100",
          city: "London",
          postal_code: "EC1A 1BB",
          country: "GB"
        )
      ),
      shipping_cost: OpenStruct.new(
        amount_total: 795,
        shipping_rate: "shr_standard"
      )
    )

    snapshot = @service.send(:build_shipping_snapshot, stripe_session)

    assert_equal "John Smith", snapshot["recipient_name"]
    assert_equal "123 Business St", snapshot["address"]["line1"]
    assert_equal "Suite 100", snapshot["address"]["line2"]
    assert_equal "London", snapshot["address"]["city"]
    assert_equal "EC1A 1BB", snapshot["address"]["postal_code"]
    assert_equal "GB", snapshot["address"]["country"]
    assert_equal 795, snapshot["cost_minor"]
  end

  test "build_shipping_snapshot handles missing shipping cost" do
    stripe_session = OpenStruct.new(
      customer_details: OpenStruct.new(
        name: "John Smith",
        address: OpenStruct.new(
          line1: "123 Business St",
          city: "London",
          postal_code: "EC1A 1BB",
          country: "GB"
        )
      ),
      shipping_cost: nil
    )

    snapshot = @service.send(:build_shipping_snapshot, stripe_session)

    assert_equal 0, snapshot["cost_minor"]
  end

  # ==========================================================================
  # create_checkout_session tests
  # ==========================================================================

  test "create_checkout_session creates Stripe session with subscription mode" do
    @user.update!(stripe_customer_id: "cus_test123")

    mock_customer = OpenStruct.new(id: "cus_test123")
    Stripe::Customer.expects(:retrieve).with("cus_test123").returns(mock_customer)

    mock_session = OpenStruct.new(
      id: "cs_test_session123",
      url: "https://checkout.stripe.com/cs_test_session123"
    )

    Stripe::Checkout::Session.expects(:create).with(
      has_entries(
        mode: "subscription",
        customer: "cus_test123"
      )
    ).returns(mock_session)

    session = @service.create_checkout_session(
      success_url: "http://localhost:3000/subscription_checkouts/success",
      cancel_url: "http://localhost:3000/subscription_checkouts/cancel"
    )

    assert_equal "cs_test_session123", session.id
  end

  test "create_checkout_session includes metadata" do
    @user.update!(stripe_customer_id: "cus_test123")

    mock_customer = OpenStruct.new(id: "cus_test123")
    Stripe::Customer.expects(:retrieve).returns(mock_customer)

    captured_params = nil
    Stripe::Checkout::Session.expects(:create).with { |params|
      captured_params = params
      true
    }.returns(OpenStruct.new(id: "cs_test", url: "https://checkout.stripe.com/test"))

    @service.create_checkout_session(
      success_url: "http://localhost/success",
      cancel_url: "http://localhost/cancel"
    )

    assert_equal @user.id.to_s, captured_params[:metadata][:user_id]
    assert_equal "every_month", captured_params[:metadata][:frequency]
    assert_equal @cart.id.to_s, captured_params[:metadata][:cart_id]
  end

  test "create_checkout_session appends session_id placeholder to success URL" do
    @user.update!(stripe_customer_id: "cus_test123")

    mock_customer = OpenStruct.new(id: "cus_test123")
    Stripe::Customer.expects(:retrieve).returns(mock_customer)

    captured_params = nil
    Stripe::Checkout::Session.expects(:create).with { |params|
      captured_params = params
      true
    }.returns(OpenStruct.new(id: "cs_test", url: "https://checkout.stripe.com/test"))

    @service.create_checkout_session(
      success_url: "http://localhost/success",
      cancel_url: "http://localhost/cancel"
    )

    assert_includes captured_params[:success_url], "{CHECKOUT_SESSION_ID}"
  end

  # ==========================================================================
  # T012: complete_checkout tests
  # ==========================================================================

  test "complete_checkout creates subscription and order from Stripe session" do
    stripe_subscription = OpenStruct.new(
      id: "sub_test123",
      customer: "cus_test123",
      items: OpenStruct.new(
        data: [
          OpenStruct.new(price: OpenStruct.new(id: "price_test123"))
        ]
      ),
      current_period_start: Time.current.to_i,
      current_period_end: 1.month.from_now.to_i
    )

    stripe_session = OpenStruct.new(
      id: "cs_test_session123",
      subscription: stripe_subscription,
      customer: "cus_test123",
      metadata: OpenStruct.new(
        user_id: @user.id.to_s,
        frequency: "every_month",
        cart_id: @cart.id.to_s
      ),
      customer_details: OpenStruct.new(
        email: @user.email_address,
        name: "John Smith",
        address: OpenStruct.new(
          line1: "123 Test St",
          city: "London",
          postal_code: "EC1A 1BB",
          country: "GB"
        )
      ),
      shipping_cost: OpenStruct.new(amount_total: 0)
    )

    Stripe::Checkout::Session.expects(:retrieve).with(
      has_entries(expand: [ "subscription" ])
    ).returns(stripe_session)

    assert_difference [ "Subscription.count", "Order.count" ], 1 do
      result = @service.complete_checkout("cs_test_session123")

      assert result.success?
      assert result.subscription.persisted?
      assert result.order.persisted?
    end

    subscription = Subscription.last
    assert_equal "sub_test123", subscription.stripe_subscription_id
    assert_equal "cus_test123", subscription.stripe_customer_id
    assert_equal "every_month", subscription.frequency
    assert subscription.active?

    order = Order.last
    assert_equal subscription, order.subscription
    assert_equal "cs_test_session123", order.stripe_session_id
    assert_nil order.stripe_invoice_id # First order has no invoice ID
  end

  test "complete_checkout clears the cart" do
    stripe_subscription = OpenStruct.new(
      id: "sub_test123",
      customer: "cus_test123",
      items: OpenStruct.new(
        data: [ OpenStruct.new(price: OpenStruct.new(id: "price_test123")) ]
      ),
      current_period_start: Time.current.to_i,
      current_period_end: 1.month.from_now.to_i
    )

    stripe_session = OpenStruct.new(
      id: "cs_test_session123",
      subscription: stripe_subscription,
      customer: "cus_test123",
      metadata: OpenStruct.new(
        user_id: @user.id.to_s,
        frequency: "every_month",
        cart_id: @cart.id.to_s
      ),
      customer_details: OpenStruct.new(
        email: @user.email_address,
        name: "John Smith",
        address: OpenStruct.new(
          line1: "123 Test St",
          city: "London",
          postal_code: "EC1A 1BB",
          country: "GB"
        )
      ),
      shipping_cost: OpenStruct.new(amount_total: 0)
    )

    Stripe::Checkout::Session.expects(:retrieve).returns(stripe_session)

    assert_equal 1, @cart.cart_items.count
    @service.complete_checkout("cs_test_session123")
    assert_equal 0, @cart.reload.cart_items.count
  end

  test "complete_checkout returns error result when session retrieval fails" do
    Stripe::Checkout::Session.expects(:retrieve).raises(
      Stripe::InvalidRequestError.new("No such session", param: :session_id)
    )

    result = @service.complete_checkout("cs_invalid")

    assert_not result.success?
    assert_includes result.error_message, "session"
  end

  test "complete_checkout is idempotent - returns existing subscription if already completed" do
    existing_subscription = Subscription.create!(
      user: @user,
      stripe_subscription_id: "sub_already_exists",
      stripe_customer_id: "cus_test123",
      stripe_price_id: "price_test123",
      frequency: :every_month,
      status: :active,
      items_snapshot: { "items" => [], "total_minor" => 0 },
      shipping_snapshot: { "address" => {} }
    )

    # Simulate the Stripe session returning the same subscription ID
    stripe_subscription = OpenStruct.new(
      id: "sub_already_exists",
      customer: "cus_test123",
      items: OpenStruct.new(
        data: [ OpenStruct.new(price: OpenStruct.new(id: "price_test123")) ]
      ),
      current_period_start: Time.current.to_i,
      current_period_end: 1.month.from_now.to_i
    )

    stripe_session = OpenStruct.new(
      id: "cs_duplicate_attempt",
      subscription: stripe_subscription,
      customer: "cus_test123",
      metadata: OpenStruct.new(
        user_id: @user.id.to_s,
        frequency: "every_month",
        cart_id: @cart.id.to_s
      ),
      customer_details: OpenStruct.new(
        email: @user.email_address,
        name: "John Smith",
        address: OpenStruct.new(
          line1: "123 Test St",
          city: "London",
          postal_code: "EC1A 1BB",
          country: "GB"
        )
      ),
      shipping_cost: OpenStruct.new(amount_total: 0)
    )

    Stripe::Checkout::Session.expects(:retrieve).returns(stripe_session)

    assert_no_difference "Subscription.count" do
      result = @service.complete_checkout("cs_duplicate_attempt")
      assert result.success?
      assert_equal existing_subscription.id, result.subscription.id
    end
  end
end
