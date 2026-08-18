require "test_helper"

# SessionDetails is the single home for pulling the non-money Order fields out of a
# completed Stripe Checkout session: the shipping address and the promotion code.
# Both order-creation paths (Checkout::OrderCreator on the success redirect and the
# Stripe webhook) call it so the two can't drift in how they read a session.
class Checkout::SessionDetailsTest < ActiveSupport::TestCase
  include StripeTestHelper

  # --- shipping_address ---

  test "shipping_address maps the collected shipping details to the order fields" do
    session = build_stripe_session(
      shipping_name: "Ada Lovelace",
      shipping_address: { line1: "5 Analytical Way", line2: "Engine House", city: "London", postal_code: "EC1A 1AA", country: "GB" }
    )

    address = Checkout::SessionDetails.shipping_address(session)

    assert_equal "Ada Lovelace", address[:name]
    assert_equal "5 Analytical Way", address[:line1]
    assert_equal "Engine House", address[:line2]
    assert_equal "London", address[:city]
    assert_equal "EC1A 1AA", address[:postal_code]
    assert_equal "GB", address[:country]
  end

  test "shipping_address returns an empty hash when there are no shipping details" do
    session = stub(to_hash: { collected_information: {} })

    assert_equal({}, Checkout::SessionDetails.shipping_address(session))
  end

  test "shipping_address returns an empty hash when shipping details carry no address" do
    session = stub(to_hash: { collected_information: { shipping_details: { name: "No Address" } } })

    assert_equal({}, Checkout::SessionDetails.shipping_address(session))
  end

  # --- billing_address ---

  test "billing_address maps customer_details to the order fields" do
    session = build_stripe_session(
      billing_name: "Ada Lovelace Ltd",
      billing_address: { line1: "1 Finance Row", city: "Manchester", postal_code: "M1 1AA", country: "GB" }
    )

    billing = Checkout::SessionDetails.billing_address(session)

    assert_equal "Ada Lovelace Ltd", billing[:name]
    assert_equal "1 Finance Row", billing[:line1]
    assert_nil billing[:line2]
    assert_equal "Manchester", billing[:city]
    assert_equal "M1 1AA", billing[:postal_code]
    assert_equal "GB", billing[:country]
  end

  test "billing_address defaults to the shipping address like Stripe does" do
    session = build_stripe_session(
      shipping_name: "Ada Lovelace",
      shipping_address: { line1: "5 Analytical Way", line2: "Engine House", city: "London", postal_code: "EC1A 1AA", country: "GB" }
    )

    billing = Checkout::SessionDetails.billing_address(session)

    assert_equal "5 Analytical Way", billing[:line1]
    assert_equal "London", billing[:city]
  end

  test "billing_address returns an empty hash when customer_details carries no address" do
    session = build_stripe_session(billing_address: nil)

    assert_equal({}, Checkout::SessionDetails.billing_address(session))
  end

  test "billing_address returns an empty hash when the session has no customer_details" do
    session = stub(to_hash: { collected_information: {} })

    assert_equal({}, Checkout::SessionDetails.billing_address(session))
  end

  # --- order_address_attributes ---

  test "order_address_attributes maps both addresses to order columns in one pass" do
    session = build_stripe_session(
      shipping_name: "Ada Lovelace",
      shipping_address: { line1: "5 Analytical Way", line2: "Engine House", city: "London", postal_code: "EC1A 1AA", country: "GB" },
      billing_name: "Ada Lovelace Ltd",
      billing_address: { line1: "1 Finance Row", city: "Manchester", postal_code: "M1 1AA", country: "GB" }
    )

    attributes = Checkout::SessionDetails.order_address_attributes(session)

    assert_equal "Ada Lovelace", attributes[:shipping_name]
    assert_equal "5 Analytical Way", attributes[:shipping_address_line1]
    assert_equal "Engine House", attributes[:shipping_address_line2]
    assert_equal "London", attributes[:shipping_city]
    assert_equal "EC1A 1AA", attributes[:shipping_postal_code]
    assert_equal "GB", attributes[:shipping_country]
    assert_equal "Ada Lovelace Ltd", attributes[:billing_name]
    assert_equal "1 Finance Row", attributes[:billing_address_line1]
    assert_nil attributes[:billing_address_line2]
    assert_equal "Manchester", attributes[:billing_city]
    assert_equal "M1 1AA", attributes[:billing_postal_code]
    assert_equal "GB", attributes[:billing_country]
  end

  test "order_address_attributes leaves billing columns nil when the session has no billing" do
    session = build_stripe_session(billing_address: nil)

    attributes = Checkout::SessionDetails.order_address_attributes(session)

    assert_equal "Test Customer", attributes[:shipping_name]
    assert_nil attributes[:billing_name]
    assert_nil attributes[:billing_address_line1]
  end

  # --- promotion_code ---

  test "promotion_code returns the code from the discount breakdown" do
    session = build_stripe_session(amount_discount: 500, promotion_code: "SUMMER20")

    assert_equal "SUMMER20", Checkout::SessionDetails.promotion_code(session)
  end

  test "promotion_code is nil when the session carries no discount" do
    session = build_stripe_session

    assert_nil Checkout::SessionDetails.promotion_code(session)
  end

  # Neither order-creation path expands total_details.breakdown, so Stripe returns
  # discount.promotion_code as a bare "promo_..." ID string. Calling .code on a String
  # returns nil, which silently dropped the code from 13 of 22 live welcome-coupon
  # orders. Resolve the ID to its human-typed code instead.
  test "promotion_code resolves an unexpanded promotion-code ID to its code" do
    session = build_stripe_session(amount_discount: 573, promotion_code_id: "promo_1Tjf7K")
    Stripe::PromotionCode.expects(:retrieve).with("promo_1Tjf7K").returns(stub(code: "WELCOME10"))

    assert_equal "WELCOME10", Checkout::SessionDetails.promotion_code(session)
  end

  # A lookup failure must not cost us the code's absence being distinguishable, but it
  # also must never fail a paid order: callers treat nil as "no code recorded".
  test "promotion_code returns nil when the promotion-code lookup fails" do
    session = build_stripe_session(amount_discount: 573, promotion_code_id: "promo_missing")
    Stripe::PromotionCode.expects(:retrieve).raises(Stripe::InvalidRequestError.new("no such code", nil))

    assert_nil Checkout::SessionDetails.promotion_code(session)
  end

  # The traversal does NOT rescue: an unexpected Stripe shape surfaces so each caller
  # can apply its own policy (OrderCreator lets it raise so a success failure is
  # visible; the webhook rescues it to nil so a cosmetic field can't fail a paid order).
  test "promotion_code propagates an unexpected Stripe shape rather than swallowing it" do
    session = build_stripe_session
    session.total_details.stubs(:breakdown).raises(NoMethodError.new("unexpected shape"))

    assert_raises(NoMethodError) do
      Checkout::SessionDetails.promotion_code(session)
    end
  end
end
