require "test_helper"

# Checkout refuses an order with no delivery destination it can price (shipping
# is baked into the Stripe line items before Stripe collects the address). Every
# surface offering checkout must therefore route the customer to the postcode
# field rather than into that refusal.
#
# The cart page and the drawer both carry the postcode field, so both disable
# their own button and say why. The navbar dropdown has no field, so it still
# routes to the cart to collect one. It appears on every product, collection and
# price-list page, and a guest who adds to cart and clicks Checkout there without
# ever opening /cart is the main first-time conversion path, so it must not
# dead-end.
class CheckoutEntryPointsTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:one)
  end

  test "the drawer disables checkout when no postcode is known" do
    # The drawer used to link to /cart here, from when it had no field of its
    # own. Now that it does, sending the customer to another page to type
    # something they could type right there is a detour, and a link styled as a
    # button reads as though checkout is available when it is not.
    add_to_cart

    get product_path(@product)

    assert_response :success
    assert_select "#drawer_cart_content [data-test=checkout-needs-postcode]", count: 0
    assert_select "#drawer_cart_content button[type=submit][disabled]", count: 1
    assert_select "#drawer_cart_content [data-test=drawer-checkout-blocked-note]", count: 1
  end

  test "the drawer posts to checkout once a postcode is known" do
    add_to_cart
    set_delivery_postcode("WD18 9SB")

    get product_path(@product)

    assert_select "[data-test=checkout-needs-postcode]", count: 0
    assert_select "form[action=?][method=post]", checkout_path
  end

  test "the navbar cart dropdown routes to the cart when no postcode is known" do
    add_to_cart

    get root_path

    assert_select "[data-test=checkout-needs-postcode]"
  end

  test "a guest checking out from the drawer is never bounced by the guard" do
    # The original regression: the drawer POSTed straight to checkout with no
    # postcode, so the guard redirected the customer back to a cart they had
    # never seen. The drawer now refuses to offer the POST at all and carries
    # the field that resolves it, so the customer never leaves the page.
    add_to_cart

    get product_path(@product)

    assert_select "#drawer_cart_content button[type=submit][disabled]", count: 1
    assert_select "#drawer_cart_content input[name=delivery_postcode]", count: 1
    assert_select "#drawer_cart_content form[action=?]", checkout_path, count: 0
  end

  test "the drawer and the cart page give the same reason in the same words" do
    # These two surfaces are deliberately identical when there is no
    # destination, so the sentence has one home. Two copies would drift, and a
    # customer moving between them would be told the same thing twice, slightly
    # differently, for no reason.
    add_to_cart

    get product_path(@product)
    drawer = css_select("#drawer_cart_content [data-test=drawer-checkout-blocked-note]").first
    assert drawer.present?, "the drawer should say why checkout is unavailable"

    get cart_path
    page = css_select("[data-test=checkout-blocked-note]").first
    assert page.present?, "the cart page should say why checkout is unavailable"

    assert_equal drawer.text.squish, page.text.squish
  end

  test "the navbar dropdown still routes to the cart, having no field of its own" do
    # The dropdown is the one surface that genuinely cannot collect a postcode,
    # so the link stays there. Disabling its button instead would dead-end the
    # main first-time conversion path.
    add_to_cart

    get root_path

    assert_select "#cart_counter [data-test=checkout-needs-postcode]", count: 1
  end

  test "a logged-in customer's default address satisfies the cart page without typing" do
    # Asserted on the cart page, not the drawer. Pages that call
    # allow_unauthenticated_access (products, collections, price list) skip
    # resume_session, so Current.user is nil there and set_current_cart hands
    # back a GUEST cart: a signed-in customer already sees a different cart in
    # the drawer than on the cart page. That divergence predates this work (the
    # navbar badge disagrees with the cart page on master too) and is out of
    # scope here; the drawer correctly routes such a customer to the cart.
    user = users(:one)
    address = user.addresses.default_first.first
    assert address.present?, "fixture user needs a saved address for this test"
    assert ShippingZone.deliverable?(ShippingZone.for(address.postcode))

    sign_in_as(user)
    add_to_cart

    get cart_path

    assert_select "[data-test=checkout-blocked-note]", count: 0
    assert_select "button[type=submit]:not([disabled])", text: /Proceed to Checkout/
  end

  private

  def add_to_cart
    post cart_cart_items_path, params: { cart_item: { sku: @product.sku, quantity: 1 } }
  end

  def set_delivery_postcode(postcode)
    post delivery_postcode_cart_path, params: { delivery_postcode: postcode }
  end

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
