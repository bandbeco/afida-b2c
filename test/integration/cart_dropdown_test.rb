require "test_helper"

# The navbar cart icon is a plain link to /cart, not a dropdown.
#
# It used to open a <details> panel repeating the item count, the subtotal, a
# "View cart" link and a Checkout control. That panel was the one checkout
# surface that could not collect a delivery postcode, so its Checkout control
# had to link to /cart anyway: two clicks to reach the page one click already
# reached, and a third copy of totals that the drawer and the cart page state
# more fully.
class CartLinkTest < ActionDispatch::IntegrationTest
  test "the cart icon links straight to the cart" do
    get root_url

    assert_response :success
    assert_select "#cart_counter a[href=?]", cart_path
  end

  test "the cart icon opens no dropdown" do
    post cart_cart_items_path, params: { cart_item: { sku: products(:one).sku, quantity: 1 } }

    get root_url

    assert_response :success
    assert_select "#cart_counter details", count: 0
    assert_select "#cart_counter [data-controller='click-outside']", count: 0
  end

  test "the cart icon offers no checkout control of its own" do
    # Checkout is offered where a postcode can be given: the cart page and the
    # drawer. A third entry point here would be a fourth thing to keep in step
    # with the delivery guard, for no reach the cart link does not already have.
    Rails.application.config.x.gtm_container_id = "GTM-TEST123"
    post cart_cart_items_path, params: { cart_item: { sku: products(:one).sku, quantity: 1 } }
    post delivery_postcode_cart_path, params: { delivery_postcode: "WD18 9SB" }

    get root_url

    assert_response :success
    assert_select "#cart_counter form[action=?]", checkout_path, count: 0
    assert_select "#cart_counter button[type=submit]", count: 0
  ensure
    Rails.application.config.x.gtm_container_id = nil
  end

  test "the cart icon still reports how many items are in the cart" do
    # The badge is the only thing the dropdown showed that the icon keeps: it is
    # visible without a click, which is the whole reason it earns navbar space.
    post cart_cart_items_path, params: { cart_item: { sku: products(:one).sku, quantity: 2 } }

    get root_url

    assert_response :success
    assert_select "#cart_counter .badge", text: "1"
  end
end
