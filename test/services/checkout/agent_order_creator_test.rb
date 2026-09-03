require "test_helper"

class Checkout::AgentOrderCreatorTest < ActiveSupport::TestCase
  include StripeTestHelper

  # An agent checkout for 2 x Product 1 (£9.99 each) plus 1 x Product 2 (£9.99)
  # delivered to the mainland under the free-shipping threshold: products
  # £29.97, delivery £6.99, VAT 20% on both = £7.39, total £44.35.
  def agent_session(overrides = {})
    build_stripe_session({
      id: "cs_agent_1",
      customer_email: "agent-buyer@example.com",
      customer_name: "Agent Buyer",
      amount_subtotal: 2997,
      amount_tax: 739,
      amount_shipping: 699,
      amount_total: 4435,
      metadata: {},
      line_items_data: [
        stripe_agent_line_item(sku: products(:one).sku, unit_amount: 999, quantity: 2),
        stripe_agent_line_item(sku: products(:two).sku, unit_amount: 999, quantity: 1)
      ]
    }.merge(overrides))
  end

  test "creates a paid agent order with items matched by catalogue SKU" do
    order = nil
    assert_difference "Order.count", 1 do
      assert_difference "OrderItem.count", 2 do
        order = Checkout::AgentOrderCreator.new(stripe_session: agent_session).create
      end
    end

    assert_equal "paid", order.status
    assert_equal "agent", order.source
    assert_equal "agent-buyer@example.com", order.email
    assert_equal "cs_agent_1", order.stripe_session_id
    assert_nil order.user
    assert_nil order.organization

    item = order.order_items.find_by(product: products(:one))
    assert_equal 2, item.quantity
    assert_equal 9.99, item.price.to_f
    assert_equal 19.98, item.line_total.to_f
    assert_equal 1, item.pac_size
    assert_equal "BUBL-POP-11", item.product_sku
    assert_equal products(:one).generated_title, item.product_name
  end

  test "records Stripe's amounts: products subtotal, VAT, shipping option and total" do
    order = Checkout::AgentOrderCreator.new(stripe_session: agent_session).create

    assert_equal 29.97, order.subtotal_amount.to_f
    assert_equal 7.39, order.vat_amount.to_f
    assert_equal 6.99, order.shipping_amount.to_f
    assert_equal 44.35, order.total_amount.to_f
    assert_equal 0.0, order.discount_amount.to_f
  end

  test "records the collected shipping and billing addresses" do
    session = agent_session(
      shipping_name: "Agent Buyer",
      shipping_address: { line1: "10 Downing Street", line2: nil, city: "London", postal_code: "SW1A 2AA", country: "GB" }
    )

    order = Checkout::AgentOrderCreator.new(stripe_session: session).create

    assert_equal "Agent Buyer", order.shipping_name
    assert_equal "10 Downing Street", order.shipping_address_line1
    assert_equal "SW1A 2AA", order.shipping_postal_code
    assert_equal "GB", order.shipping_country
    assert_equal "10 Downing Street", order.billing_address_line1
    assert_equal "mainland", order.shipping_zone
  end

  test "raises a permanent error and creates nothing when a SKU is not in the catalogue" do
    session = agent_session(line_items_data: [ stripe_agent_line_item(sku: "NOT-A-SKU", unit_amount: 100) ])

    assert_no_difference [ "Order.count", "OrderItem.count" ] do
      assert_raises Checkout::AgentOrderCreator::UnknownSkuError do
        Checkout::AgentOrderCreator.new(stripe_session: session).create
      end
    end
  end

  test "raises a permanent error when the session has no shipping details" do
    session = agent_session(shipping_address: { line1: nil, city: nil, postal_code: nil, country: nil })

    assert_raises Checkout::MissingShippingDetails do
      Checkout::AgentOrderCreator.new(stripe_session: session).create
    end
  end
end
