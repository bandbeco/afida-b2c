require "test_helper"

class Webhooks::StripeControllerTest < ActionDispatch::IntegrationTest
  include StripeTestHelper

  setup do
    # Stub credentials to return a test webhook secret
    Rails.application.credentials.stubs(:dig).with(:stripe, :webhook_secret).returns("whsec_test_secret")
    Rails.application.credentials.stubs(:dig).with(:stripe, :publishable_key).returns("pk_test")
    Rails.application.credentials.stubs(:dig).with(:stripe, :secret_key).returns("sk_test")
  end

  test "returns bad_request when webhook secret is missing" do
    Rails.application.credentials.stubs(:dig).with(:stripe, :webhook_secret).returns(nil)

    post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "test_sig" }

    assert_response :bad_request
  end

  test "returns bad_request for invalid JSON payload" do
    Stripe::Webhook.stubs(:construct_event).raises(JSON::ParserError)

    post webhooks_stripe_url, params: "invalid json", headers: { "HTTP_STRIPE_SIGNATURE" => "test_sig" }

    assert_response :bad_request
  end

  test "returns bad_request for invalid signature" do
    Stripe::Webhook.stubs(:construct_event).raises(Stripe::SignatureVerificationError.new("Invalid signature", "test_sig"))

    post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "bad_sig" }

    assert_response :bad_request
  end

  test "handles checkout.session.completed when order already exists" do
    order = orders(:one)
    session = build_stripe_session(id: order.stripe_session_id, payment_status: "paid")
    event = build_stripe_webhook_event(type: "checkout.session.completed", data_object: session)
    stub_stripe_webhook_construct_event(event)

    assert_no_difference "Order.count" do
      post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
    end

    assert_response :ok
  end

  test "handles unhandled event types gracefully" do
    session = build_stripe_session
    event = build_stripe_webhook_event(type: "payment_intent.succeeded", data_object: session)
    stub_stripe_webhook_construct_event(event)

    post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }

    assert_response :ok
  end

  test "skips unpaid checkout sessions" do
    session = build_stripe_session(id: "sess_new_unpaid", payment_status: "unpaid")
    event = build_stripe_webhook_event(type: "checkout.session.completed", data_object: session)
    stub_stripe_webhook_construct_event(event)

    assert_no_difference "Order.count" do
      post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
    end

    assert_response :ok
  end

  test "creates order with order items when cart_id is in metadata" do
    # Create a guest cart with items (simulating what would exist when redirect fails)
    cart = Cart.create!
    product = products(:one)
    cart_item = cart.cart_items.create!(
      product: product,
      quantity: 2,
      price: product.price
    )

    # Build session with cart_id in metadata
    session = build_stripe_session(
      id: "sess_new_with_cart",
      payment_status: "paid",
      metadata: { cart_id: cart.id.to_s },
      amount_total: 3500, # £35.00 in pence
      amount_tax: 500     # £5.00 VAT in pence
    )

    # Stub both the initial event and the retrieve call
    event = build_stripe_webhook_event(type: "checkout.session.completed", data_object: session)
    stub_stripe_webhook_construct_event(event)
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    assert_difference "Order.count", 1 do
      assert_difference "OrderItem.count", 1 do
        post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
      end
    end

    assert_response :ok

    # Verify the order was created correctly
    order = Order.find_by(stripe_session_id: "sess_new_with_cart")
    assert_not_nil order
    assert_equal 1, order.order_items.count
    assert_equal product.id, order.order_items.first.product_id
    assert_equal 2, order.order_items.first.quantity

    # Verify cart was cleared
    assert_equal 0, cart.reload.cart_items.count
  end

  test "creates order without order items when cart_id is missing from metadata" do
    # Build session without cart_id in metadata (legacy sessions)
    session = build_stripe_session(
      id: "sess_no_cart_metadata",
      payment_status: "paid",
      metadata: {},
      amount_total: 3500,
      amount_tax: 500,
      line_items_data: [
        stub(amount_total: 3000, description: "Test Product")
      ]
    )

    event = build_stripe_webhook_event(type: "checkout.session.completed", data_object: session)
    stub_stripe_webhook_construct_event(event)
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    assert_difference "Order.count", 1 do
      assert_no_difference "OrderItem.count" do
        post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
      end
    end

    assert_response :ok

    # Order should exist but without order items
    order = Order.find_by(stripe_session_id: "sess_no_cart_metadata")
    assert_not_nil order
    assert_equal 0, order.order_items.count
  end

  test "creates order without order items when cart no longer exists" do
    # Build session with cart_id that doesn't exist anymore
    session = build_stripe_session(
      id: "sess_deleted_cart",
      payment_status: "paid",
      metadata: { cart_id: "999999" },
      amount_total: 3500,
      amount_tax: 500,
      line_items_data: [
        stub(amount_total: 3000, description: "Test Product")
      ]
    )

    event = build_stripe_webhook_event(type: "checkout.session.completed", data_object: session)
    stub_stripe_webhook_construct_event(event)
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    assert_difference "Order.count", 1 do
      assert_no_difference "OrderItem.count" do
        post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
      end
    end

    assert_response :ok
  end
end
