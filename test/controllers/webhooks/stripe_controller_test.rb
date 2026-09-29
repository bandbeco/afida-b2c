require "test_helper"

# The webhook is one completion channel (CONTEXT.md: Checkout completion). It
# owns only transport: verifying Stripe's signature, the HTTP status Stripe
# sees (200 stops retries, 5xx asks for one) and its own webhook.* tracing
# events. What a completion does lives in Checkout::CompletionTest.
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

  test "handles unhandled event types gracefully" do
    completed_event(type: "payment_intent.succeeded")
    Checkout::Completion.expects(:complete).never

    post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }

    assert_response :ok
  end

  test "emits webhook.received event when webhook arrives" do
    completed_event(id: "evt_test_123")
    stub_completion(outcome(:existing, orders(:one)))

    assert_event_reported("webhook.received",
      payload: { event_type: "checkout.session.completed", stripe_event_id: "evt_test_123" }
    ) do
      post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
    end

    assert_response :ok
  end

  test "completes the session with no browser present and reports the order it created" do
    completed_event(id: "evt_created")
    Checkout::Completion.expects(:complete).with("sess_hook", browser_present: false)
      .returns(outcome(:created, orders(:one)))

    assert_event_reported("webhook.processed",
      payload: { stripe_event_id: "evt_created", order_id: orders(:one).id }
    ) do
      post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
    end

    assert_response :ok
  end

  test "answers 200 when the redirect already completed the order" do
    completed_event
    stub_completion(outcome(:existing, orders(:one)))

    assert_event_reported("webhook.processed") do
      post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
    end

    assert_response :ok
  end

  test "answers 200 for a session that is not paid" do
    completed_event
    stub_completion(outcome(:unpaid, nil))

    post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }

    assert_response :ok
  end

  test "answers 200 without retrying when the session can never complete" do
    # Retrying the identical payload can never succeed, so 200 stops Stripe
    # retrying for 72h. Completion has already reported it.
    completed_event
    Checkout::Completion.stubs(:complete).raises(Checkout::MissingShippingDetails.new("no shipping"))

    assert_event_reported("webhook.failed") do
      post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
    end

    assert_response :ok
  end

  test "answers 5xx so Stripe retries a transient completion failure" do
    completed_event
    Checkout::Completion.stubs(:complete).raises(Checkout::TransientCompletionFailure.new("connection reset"))

    assert_event_reported("webhook.failed") do
      post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
    end

    assert_response :internal_server_error
  end

  test "answers 5xx and reports an unexpected error rather than losing a paid order" do
    completed_event
    Checkout::Completion.stubs(:complete).raises(StandardError.new("Test error"))
    Sentry.expects(:capture_exception).once

    assert_event_reported("webhook.failed") do
      post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
    end

    assert_response :internal_server_error
  end

  test "creates the order end to end when the redirect never arrived" do
    # The wiring check: a real completion through the Stripe stubs. The
    # order.placed assertion is what reaches Klaviyo; this channel never emitted
    # it before the completion module.
    cart = Cart.create!
    product = products(:one)
    cart.cart_items.create!(product: product, quantity: 2, price: product.price)
    session = build_stripe_session(id: "sess_end_to_end", payment_status: "paid", metadata: { cart_id: cart.id.to_s })
    stub_stripe_webhook_construct_event(build_stripe_webhook_event(type: "checkout.session.completed", data_object: session))
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)
    Ga4MeasurementProtocolService.stubs(:track_purchase)

    assert_difference [ "Order.count", "OrderItem.count" ], 1 do
      assert_event_reported("order.placed", payload: { source: "checkout" }) do
        post webhooks_stripe_url, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "valid_sig" }
      end
    end

    assert_response :ok
    order = Order.find_by!(stripe_session_id: "sess_end_to_end")
    assert_equal 2, order.order_items.first.quantity
    assert_equal 0, cart.reload.cart_items.count
    assert_enqueued_with(job: TelegramOrderNotificationJob, args: [ order.id ])
  end

  private

  def completed_event(type: "checkout.session.completed", id: nil)
    session = build_stripe_session(id: "sess_hook", payment_status: "paid")
    stub_stripe_webhook_construct_event(build_stripe_webhook_event(type: type, data_object: session, id: id))
  end

  def stub_completion(outcome)
    Checkout::Completion.stubs(:complete).returns(outcome)
  end

  def outcome(status, order)
    Checkout::Completion::Outcome.new(order: order, status: status)
  end
end
