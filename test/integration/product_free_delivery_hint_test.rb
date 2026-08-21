require "test_helper"

class ProductFreeDeliveryHintTest < ActionDispatch::IntegrationTest
  include ActionView::Helpers::NumberHelper

  setup do
    @product = products(:single_wall_8oz_white)
  end

  # turbo_stream payloads wrap their markup in <template>, which assert_select
  # will not descend into. Unwrap every template into one document so the
  # streamed fragments can be asserted as ordinary markup.
  def assert_select_turbo_stream_body(&block)
    bodies = Nokogiri::HTML5.fragment(response.body)
      .css("turbo-stream template").map(&:inner_html).join
    assert_select Nokogiri::HTML5("<body>#{bodies}</body>"), "body", &block
  end

  test "renders a visually prominent free-delivery hint on the PDP" do
    get product_path(@product)

    assert_select "[data-test='free-delivery-hint']" do
      assert_select "[data-test='free-delivery-amount']", text: /£100/
    end
  end

  test "free-delivery hint mentions free delivery" do
    get product_path(@product)

    assert_select "[data-test='free-delivery-hint']", text: /free delivery/i
  end

  # Free delivery only applies to the mainland (ShippingZone::FREE_SHIPPING_ZONES).
  # An unqualified claim here is a promise we cannot keep for Northern Ireland,
  # the Highlands or the islands, all of which have placed real orders.
  test "free-delivery hint qualifies the promise as mainland UK" do
    get product_path(@product)

    assert_select "[data-test='free-delivery-hint']", text: /mainland UK/i
  end

  # The sentence is built on the server, so the buy box no longer ships the
  # threshold, the cart subtotal or the page's opening total for a client to do
  # arithmetic with. Their absence is the point: nothing is left to drift.
  test "the buy box carries no client-side countdown state" do
    get product_path(@product)

    assert_select "[data-free-delivery-threshold-value]", count: 0
    assert_select "[data-free-delivery-cart-subtotal-value]", count: 0
    assert_select "[data-free-delivery-opening-total-value]", count: 0
  end

  # With an empty cart the hint states the rule rather than counting down,
  # because there is no spend to count down from. The client repeats this
  # wording in that state, so the two must not drift apart.
  test "the server-rendered hint states the rule rather than a countdown" do
    get product_path(@product)

    assert_select "[data-test='free-delivery-hint']", text: /over £100/i
    assert_select "[data-test='free-delivery-hint']", text: /\Aadd /i, count: 0
  end

  # The nudge reads the cart, and the cart changes on the server, so it refreshes
  # the same way every other cart-dependent fragment does: a turbo_stream replace
  # on the mutation response. No client-side arithmetic to drift out of step.
  test "adding to the cart streams a replacement nudge" do
    lid = products(:flat_lid_8oz)

    post cart_cart_items_path,
         params: { cart_item: { sku: lid.sku, quantity: 1 } },
         as: :turbo_stream

    assert_turbo_stream action: :replace, target: "free_delivery_hint"
  end

  test "the streamed nudge counts down from the new cart total" do
    lid = products(:flat_lid_8oz)

    post cart_cart_items_path,
         params: { cart_item: { sku: lid.sku, quantity: 1 } },
         as: :turbo_stream

    expected = number_to_currency(100 - lid.price)
    assert_select_turbo_stream_body do
      assert_select "[data-test='free-delivery-hint']", text: /Add #{Regexp.escape(expected)} more/
    end
  end

  # Removing the last item has to walk the message back to the rule, or a buyer
  # who empties their cart keeps reading a countdown from a total they no
  # longer have.
  test "emptying the cart streams the nudge back to the rule" do
    lid = products(:flat_lid_8oz)
    post cart_cart_items_path, params: { cart_item: { sku: lid.sku, quantity: 1 } }
    item = Cart.find(session[:cart_id]).cart_items.first

    delete cart_cart_item_path(item), as: :turbo_stream

    assert_turbo_stream action: :replace, target: "free_delivery_hint"
    assert_select_turbo_stream_body do
      assert_select "[data-test='free-delivery-hint']", text: /over £100/i
    end
  end

  # The tint and the sentence are two renderings of one rule, so they must not
  # be able to disagree. A band tinted "not yet" beside the words "qualifies"
  # reads as a broken page.
  test "the band's tint agrees with its sentence" do
    lid = products(:flat_lid_8oz)
    post cart_cart_items_path, params: { cart_item: { sku: lid.sku, quantity: 10 } }

    get product_path(@product)

    assert_select "[data-test='free-delivery-hint'][data-qualified='true']", text: /qualifies/i
  end

  # A buyer arriving with a full cart must see the state their cart is actually
  # in, not the empty-cart rule waiting for an interaction to correct it.
  test "the hint reflects what is already in the cart on first render" do
    lid = products(:flat_lid_8oz)
    post cart_cart_items_path, params: { cart_item: { sku: lid.sku, quantity: 2 } }

    get product_path(@product)

    expected = number_to_currency(100 - lid.price * 2)
    assert_select "[data-test='free-delivery-hint']", text: /Add #{Regexp.escape(expected)} more/
  end
end
