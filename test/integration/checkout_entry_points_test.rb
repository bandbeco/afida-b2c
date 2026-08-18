require "test_helper"

# The cart surfaces no longer collect or require a delivery destination:
# shipping is priced live on the checkout page from the address the customer
# types there, so every surface offering checkout does so whenever the cart has
# items. These pin that no gate creeps back in.
#
# The navbar cart icon is deliberately not an entry point. It was a dropdown
# offering Checkout of its own, and is now a plain link to /cart.
class CheckoutEntryPointsTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:one)
  end

  test "the drawer posts to checkout as soon as the cart has items" do
    add_to_cart

    get product_path(@product)

    assert_response :success
    assert_select "#drawer_cart_content form[action=?][method=post]", checkout_path
    assert_select "#drawer_cart_content button[type=submit]:not([disabled])", count: 1
    assert_select "#drawer_cart_content [data-test=drawer-checkout-blocked-note]", count: 0
  end

  test "the drawer carries no postcode field" do
    # The calculator went with the cart-side pricing (Phase C of the
    # live-reprice plan): the checkout page owns the destination now.
    add_to_cart

    get product_path(@product)

    assert_select "#drawer_cart_content input[name=delivery_postcode]", count: 0
  end

  test "the navbar cart icon routes to the cart" do
    add_to_cart

    get root_path

    assert_select "#cart_counter a[href=?]", cart_path
  end

  test "an empty cart offers no checkout POST anywhere" do
    get product_path(@product)

    assert_select "form[action=?]", checkout_path, count: 0
  end

  private

  def add_to_cart
    post cart_cart_items_path, params: { cart_item: { sku: @product.sku, quantity: 1 } }
  end
end
