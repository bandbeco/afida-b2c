require "test_helper"

class CartDropdownTest < ActionDispatch::IntegrationTest
  test "cart dropdown has click-outside controller" do
    get root_url

    assert_response :success
    assert_select "details.dropdown[data-controller='click-outside']"
  end

  test "cart dropdown details element is the click-outside target" do
    get root_url

    assert_response :success
    assert_select "details[data-click-outside-target='details']"
  end

  test "cart dropdown checkout button fires begin_checkout via an analytics-wired form" do
    # With items in the cart, the dropdown's Checkout control must be an analytics
    # form (not a plain button_to) so GA4 begin_checkout fires from the header too.
    post cart_cart_items_path, params: { cart_item: { sku: products(:one).sku, quantity: 1 } }
    get root_url

    assert_response :success
    assert_select "#cart_counter form[data-controller='analytics'] button[type=submit]",
                  text: "Checkout"
  end
end
