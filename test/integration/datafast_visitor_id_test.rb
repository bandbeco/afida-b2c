# frozen_string_literal: true

require "test_helper"

# The Datafa.st conversion funnel was broken because nothing ever populated
# cookies[:datafast_visitor_id] — the Datafa.st script is meant to set it but
# does not reliably do so on this site, so every goal was dropped as blank.
#
# The fix guarantees a first-party datafast_visitor_id cookie exists on every
# request (reusing the Datafa.st-set value if present, else minting our own
# UUID). Because the Datafa.st script reads an existing datafast_visitor_id
# cookie before generating its own, setting it server-side means both sides
# share one id, and all downstream goal tracking (cart, checkout, webhook via
# Stripe metadata) starts working.
class DatafastVisitorIdTest < ActionDispatch::IntegrationTest
  test "sets a datafast_visitor_id cookie when none is present" do
    assert_nil cookies[:datafast_visitor_id]

    get root_path

    assert_response :success
    assert cookies[:datafast_visitor_id].present?, "expected a datafast_visitor_id cookie to be set"
    # Should be a UUID we minted
    assert_match(/\A[0-9a-f-]{36}\z/, cookies[:datafast_visitor_id])
  end

  test "preserves an existing datafast_visitor_id cookie (e.g. one Datafast set)" do
    existing = "a3ab2331-989f-4cfa-91c6-2461c9e3c6bd"
    cookies[:datafast_visitor_id] = existing

    get root_path

    assert_response :success
    assert_equal existing, cookies[:datafast_visitor_id], "must not overwrite an existing visitor id"
  end

  test "keeps the same minted id stable across requests" do
    get root_path
    first = cookies[:datafast_visitor_id]
    assert first.present?

    get root_path
    assert_equal first, cookies[:datafast_visitor_id], "visitor id must be stable across requests"
  end

  test "the guaranteed visitor id reaches checkout Stripe metadata" do
    # Establish a cart with an item so checkout can build a session
    post cart_cart_items_path, params: {
      cart_item: { sku: products(:single_wall_8oz_white).sku, quantity: 1 }
    }
    visitor_id = cookies[:datafast_visitor_id]
    assert visitor_id.present?, "cart request should have minted a visitor id"

    # SessionBuilder must receive the non-blank visitor id (it flows into Stripe
    # metadata, which the webhook later reads for purchase attribution).
    captured = nil
    Checkout::SessionBuilder.stubs(:new).with do |kwargs|
      captured = kwargs[:datafast_visitor_id]
      true
    end.raises(Stripe::StripeError.new("stop before real Stripe call"))

    post checkout_path

    assert_equal visitor_id, captured,
      "checkout must pass the guaranteed visitor id into the Stripe session builder"
  end
end
