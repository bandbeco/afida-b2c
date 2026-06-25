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
      assert_no_enqueued_jobs only: TelegramOrderNotificationJob do
        post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
      end
    end

    assert_response :ok
  end

  test "returns 200 without erroring when it loses the create race (order already committed)" do
    # The success redirect committed the order in the window after the webhook's
    # find_by check, so create! hits the unique index. That is benign - the order
    # exists - so return 200 and do not ask Stripe to retry.
    cart = Cart.create!
    cart.cart_items.create!(product: products(:one), quantity: 1, price: products(:one).price)
    session = build_stripe_session(
      id: "sess_webhook_race", payment_status: "paid",
      metadata: { cart_id: cart.id.to_s }, amount_total: 1699, amount_tax: 283
    )
    event = build_stripe_webhook_event(type: "checkout.session.completed", data_object: session)
    stub_stripe_webhook_construct_event(event)
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)
    # The competing order exists by the time we re-check in the rescue.
    Order.stubs(:find_by).with(stripe_session_id: "sess_webhook_race").returns(nil).then.returns(
      Order.create!(
        email: "r@e.com", stripe_session_id: "sess_webhook_race", status: "paid",
        subtotal_amount: 10, vat_amount: 2, shipping_amount: 6.99, total_amount: 18.99,
        shipping_name: "R", shipping_address_line1: "1", shipping_city: "L",
        shipping_postal_code: "SW1A 1AA", shipping_country: "GB"
      )
    )
    Order.stubs(:create!).raises(ActiveRecord::RecordNotUnique.new("duplicate key"))

    post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }

    assert_response :ok
  end

  test "returns 5xx so Stripe retries when order creation hits a transient error" do
    # A transient failure (DB blip, Stripe error) must NOT be swallowed as 200 -
    # that would lose a paid order with no retry. Re-raise so Stripe retries.
    cart = Cart.create!
    cart.cart_items.create!(product: products(:one), quantity: 1, price: products(:one).price)
    session = build_stripe_session(
      id: "sess_webhook_transient", payment_status: "paid",
      metadata: { cart_id: cart.id.to_s }, amount_total: 1699, amount_tax: 283
    )
    event = build_stripe_webhook_event(type: "checkout.session.completed", data_object: session)
    stub_stripe_webhook_construct_event(event)
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)
    Order.stubs(:create!).raises(ActiveRecord::StatementInvalid.new("connection reset"))

    assert_no_difference "Order.count" do
      post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
    end

    assert_response :internal_server_error
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

  test "creates order for a no_payment_required (fully discounted) checkout session" do
    # A 100%-off coupon zeroes amount_total, so Stripe sets payment_status to
    # "no_payment_required" rather than "paid". The webhook fallback must still
    # create the order (these orders fire no payment_intent, so the webhook is
    # the only reliable signal).
    cart = Cart.create!
    product = products(:one)
    cart.cart_items.create!(product: product, quantity: 2, price: product.price)

    session = build_stripe_session(
      id: "sess_no_payment_required",
      payment_status: "no_payment_required",
      metadata: { cart_id: cart.id.to_s },
      amount_subtotal: 0,
      amount_tax: 0,
      amount_total: 0
    )
    event = build_stripe_webhook_event(type: "checkout.session.completed", data_object: session)
    stub_stripe_webhook_construct_event(event)
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    assert_difference "Order.count", 1 do
      post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
    end

    assert_response :ok

    order = Order.find_by(stripe_session_id: "sess_no_payment_required")
    assert_not_nil order
    assert_equal 0, order.total_amount
    assert_equal 1, order.order_items.count
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

    # Telegram notification enqueued for the new order
    assert_enqueued_with(job: TelegramOrderNotificationJob, args: [ order.id ])
  end

  test "rolls back the order when an order item fails, leaving no item-less paid order" do
    # The order and its items must be created atomically: a mid-loop OrderItem
    # failure must not leave a committed paid order with missing items.
    cart = Cart.create!
    cart.cart_items.create!(product: products(:one), quantity: 2, price: products(:one).price)

    session = build_stripe_session(
      id: "sess_item_fails",
      payment_status: "paid",
      metadata: { cart_id: cart.id.to_s },
      amount_total: 3500,
      amount_tax: 500
    )
    event = build_stripe_webhook_event(type: "checkout.session.completed", data_object: session)
    stub_stripe_webhook_construct_event(event)
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    # Force item creation to fail after the order row would be created.
    OrderItem.any_instance.stubs(:save!).raises(ActiveRecord::RecordInvalid.new(OrderItem.new))

    assert_no_difference "Order.count" do
      post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
    end

    # The transaction rolls back (no item-less order) and the error is re-raised so
    # Stripe retries rather than silently losing the paid order.
    assert_response :internal_server_error
    assert_nil Order.find_by(stripe_session_id: "sess_item_fails")
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

  # ============================================================================
  # GA4 MEASUREMENT PROTOCOL TRACKING
  # ============================================================================

  test "calls GA4 Measurement Protocol tracking after creating order from webhook" do
    cart = Cart.create!
    product = products(:one)
    cart.cart_items.create!(product: product, quantity: 1, price: product.price)

    session = build_stripe_session(
      id: "sess_ga4_tracking",
      payment_status: "paid",
      metadata: { cart_id: cart.id.to_s }
    )
    event = build_stripe_webhook_event(type: "checkout.session.completed", data_object: session)
    stub_stripe_webhook_construct_event(event)
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    Ga4MeasurementProtocolService.expects(:track_purchase).once.with { |order| order.is_a?(Order) }

    post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }

    assert_response :ok
  end

  # ============================================================================
  # DISCOUNT / STRIPE-SOURCED TOTALS TESTS
  # ============================================================================

  test "creates order with Stripe-sourced amounts including discount" do
    cart = Cart.create!
    product = products(:one)
    cart.cart_items.create!(product: product, quantity: 2, price: product.price)

    # Shipping is a taxed line item: amount_subtotal includes it (1900 + 500) and
    # amount_tax is VAT on both: 2400 * 0.2 = 480.
    session = build_stripe_session(
      id: "sess_webhook_discount",
      payment_status: "paid",
      metadata: { cart_id: cart.id.to_s, discount_code: "WELCOME5" },
      amount_subtotal: 2400,
      amount_tax: 480,
      amount_total: 2880,
      amount_discount: 100,
      line_items_data: [
        stripe_product_line_item(amount_subtotal: 1900),
        stripe_shipping_line_item(amount_subtotal: 500)
      ]
    )

    event = build_stripe_webhook_event(type: "checkout.session.completed", data_object: session)
    stub_stripe_webhook_construct_event(event)
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    assert_difference "Order.count", 1 do
      post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
    end

    order = Order.find_by(stripe_session_id: "sess_webhook_discount")
    assert_equal 19.0, order.subtotal_amount.to_f
    assert_equal 4.80, order.vat_amount.to_f
    assert_equal 5.0, order.shipping_amount.to_f
    assert_equal 28.80, order.total_amount.to_f
    assert_equal 1.0, order.discount_amount.to_f
    assert_equal "WELCOME5", order.discount_code
  end

  test "expands nested line item product so the shipping line is identifiable" do
    cart = Cart.create!
    cart.cart_items.create!(product: products(:one), quantity: 1, price: products(:one).price)

    session = build_stripe_session(
      id: "sess_webhook_expand",
      payment_status: "paid",
      metadata: { cart_id: cart.id.to_s },
      amount_subtotal: 1000,
      amount_tax: 200,
      amount_total: 1200,
      line_items_data: [ stripe_product_line_item(amount_subtotal: 1000) ]
    )

    event = build_stripe_webhook_event(type: "checkout.session.completed", data_object: session)
    stub_stripe_webhook_construct_event(event)
    Stripe::Checkout::Session.expects(:retrieve).with do |args|
      args[:expand] == [ "collected_information", "line_items.data.price.product" ]
    end.returns(session)

    assert_difference "Order.count", 1 do
      post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
    end
  end

  # ============================================================================
  # CUSTOMER-ENTERED PROMOTION CODE TESTS
  # ============================================================================

  test "creates order with promotion code when customer enters code at checkout" do
    cart = Cart.create!
    product = products(:one)
    cart.cart_items.create!(product: product, quantity: 2, price: product.price)

    session = build_stripe_session(
      id: "sess_webhook_promo_code",
      payment_status: "paid",
      metadata: { cart_id: cart.id.to_s },
      amount_subtotal: 2300,
      amount_tax: 460,
      amount_total: 2760,
      amount_discount: 200,
      promotion_code: "SUMMER20",
      line_items_data: [
        stripe_product_line_item(amount_subtotal: 1800),
        stripe_shipping_line_item(amount_subtotal: 500)
      ]
    )

    event = build_stripe_webhook_event(type: "checkout.session.completed", data_object: session)
    stub_stripe_webhook_construct_event(event)
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    assert_difference "Order.count", 1 do
      post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
    end

    order = Order.find_by(stripe_session_id: "sess_webhook_promo_code")
    assert_equal 2.0, order.discount_amount.to_f
    assert_equal "SUMMER20", order.discount_code
  end

  # ============================================================================
  # STRUCTURED EVENT EMISSION TESTS (User Story 1: Debug Silent Failures)
  # ============================================================================

  test "emits webhook.received event when webhook arrives" do
    session = build_stripe_session(id: "sess_event_test", payment_status: "paid")
    event = build_stripe_webhook_event(
      type: "checkout.session.completed",
      id: "evt_test_123",
      data_object: session
    )
    stub_stripe_webhook_construct_event(event)
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    assert_event_reported("webhook.received",
      payload: {
        event_type: "checkout.session.completed",
        stripe_event_id: "evt_test_123"
      }
    ) do
      post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
    end

    assert_response :ok
  end

  test "emits webhook.processed event after successful handling" do
    cart = Cart.create!
    product = products(:one)
    cart.cart_items.create!(product: product, quantity: 1, price: product.price)

    session = build_stripe_session(
      id: "sess_processed_test",
      payment_status: "paid",
      metadata: { cart_id: cart.id.to_s }
    )
    event = build_stripe_webhook_event(
      type: "checkout.session.completed",
      id: "evt_processed_123",
      data_object: session
    )
    stub_stripe_webhook_construct_event(event)
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    assert_event_reported("webhook.processed") do
      post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
    end

    assert_response :ok
  end

  test "emits webhook.failed event when processing fails" do
    session = build_stripe_session(
      id: "sess_failing_test",
      payment_status: "paid",
      metadata: { cart_id: "999999" }
    )
    event = build_stripe_webhook_event(
      type: "checkout.session.completed",
      id: "evt_failing_123",
      data_object: session
    )
    stub_stripe_webhook_construct_event(event)

    # Make the retrieve call raise an error
    Stripe::Checkout::Session.stubs(:retrieve).raises(StandardError.new("Test error"))

    assert_event_reported("webhook.failed") do
      post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
    end

    # Returns 5xx so Stripe retries rather than silently losing the paid order.
    assert_response :internal_server_error
  end

  # ============================================================================
  # DATAFAST CONVERSION TRACKING TESTS
  # ============================================================================

  test "emits checkout.completed event with datafast visitor ID from metadata" do
    cart = Cart.create!
    product = products(:one)
    cart.cart_items.create!(product: product, quantity: 1, price: product.price)

    # Build session with datafast IDs in metadata (as stored during checkout creation)
    session = build_stripe_session(
      id: "sess_datafast_test",
      payment_status: "paid",
      metadata: {
        cart_id: cart.id.to_s,
        datafast_visitor_id: "dfv_test_visitor_123",
        datafast_session_id: "dfs_test_session_456"
      }
    )
    event = build_stripe_webhook_event(type: "checkout.session.completed", data_object: session)
    stub_stripe_webhook_construct_event(event)
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    assert_event_reported("checkout.completed",
      payload: {
        order_id: ->(id) { id.is_a?(Integer) },
        total: ->(t) { t.is_a?(Float) || t.is_a?(BigDecimal) },
        payment_method: "card"
      }
    ) do
      post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
    end

    assert_response :ok
  end

  test "skips checkout.completed event when datafast visitor ID is missing" do
    cart = Cart.create!
    product = products(:one)
    cart.cart_items.create!(product: product, quantity: 1, price: product.price)

    # Build session without datafast metadata
    session = build_stripe_session(
      id: "sess_no_datafast",
      payment_status: "paid",
      metadata: { cart_id: cart.id.to_s }
    )
    event = build_stripe_webhook_event(type: "checkout.session.completed", data_object: session)
    stub_stripe_webhook_construct_event(event)
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    # Should emit webhook.processed but NOT checkout.completed
    assert_no_event_reported("checkout.completed") do
      post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
    end

    assert_response :ok
  end
end
