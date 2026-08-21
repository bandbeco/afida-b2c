require "test_helper"

# The free-delivery countdown on the two CART surfaces: the slide-out drawer and
# the cart page's summary column.
#
# Both surfaces render "Shipping: Calculated at checkout" (CartSummary::
# DEFERRED_LABEL), because neither collects a destination. That is honest but it
# is a dead end at the moment the buyer is deciding whether to check out or keep
# shopping: it says nothing about the one lever they control. The PDP tells a
# buyer at £80 to add £20; without these mounts the cart, one click later, tells
# them nothing.
#
# The hint partial is shared with the PDP buy box, so the interesting thing to
# pin here is DOM identity. The drawer is mounted on the PDP too, and the cart
# page carries both its own hint and the drawer's, so all three copies coexist
# in one document. Each therefore needs its own id, and the turbo_stream that
# refreshes one must not be able to blank another.
class CartFreeDeliveryHintTest < ActionDispatch::IntegrationTest
  include ActionView::Helpers::NumberHelper

  # turbo_stream payloads wrap their markup in <template>, which assert_select
  # will not descend into. Unwrap every template into one document so the
  # streamed fragments can be asserted as ordinary markup.
  def assert_select_turbo_stream_body(&block)
    bodies = Nokogiri::HTML5.fragment(response.body)
      .css("turbo-stream template").map(&:inner_html).join
    assert_select Nokogiri::HTML5("<body>#{bodies}</body>"), "body", &block
  end

  def add_lid(quantity)
    lid = products(:flat_lid_8oz)
    post cart_cart_items_path, params: { cart_item: { sku: lid.sku, quantity: quantity } }
    lid
  end

  # --- the drawer -------------------------------------------------------

  # Asserted from the homepage, not /cart: the cart page mounts no drawer (a
  # slide-out cart on the cart page would be a second copy of the page).
  test "the drawer counts down to free delivery" do
    lid = add_lid(2)

    get root_path

    expected = number_to_currency(100 - lid.price * 2)
    assert_select "#drawer_cart_content [data-test='free-delivery-hint']",
      text: /Add #{Regexp.escape(expected)} more/
  end

  # The drawer opens on every add-to-cart, so it is the surface the nudge is
  # seen on most, and the one where the buyer is most able to act on it.
  test "adding to the cart streams a drawer carrying the countdown" do
    lid = products(:flat_lid_8oz)

    post cart_cart_items_path,
         params: { cart_item: { sku: lid.sku, quantity: 1 } },
         as: :turbo_stream

    expected = number_to_currency(100 - lid.price)
    assert_select_turbo_stream_body do
      assert_select "#drawer_cart_content [data-test='free-delivery-hint']",
        text: /Add #{Regexp.escape(expected)} more/
    end
  end

  # Sitting directly above a "Calculated at checkout" shipping line, the
  # qualified state does real work: it pre-empts the fear that delivery is a
  # cost still waiting at payment.
  test "a qualifying cart is told so in the drawer" do
    add_lid(10)

    get root_path

    assert_select "#drawer_cart_content [data-test='free-delivery-hint'][data-qualified='true']",
      text: /qualifies/i
  end

  # An empty drawer has no spend to count down from, and the plain rule would be
  # the only line of copy in a panel that already says "Your cart is empty".
  test "an empty drawer shows no hint at all" do
    get root_path

    assert_select "#drawer_cart_content [data-test='free-delivery-hint']", count: 0
  end

  # --- the cart page ----------------------------------------------------

  test "the cart page counts down to free delivery" do
    lid = add_lid(2)

    get cart_path

    expected = number_to_currency(100 - lid.price * 2)
    assert_select "#cart [data-test='free-delivery-hint']",
      text: /Add #{Regexp.escape(expected)} more/
  end

  test "an empty cart page shows no hint at all" do
    get cart_path

    assert_select "#cart [data-test='free-delivery-hint']", count: 0
  end

  # A quantity change reprices the cart, so the countdown has to move with it or
  # the cart page states a gap the buyer has already closed. Asserted against
  # the cart page's OWN id: the response also carries the drawer's copy, and
  # matching that one would let this pass while the visible band went stale.
  test "changing quantity refreshes the cart page countdown" do
    lid = add_lid(2)
    item = Cart.find(session[:cart_id]).cart_items.first

    patch cart_cart_item_path(item),
          params: { cart_item: { quantity: 3 } },
          as: :turbo_stream

    assert_turbo_stream action: :replace, target: "cart_free_delivery_hint"

    expected = number_to_currency(100 - lid.price * 3)
    assert_select_turbo_stream_body do
      assert_select "#cart_free_delivery_hint[data-test='free-delivery-hint']",
        text: /Add #{Regexp.escape(expected)} more/
    end
  end

  # Removing an item is the other way the cart page's total moves. Its stream
  # re-renders the whole #cart frame, which carries the band along with it, so
  # this needs no stream of its own; pinned so that stays true.
  test "removing an item refreshes the cart page countdown" do
    lid = add_lid(3)
    cart = Cart.find(session[:cart_id])
    keep = cart.cart_items.first
    other = products(:single_wall_8oz_white)
    post cart_cart_items_path, params: { cart_item: { sku: other.sku, quantity: 1 } }
    extra = Cart.find(session[:cart_id]).cart_items.find_by(product: other)

    delete cart_cart_item_path(extra), as: :turbo_stream

    expected = number_to_currency(100 - lid.price * 3)
    assert_select_turbo_stream_body do
      assert_select "#cart_free_delivery_hint[data-test='free-delivery-hint']",
        text: /Add #{Regexp.escape(expected)} more/
    end
    assert keep.persisted?
  end

  # --- the three copies must not collide --------------------------------

  # The cart page mounts no drawer, so it carries exactly one hint. Pinned
  # because the obvious way to add the cart-page mount (dropping it into the
  # summary partial the drawer also renders) would silently produce two.
  test "the cart page carries exactly one hint, with an id of its own" do
    add_lid(2)

    get cart_path

    assert_select "[data-test='free-delivery-hint']", count: 1
    assert_select "#cart_free_delivery_hint[data-test='free-delivery-hint']"
  end

  test "the PDP's buy-box hint and its drawer hint have distinct ids" do
    add_lid(2)

    get product_path(products(:single_wall_8oz_white))

    assert_select "[data-test='free-delivery-hint']", count: 2
    ids = css_select("[data-test='free-delivery-hint']").map { |node| node["id"] }
    assert_equal ids.uniq, ids, "two hints share a DOM id: #{ids.inspect}"
  end

  # The buy box's hint keeps the original id, because the streams that target it
  # by name are already deployed and the PDP tests pin that contract.
  test "the buy box keeps the free_delivery_hint id" do
    get product_path(products(:single_wall_8oz_white))

    assert_select "#free_delivery_hint[data-test='free-delivery-hint']"
  end

  # The drawer is replaced wholesale by the same streams that replace the buy
  # box's hint. If the drawer's copy answered to free_delivery_hint too, one
  # stream would overwrite the other's target inside a document that had just
  # received it.
  test "the drawer's hint does not answer to the buy box's id" do
    add_lid(2)

    get cart_path

    assert_select "#drawer_cart_content #free_delivery_hint", count: 0
  end
end
