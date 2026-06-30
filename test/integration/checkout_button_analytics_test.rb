require "test_helper"

# Phase 1 of the mobile-conversion work: every checkout entry point must fire the
# GA4 begin_checkout dataLayer event, not just the cart page. The cart drawer
# (the primary mobile path, since it auto-opens on add-to-cart) and the header
# dropdown previously rendered plain button_to controls with no analytics wiring,
# so mobile checkout intent was under-measured in GA4/Ads.
#
# No JS test harness exists, so we assert on the rendered HTML attributes that wire
# the existing `analytics` Stimulus controller (the same approach as cart_dropdown_test).
#
# The analytics wiring is gated on gtm_enabled? (analytics_checkout_form_data), so the
# happy-path tests enable GTM; a dedicated test covers the GTM-off case.
class CheckoutButtonAnalyticsTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:one)
    Rails.application.config.x.gtm_container_id = "GTM-TEST123"
    # Seed a cart into the session by adding an item (mirrors cart_items_controller_test).
    post cart_cart_items_path, params: { cart_item: { sku: @product.sku, quantity: 1 } }
  end

  teardown do
    Rails.application.config.x.gtm_container_id = nil
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

  test "checkout button renders without analytics wiring when GTM is disabled" do
    # The begin_checkout event can't fire without GTM, so analytics_checkout_form_data
    # skips the controller/action/values (and the total_amount + cart-items query cost).
    # The checkout form must still render so users can check out.
    Rails.application.config.x.gtm_container_id = nil
    get root_url

    assert_response :success
    assert_select "#drawer_cart_content form[data-controller='analytics']", count: 0
    assert_select "#drawer_cart_content form[action='#{checkout_path}'] button[type=submit]",
                  text: "Proceed to Checkout"
  end

  test "empty cart renders no checkout form at all" do
    # Empty the cart that the setup seeded by removing its only line item, then re-render.
    item = CartItem.last
    delete cart_cart_item_path(item)
    get root_url

    assert_response :success
    assert_select "#drawer_cart_content form[action='#{checkout_path}']", count: 0
    assert_select "#cart_counter form[action='#{checkout_path}']", count: 0
  end

  test "add-to-cart turbo stream re-renders the drawer with the analytics-wired form" do
    # A turbo_stream.replace of the drawer must carry the same wiring as a full-page
    # render, since the drawer never reaches the user any other way after an add.
    post cart_cart_items_path,
         params: { cart_item: { sku: @product.sku, quantity: 1 } },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    # Scope to the DRAWER fragment specifically: the same response also replaces
    # #cart_counter (which carries its own analytics form), so a body-wide match would
    # pass even if the drawer fragment lost the form. Extract the drawer template and
    # assert against it alone.
    drawer = @response.body[/<turbo-stream action="replace" target="drawer_cart_content">.*?<\/turbo-stream>/m]
    refute_nil drawer, "expected a turbo-stream replacing drawer_cart_content"
    assert_match(/data-controller="analytics"/, drawer)
    # Rails' tag builder HTML-entity-encodes attribute values, so submit-> becomes submit-&gt;.
    assert_match(/submit-&gt;analytics#beginCheckout/, drawer)
  end
end
