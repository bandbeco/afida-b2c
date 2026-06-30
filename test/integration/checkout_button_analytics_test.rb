require "test_helper"

# Phase 1 of the mobile-conversion work: every checkout entry point must fire the
# GA4 begin_checkout dataLayer event, not just the cart page. The cart drawer
# (the primary mobile path, since it auto-opens on add-to-cart) and the header
# dropdown previously rendered plain button_to controls with no analytics wiring,
# so mobile checkout intent was under-measured in GA4/Ads.
#
# No JS test harness exists, so we assert on the rendered HTML attributes that wire
# the existing `analytics` Stimulus controller (the same approach as cart_dropdown_test).
class CheckoutButtonAnalyticsTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:one)
    # Seed a cart into the session by adding an item (mirrors cart_items_controller_test).
    post cart_cart_items_path, params: { cart_item: { sku: @product.sku, quantity: 1 } }
  end

  test "cart drawer checkout button is an analytics-wired begin_checkout form" do
    get root_url

    assert_response :success
    assert_select "#drawer_cart_content " \
                  "form[data-controller='analytics']" \
                  "[data-action='submit->analytics#beginCheckout']" \
                  "[data-analytics-cart-value-value]" \
                  "[data-analytics-cart-items-value]" do
      assert_select "button[type=submit]", text: "Proceed to Checkout"
    end
  end

  test "header dropdown checkout button is an analytics-wired begin_checkout form" do
    get root_url

    assert_response :success
    assert_select "#cart_counter " \
                  "form[data-controller='analytics']" \
                  "[data-action='submit->analytics#beginCheckout']" \
                  "[data-analytics-cart-value-value]" \
                  "[data-analytics-cart-items-value]" do
      assert_select "button[type=submit]", text: "Checkout"
    end
  end

  test "cart-items data value is valid JSON describing the cart contents" do
    get root_url

    assert_response :success
    form = css_select("#drawer_cart_content form[data-controller='analytics']").first
    refute_nil form, "expected the drawer to render an analytics-wired checkout form"

    items = JSON.parse(form["data-analytics-cart-items-value"])
    assert_kind_of Array, items
    assert_equal 1, items.length
    assert_equal @product.sku, items.first["item_id"]
  end

  test "empty cart renders no analytics-wired checkout form" do
    # Empty the cart that the setup seeded by removing its only line item, then re-render.
    item = CartItem.last
    delete cart_cart_item_path(item)
    get root_url

    assert_response :success
    assert_select "#drawer_cart_content form[data-controller='analytics']", count: 0
    assert_select "#cart_counter form[data-controller='analytics']", count: 0
  end

  test "add-to-cart turbo stream re-renders the drawer with the analytics-wired form" do
    # A turbo_stream.replace of the drawer must carry the same wiring as a full-page
    # render, since the drawer never reaches the user any other way after an add.
    post cart_cart_items_path,
         params: { cart_item: { sku: @product.sku, quantity: 1 } },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match(/turbo-stream action="replace" target="drawer_cart_content"/, @response.body)
    assert_match(/data-controller="analytics"/, @response.body)
    assert_match(/submit-&gt;analytics#beginCheckout|submit->analytics#beginCheckout/, @response.body)
  end
end
