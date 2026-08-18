require "test_helper"

class Checkout::SessionRepricerTest < ActiveSupport::TestCase
  include StripeTestHelper

  SESSION_ID = "cs_test_reprice_123"

  setup do
    @cart = Cart.create!
    @cart.cart_items.create!(product: products(:one), quantity: 1, price: 10.00)
    stub_stripe_tax_rate_list
  end

  test "refuses an undeliverable postcode without touching Stripe" do
    Stripe::Checkout::Session.expects(:list_line_items).never
    Stripe::Checkout::Session.expects(:update).never

    error = assert_raises(Checkout::SessionRepricer::UndeliverableZone) do
      reprice(postcode: "JE2 3AB")
    end
    assert_equal :undeliverable, error.zone
  end

  test "refuses an unparseable postcode without touching Stripe" do
    Stripe::Checkout::Session.expects(:list_line_items).never
    Stripe::Checkout::Session.expects(:update).never

    error = assert_raises(Checkout::SessionRepricer::UndeliverableZone) do
      reprice(postcode: "NOT A POSTCODE")
    end
    assert_equal :unknown, error.zone
  end

  test "swaps the shipping line for the new zone and retains product lines by id" do
    stub_line_items(
      stripe_shipping_line_item(amount_subtotal: 699, id: "li_ship_old"),
      stripe_product_line_item(amount_subtotal: 1000, id: "li_prod")
    )

    captured = capture_update

    result = reprice(postcode: "IV1 1AA")

    assert_equal :highlands, result.zone
    shipping, *rest = captured[:params][:line_items]
    assert_equal 2500, shipping[:price_data][:unit_amount]
    assert_equal Shipping::LINE_ITEM_FLAG, shipping[:price_data][:product_data][:metadata]
    assert_equal [ { id: "li_prod" } ], rest
    # Retransmitting the old shipping line's id would RETAIN it (verified against
    # the live API), double-charging shipping. Omission is the removal.
    refute_includes captured[:params][:line_items].map { |li| li[:id] }, "li_ship_old"
  end

  test "removes the shipping line when the new zone qualifies for free shipping" do
    @cart.cart_items.create!(product: products(:two), quantity: 1, price: 150.00)
    stub_line_items(
      stripe_shipping_line_item(amount_subtotal: 2500, id: "li_ship_old"),
      stripe_product_line_item(amount_subtotal: 16_000, id: "li_prod")
    )

    captured = capture_update

    result = reprice(postcode: "SW1A 1AA")

    assert_equal :mainland, result.zone
    assert_equal [ { id: "li_prod" } ], captured[:params][:line_items]
  end

  test "adds a shipping line when leaving the free-shipping zone" do
    @cart.cart_items.create!(product: products(:two), quantity: 1, price: 150.00)
    # Free mainland order: the Stripe session carries no shipping line at all.
    stub_line_items(stripe_product_line_item(amount_subtotal: 16_000, id: "li_prod"))

    captured = capture_update

    result = reprice(postcode: "BT1 1AA")

    assert_equal :northern_ireland, result.zone
    shipping, *rest = captured[:params][:line_items]
    assert_equal 2500, shipping[:price_data][:unit_amount]
    assert_equal [ { id: "li_prod" } ], rest
  end

  test "still charges mainland shipping below the free-shipping threshold" do
    stub_line_items(
      stripe_shipping_line_item(amount_subtotal: 2500, id: "li_ship_old"),
      stripe_product_line_item(amount_subtotal: 1000, id: "li_prod")
    )

    captured = capture_update

    reprice(postcode: "SW1A 1AA")

    shipping, = captured[:params][:line_items]
    assert_equal Shipping::STANDARD_COST, shipping[:price_data][:unit_amount]
  end

  test "retains every product line when the session has more than ten" do
    items = (1..11).map { |n| stripe_product_line_item(amount_subtotal: 100, id: "li_prod_#{n}") }
    stub_line_items(stripe_shipping_line_item(amount_subtotal: 699, id: "li_ship_old"), *items)

    captured = capture_update

    reprice(postcode: "IV1 1AA")

    retained = captured[:params][:line_items].filter_map { |li| li[:id] }
    assert_equal items.map(&:id), retained
  end

  test "raises when a line item's product comes back as a bare id" do
    # A String product means the nested expand was dropped: the flag metadata
    # is unreadable, so the shipping line would silently pass as a product line
    # and its id be retained alongside a NEW shipping line (double-charge).
    # Same hardening as SessionAmounts#shipping_line?.
    stub_line_items(stub(id: "li_ship_old", price: stub(product: "prod_unexpanded")))
    Stripe::Checkout::Session.expects(:update).never

    assert_raises(Checkout::SessionAmounts::UnexpandedLineItemError) do
      reprice(postcode: "IV1 1AA")
    end
  end

  test "reports the shipping charge in pence, zero when the order ships free" do
    @cart.cart_items.create!(product: products(:two), quantity: 1, price: 150.00)
    stub_line_items(stripe_product_line_item(amount_subtotal: 16_000, id: "li_prod"))
    capture_update

    assert_equal 2500, reprice(postcode: "IV1 1AA").shipping_pence
    assert_equal 0, reprice(postcode: "SW1A 1AA").shipping_pence
  end

  test "records the priced zone on the session metadata in the same update call" do
    stub_line_items(
      stripe_shipping_line_item(amount_subtotal: 699, id: "li_ship_old"),
      stripe_product_line_item(amount_subtotal: 1000, id: "li_prod")
    )

    captured = capture_update

    reprice(postcode: "IV1 1AA")

    assert_equal SESSION_ID, captured[:id]
    assert_equal({ shipping_zone: "highlands" }, captured[:params][:metadata])
    # The address is deliberately absent: the Stripe SDK syncs it client-side;
    # this update owns only the price.
    assert_nil captured[:params][:collected_information]
  end

  private

  def reprice(postcode:)
    Checkout::SessionRepricer.new(
      stripe_session_id: SESSION_ID,
      cart: @cart,
      postcode: postcode
    ).call
  end

  # The repricer pages with auto_paging_each, so the list stub answers that
  # rather than .data.
  def stub_line_items(*items)
    Stripe::Checkout::Session
      .stubs(:list_line_items)
      .with { |id, params| id == SESSION_ID && params[:expand] == [ "data.price.product" ] }
      .returns(stub(auto_paging_each: items.each))
  end

  # Captures the update's id and params; returns the holder hash.
  def capture_update(session: build_custom_stripe_session)
    captured = {}
    Stripe::Checkout::Session.stubs(:update).with do |id, params|
      captured[:id] = id
      captured[:params] = params
      true
    end.returns(session)
    captured
  end
end
