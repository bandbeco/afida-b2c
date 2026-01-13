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
end
