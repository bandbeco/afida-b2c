require "test_helper"

# Checkout refuses an order with no delivery destination it can price (shipping
# is baked into the Stripe line items before Stripe collects the address). Every
# surface offering checkout must therefore route the customer to the postcode
# field rather than into that refusal.
#
# The cart page has the field and disables its own button; the drawer and the
# navbar dropdown are compact surfaces with no room for it, and they appear on
# every product, collection and price-list page. A guest who adds to cart and
# clicks Checkout there without ever opening /cart is the main first-time
# conversion path, so it must not dead-end.
class CheckoutEntryPointsTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:one)
  end

  test "the drawer offers checkout as a link to the cart when no postcode is known" do
    add_to_cart

    get product_path(@product)

    assert_response :success
    assert_select "[data-test=checkout-needs-postcode]"
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
    # The regression: the drawer POSTed straight to checkout with no postcode,
    # so the guard redirected the customer back to a cart they had never seen.
    # Following the drawer's own affordance must land them on the cart with the
    # postcode field, not on an error.
    add_to_cart

    get product_path(@product)
    assert_select "[data-test=checkout-needs-postcode]"

    get cart_path

    assert_response :success
    assert_nil flash[:alert]
    assert_select "input[name=delivery_postcode]"
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
