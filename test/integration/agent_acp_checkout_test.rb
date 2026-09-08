# frozen_string_literal: true

require "test_helper"

class AgentAcpCheckoutTest < ActionDispatch::IntegrationTest
  include StripeTestHelper

  setup do
    stub_stripe_tax_rate_list
  end

  test "creates a hosted Stripe checkout session from catalog line items" do
    Stripe::Checkout::Session.stubs(:create).returns(
      stub(id: "cs_test_acp", url: "https://checkout.stripe.com/c/pay/cs_test_acp")
    )

    post "/api/v1/acp/checkout_sessions", params: {
      items: [ { slug: products(:one).slug, quantity: 2 } ]
    }, as: :json

    assert_response :created
    body = response.parsed_body
    assert_equal "cs_test_acp", body["id"]
    assert_equal "https://checkout.stripe.com/c/pay/cs_test_acp", body["checkout_url"]
    assert_includes %w[pending ready_for_payment], body["status"]
  end

  test "returning from Stripe builds the order from the agent cart, not the empty browser cart" do
    Stripe::Checkout::Session.stubs(:create).returns(
      stub(id: "cs_test_acp", url: "https://checkout.stripe.com/c/pay/cs_test_acp")
    )

    post "/api/v1/acp/checkout_sessions", params: {
      items: [ { slug: products(:one).slug, quantity: 2 } ]
    }, as: :json
    assert_response :created

    agent_cart = Cart.last
    stub_stripe_session_retrieve(
      id: "cs_test_acp",
      customer_email: "agent-buyer@example.com",
      metadata: { "cart_id" => agent_cart.id.to_s }
    )

    assert_difference "Order.count", 1 do
      get success_checkout_path, params: { session_id: "cs_test_acp" }
    end

    order = Order.last
    assert_equal [ products(:one).id ], order.order_items.map(&:product_id)
    assert_equal 2, order.order_items.first.quantity
    assert_equal 0, agent_cart.reload.cart_items.count
  end

  test "rejects an empty item list" do
    post "/api/v1/acp/checkout_sessions", params: { items: [] }, as: :json

    assert_response :unprocessable_entity
  end

  test "consolidates a repeated slug into one cart line" do
    Stripe::Checkout::Session.stubs(:create).returns(
      stub(id: "cs_test_dupe", url: "https://checkout.stripe.com/c/pay/cs_test_dupe")
    )

    post "/api/v1/acp/checkout_sessions", params: {
      items: [
        { slug: products(:one).slug, quantity: 1 },
        { slug: products(:one).slug, quantity: 2 }
      ]
    }, as: :json

    assert_response :created
    cart = Cart.last
    assert_equal 1, cart.cart_items.count
    assert_equal 3, cart.cart_items.first.quantity
  end

  test "rejects a quantity the cart cannot hold without leaving a cart behind" do
    assert_no_difference [ "Cart.count", "CartItem.count" ] do
      post "/api/v1/acp/checkout_sessions", params: {
        items: [ { slug: products(:one).slug, quantity: 40_000 } ]
      }, as: :json
    end

    assert_response :unprocessable_entity
    assert response.parsed_body["error"].present?
  end

  test "rejects unknown product slugs" do
    post "/api/v1/acp/checkout_sessions", params: {
      items: [ { slug: "not-a-product", quantity: 1 } ]
    }, as: :json

    assert_response :unprocessable_entity
  end
end
