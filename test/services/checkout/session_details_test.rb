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

  # --- promotion_code ---

  test "promotion_code returns the code from the discount breakdown" do
    session = build_stripe_session(amount_discount: 500, promotion_code: "SUMMER20")

    assert_equal "SUMMER20", Checkout::SessionDetails.promotion_code(session)
  end

  test "promotion_code is nil when the session carries no discount" do
    session = build_stripe_session

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
