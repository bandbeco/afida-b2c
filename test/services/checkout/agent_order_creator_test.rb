require "test_helper"

class Checkout::AgentOrderCreatorTest < ActiveSupport::TestCase
  include StripeTestHelper

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

  test "creates items for SKUs that sit past Stripe's first embedded page" do
    page_one = stripe_agent_line_item(sku: products(:one).sku, unit_amount: 999, quantity: 1, id: "li_page1")
    page_two = stripe_agent_line_item(sku: products(:two).sku, unit_amount: 999, quantity: 1, id: "li_page2")
    session = agent_session(
      amount_subtotal: 1998,
      amount_tax: 400,
      amount_total: 3097,
      line_items_data: [ page_one ],
      line_items_has_more: true
    )
    Stripe::Checkout::Session.stubs(:list_line_items)
      .with(
        "cs_agent_1",
        has_entries(expand: [ "data.price.product" ], starting_after: "li_page1"),
        has_entries(stripe_version: "2025-12-15.preview")
      )
      .returns(stub(auto_paging_each: [ page_two ].each))

    order = Checkout::AgentOrderCreator.new(stripe_session: session).create

    assert_equal [ products(:one).id, products(:two).id ].sort, order.order_items.map(&:product_id).sort
  end

  test "skips a shipping line that has no catalogue SKU" do
    session = agent_session(
      line_items_data: [
        stripe_agent_line_item(sku: products(:one).sku, unit_amount: 999, quantity: 2),
        stripe_shipping_line_item(amount_subtotal: 699)
      ]
    )

    order = Checkout::AgentOrderCreator.new(stripe_session: session).create

    assert_equal [ products(:one) ], order.order_items.map(&:product)
  end

  test "raises a permanent error and creates nothing when a SKU is not in the catalogue" do
    session = agent_session(line_items_data: [ stripe_agent_line_item(sku: "NOT-A-SKU", unit_amount: 100) ])

    assert_no_difference [ "Order.count", "OrderItem.count" ] do
      assert_raises Checkout::AgentOrderCreator::UnknownSkuError do
        Checkout::AgentOrderCreator.new(stripe_session: session).create
      end
    end
  end

  test "skips a line item whose price carries no catalogue reference" do
    session = agent_session(
      line_items_data: [
        stripe_agent_line_item(sku: products(:one).sku, unit_amount: 999, quantity: 2),
        stripe_agent_line_item(sku: nil, unit_amount: 699)
      ]
    )

    order = Checkout::AgentOrderCreator.new(stripe_session: session).create

    assert_equal [ products(:one) ], order.order_items.map(&:product)
  end

  test "raises rather than committing a paid order with no items" do
    session = agent_session(line_items_data: [ stripe_shipping_line_item(amount_subtotal: 699) ])

    assert_no_difference [ "Order.count", "OrderItem.count" ] do
      assert_raises Checkout::AgentOrderCreator::EmptyOrderError do
        Checkout::AgentOrderCreator.new(stripe_session: session).create
      end
    end
  end

  test "fails validation rather than raising when the session carries no customer details" do
    session = agent_session(customer_details: nil)

    assert_raises ActiveRecord::RecordInvalid do
      Checkout::AgentOrderCreator.new(stripe_session: session).create
    end
  end

  test "recognises a session carrying catalogue line items as an agent session" do
    assert Checkout::AgentOrderCreator.new(stripe_session: agent_session).agent_session?
  end

  test "does not recognise a session without catalogue line items as an agent session" do
    session = agent_session(line_items_data: [ stripe_shipping_line_item(amount_subtotal: 699) ])

    assert_not Checkout::AgentOrderCreator.new(stripe_session: session).agent_session?
  end

  test "raises a permanent error when the session has no shipping details" do
    session = agent_session(shipping_address: { line1: nil, city: nil, postal_code: nil, country: nil })

    assert_raises Checkout::MissingShippingDetails do
      Checkout::AgentOrderCreator.new(stripe_session: session).create
    end
  end
end
