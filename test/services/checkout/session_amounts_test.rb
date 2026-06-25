# frozen_string_literal: true

require "test_helper"

# SessionAmounts derives the five money figures we persist on an Order from a
# completed Stripe Checkout session, in pounds.
#
# Shipping is sent as a taxed LINE ITEM (manual tax rates do not tax
# shipping_options), so the session's amount_subtotal now INCLUDES shipping. To
# recover the products-only subtotal we find the shipping line by its product
# metadata and subtract its own post-discount amount_subtotal. VAT (amount_tax)
# already spans products + shipping, which is the whole point of the change.
class Checkout::SessionAmountsTest < ActiveSupport::TestCase
  include StripeTestHelper

  test "subtracts the shipping line from the session subtotal and taxes both" do
    session = build_stripe_session(
      amount_subtotal: 2699, # products 2000 + shipping 699 (pre-tax)
      amount_tax: 540,       # 20% of 26.99
      amount_total: 3239,
      line_items_data: [
        stripe_product_line_item(amount_subtotal: 2000),
        stripe_shipping_line_item(amount_subtotal: 699)
      ]
    )

    amounts = Checkout::SessionAmounts.from(session)

    assert_equal 20.0, amounts.subtotal
    assert_equal 6.99, amounts.shipping
    assert_equal 5.40, amounts.vat
    assert_equal 32.39, amounts.total
  end

  test "reconciles: subtotal + shipping + vat - discount == total, with a discount applied" do
    # Use a discounted session so the - discount term is actually exercised (a
    # zero-discount fixture would pass regardless of whether it belongs). Stripe's
    # amount_subtotal is pre-discount, so subtotal/shipping are gross and the
    # discount is subtracted exactly once to reach the total.
    session = build_stripe_session(
      amount_subtotal: 2699,  # gross: products 2000 + shipping 699 (pre-discount)
      amount_tax: 540,
      amount_discount: 500,
      amount_total: 2739,     # 2699 + 540 - 500
      line_items_data: [
        stripe_product_line_item(amount_subtotal: 2000),
        stripe_shipping_line_item(amount_subtotal: 699)
      ]
    )

    amounts = Checkout::SessionAmounts.from(session)

    assert_equal 5.0, amounts.discount, "the discount term must be non-zero to exercise the invariant"
    assert_equal amounts.total,
                 (amounts.subtotal + amounts.shipping + amounts.vat - amounts.discount).round(2)
  end

  test "shipping is zero and subtotal unchanged when there is no shipping line" do
    # Free-shipping orders carry no shipping line item.
    session = build_stripe_session(
      amount_subtotal: 12000,
      amount_tax: 2400,
      amount_total: 14400,
      line_items_data: [ stripe_product_line_item(amount_subtotal: 12000) ]
    )

    amounts = Checkout::SessionAmounts.from(session)

    assert_equal 120.0, amounts.subtotal
    assert_equal 0.0, amounts.shipping
    assert_equal 24.0, amounts.vat
    assert_equal 144.0, amounts.total
  end

  test "uses the shipping line's own post-discount subtotal under a whole-order discount" do
    # A 20% off-everything coupon: shipping 6.99 -> 5.59 (rounded) post-discount.
    session = build_stripe_session(
      amount_subtotal: 2159, # products 1600 + shipping 559
      amount_tax: 432,
      amount_total: 2591,
      amount_discount: 540,
      line_items_data: [
        stripe_product_line_item(amount_subtotal: 1600),
        stripe_shipping_line_item(amount_subtotal: 559)
      ]
    )

    amounts = Checkout::SessionAmounts.from(session)

    assert_equal 16.0, amounts.subtotal
    assert_equal 5.59, amounts.shipping
    assert_equal 5.40, amounts.discount
  end

  test "identifies the shipping line by product metadata, not by name" do
    # A product literally named "Shipping" but WITHOUT the metadata flag must be
    # treated as a product, while the real shipping line (metadata flag, any name)
    # is subtracted.
    decoy = stripe_product_line_item(amount_subtotal: 1000, name: "Shipping")
    real_shipping = stripe_shipping_line_item(amount_subtotal: 699, name: "Delivery")
    session = build_stripe_session(
      amount_subtotal: 1699,
      amount_tax: 340,
      amount_total: 2039,
      line_items_data: [ decoy, real_shipping ]
    )

    amounts = Checkout::SessionAmounts.from(session)

    assert_equal 6.99, amounts.shipping
    assert_equal 10.0, amounts.subtotal
  end

  test "reads vat and discount from total_details" do
    session = build_stripe_session(
      amount_subtotal: 2000,
      amount_tax: 400,
      amount_total: 2400,
      amount_discount: 250,
      line_items_data: [ stripe_product_line_item(amount_subtotal: 2000) ]
    )

    amounts = Checkout::SessionAmounts.from(session)

    assert_equal 4.0, amounts.vat
    assert_equal 2.5, amounts.discount
  end

  test "tolerates a line item with no expanded price without raising" do
    # The webhook's no-order-items path stubs bare line items; the shipping-line
    # check must not blow up on a line lacking price/product.
    bare = stub(amount_subtotal: 3000, amount_tax: 600, amount_total: 3600, description: "x")
    session = build_stripe_session(
      amount_subtotal: 3000,
      amount_tax: 600,
      amount_total: 3600,
      line_items_data: [ bare ]
    )

    amounts = Checkout::SessionAmounts.from(session)

    assert_equal 30.0, amounts.subtotal
    assert_equal 0.0, amounts.shipping
  end

  test "pages through line items so a shipping line beyond the first page is still found" do
    # Stripe returns at most 10 expanded line items per page and does not promise
    # creation order, so the shipping line can sit on a later page. SessionAmounts
    # must paginate (Stripe does not auto-paginate retrieve) to find it; otherwise
    # shipping records as £0 and stays folded into the subtotal.
    page_one_product = stripe_product_line_item(amount_subtotal: 2000, id: "li_page1")
    shipping_on_page_two = stripe_shipping_line_item(amount_subtotal: 699, id: "li_page2")

    session = build_stripe_session(
      id: "sess_paginated",
      amount_subtotal: 2699, # products 2000 + shipping 699
      amount_tax: 540,
      amount_total: 3239,
      line_items_data: [ page_one_product ],
      line_items_has_more: true
    )

    # Only the items AFTER the embedded first page are fetched (starting_after the
    # last embedded id), then combined with the embedded page - so the first page
    # Stripe already returned is not re-fetched.
    Stripe::Checkout::Session.stubs(:list_line_items)
      .with("sess_paginated", has_entries(expand: [ "data.price.product" ], starting_after: "li_page1"))
      .returns(stub(auto_paging_each: [ shipping_on_page_two ].each))

    amounts = Checkout::SessionAmounts.from(session)

    assert_equal 20.0, amounts.subtotal
    assert_equal 6.99, amounts.shipping
  end

  test "propagates a Stripe error during pagination instead of silently recording zero shipping" do
    # A transient Stripe error while paging a >10-item cart must surface to the
    # caller's handler (the success path rescues it; the webhook lets Stripe retry),
    # not be swallowed into a £0-shipping order.
    page_one_product = stripe_product_line_item(amount_subtotal: 2000, id: "li_page1")
    session = build_stripe_session(
      id: "sess_pagination_error",
      amount_subtotal: 2699,
      amount_tax: 540,
      amount_total: 3239,
      line_items_data: [ page_one_product ],
      line_items_has_more: true
    )
    Stripe::Checkout::Session.stubs(:list_line_items).raises(Stripe::APIError.new("boom"))

    assert_raises(Stripe::StripeError) do
      Checkout::SessionAmounts.from(session)
    end
  end

  test "raises when a line item's product is unexpanded, rather than silently recording zero shipping" do
    # If a caller retrieves the session without expand: line_items.data.price.product,
    # Stripe returns price.product as a String id. The shipping line then cannot be
    # identified, and shipping would silently fold into the subtotal as £0. That is a
    # caller bug (a missing expand), so fail loud instead of corrupting the amounts.
    unexpanded = stub(
      amount_subtotal: 2699,
      price: stub(product: "prod_unexpanded_id")
    )
    session = build_stripe_session(
      amount_subtotal: 2699,
      amount_tax: 540,
      amount_total: 3239,
      line_items_data: [ unexpanded ]
    )

    assert_raises(Checkout::SessionAmounts::UnexpandedLineItemError) do
      Checkout::SessionAmounts.from(session)
    end
  end

  test "falls back to legacy shipping_cost when a session predates line-item shipping" do
    # Sessions created before this change carried shipping via shipping_options, so
    # they have a populated shipping_cost and NO shipping line item, and their
    # amount_subtotal already excludes shipping. We must still record the shipping
    # the customer was charged rather than dropping it to zero.
    session = build_stripe_session(
      amount_subtotal: 2000,        # products only (legacy: excludes shipping)
      amount_tax: 400,
      shipping_amount_total: 699,   # legacy shipping_cost.amount_total
      amount_total: 3099,
      line_items_data: [ stripe_product_line_item(amount_subtotal: 2000) ]
    )

    amounts = Checkout::SessionAmounts.from(session)

    assert_equal 20.0, amounts.subtotal   # not reduced by the legacy shipping
    assert_equal 6.99, amounts.shipping
    assert_equal 30.99, amounts.total
  end
end
