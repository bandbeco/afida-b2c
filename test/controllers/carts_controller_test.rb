require "test_helper"

class CartsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product_variant = products(:one)
  end

  # GET /cart
  test "should show cart for guest" do
    get cart_url
    assert_response :success
    # A cart should be created automatically
    assert_not_nil session[:cart_id]
  end

  test "should show cart page even when empty" do
    get cart_url
    assert_response :success
  end

  test "cart page is accessible to authenticated users" do
    user = users(:one)
    sign_in_as(user)

    get cart_url
    assert_response :success
  end

  test "should create cart automatically on first visit" do
    assert_difference("Cart.count", 1) do
      get cart_url
    end
    assert_response :success
  end

  test "should use existing cart from session" do
    # First request creates cart
    get cart_url
    cart_id = session[:cart_id]

    # Second request should reuse same cart
    assert_no_difference("Cart.count") do
      get cart_url
    end
    assert_equal cart_id, session[:cart_id]
  end

  test "authenticated user gets their own cart" do
    user = users(:one)
    sign_in_as(user)

    get cart_url
    cart = Cart.find_by(user: user)
    assert_not_nil cart
    assert_response :success
  end

  # Cart item display tests - products show category name
  test "cart displays product with category name" do
    # First get cart to create it
    get cart_url
    cart = Cart.find(session[:cart_id])

    # Add a product
    product = products(:single_wall_8oz_white)
    cart.cart_items.create!(product: product, quantity: 1, price: product.price)

    get cart_url
    assert_response :success
    # Products show category name
    assert_match product.category.name, response.body
  end

  # Cart preview shipping line: matches what Stripe charges (see Cart#shipping_amount)
  test "cart page shows the charged shipping amount below the free-shipping threshold" do
    get cart_url
    cart = Cart.find(session[:cart_id])
    # products(:one) is £10/pack; one pack keeps the cart under the £100 threshold.
    cart.cart_items.create!(product: products(:one), quantity: 1, price: products(:one).price)
    # A destination is required before any price is quoted, so enter one the way
    # a customer does. Without it the line defers to the postcode field.
    post delivery_postcode_cart_url, params: { delivery_postcode: "WD18 9SB" }

    get cart_url
    assert_response :success
    assert_select "#shipping", text: /#{Regexp.escape(Shipping.formatted_standard_cost)}/
  end

  test "cart page shows Free shipping at or above the free-shipping threshold" do
    get cart_url
    cart = Cart.find(session[:cart_id])
    over_threshold = Product.create!(
      category: categories(:cups),
      name: "Bulk pack",
      sku: "TEST-CART-OVER-THRESHOLD",
      price: Shipping::FREE_SHIPPING_THRESHOLD + 1,
      pac_size: 1,
      active: true
    )
    cart.cart_items.create!(product: over_threshold, quantity: 1, price: over_threshold.price)
    # Free delivery is a MAINLAND promise, so it only appears once the customer
    # has told us the order is going to the mainland.
    post delivery_postcode_cart_url, params: { delivery_postcode: "WD18 9SB" }

    get cart_url
    assert_response :success
    assert_select "#shipping", text: /Free/
  end

  # Cart summary discount line: shown only when a coupon is active in the session
  test "cart page shows the discount line when a welcome code is in the session" do
    get cart_url
    cart = Cart.find(session[:cart_id])
    cart.cart_items.create!(product: products(:one), quantity: 1, price: products(:one).price)
    # Claim the welcome discount, which stores the code in the session.
    post email_subscriptions_path, params: { email: "cart-discount-test@example.com" }

    get cart_url
    assert_response :success
    # The discount line is rendered inside the summary, with its negative amount.
    assert_select "#cart_summary", text: /Discount/
    assert_select "#discount_amount", text: /-/
  end

  test "cart page omits the discount line when no code is in the session" do
    get cart_url
    cart = Cart.find(session[:cart_id])
    cart.cart_items.create!(product: products(:one), quantity: 1, price: products(:one).price)

    get cart_url
    assert_response :success
    # CartSummary omits the discount line entirely when no discount is active.
    assert_select "#discount_amount", count: 0
  end

  # GET /cart/resume?token=... (cross-device abandoned-cart recovery)
  test "resume re-binds the guest session to the cart in a valid token and redirects to cart" do
    guest_cart = Cart.create!
    guest_cart.cart_items.create!(product: products(:single_wall_8oz_white), quantity: 1, price: 10)

    get resume_cart_url(token: guest_cart.signed_recovery_token)

    assert_redirected_to cart_path
    assert_equal guest_cart.id, session[:cart_id]
  end

  test "resume overrides an existing guest session cart with the one in the token" do
    # The realistic cross-device case: the visitor lands first (auto-created
    # empty cart in their session), then clicks the recovery link for a different,
    # earlier cart. Resume should re-bind the session to the token's cart.
    get cart_url
    other_cart_id = session[:cart_id]
    recovered_cart = Cart.create!
    recovered_cart.cart_items.create!(product: products(:single_wall_8oz_white), quantity: 1, price: 10)

    get resume_cart_url(token: recovered_cart.signed_recovery_token)

    assert_redirected_to cart_path
    assert_equal recovered_cart.id, session[:cart_id]
    assert_not_equal other_cart_id, session[:cart_id]
  end

  test "resume redirects to cart and leaves the session untouched for an invalid token" do
    get cart_url # establishes a guest cart in the session
    original_cart_id = session[:cart_id]

    get resume_cart_url(token: "not-a-real-token")

    assert_redirected_to cart_path
    assert_equal original_cart_id, session[:cart_id]
  end

  test "resume does not bind a user-owned cart into a guest session (no hijack)" do
    get cart_url
    original_cart_id = session[:cart_id]
    user_cart = Cart.create!(user: users(:one))

    get resume_cart_url(token: user_cart.signed_recovery_token)

    assert_redirected_to cart_path
    assert_equal original_cart_id, session[:cart_id]
    assert_not_equal user_cart.id, session[:cart_id]
  end

  # POST /cart/delivery_postcode — the cart-page "calculate delivery" field.
  # The postcode is held in the session so every cart surface prices the same
  # destination, and so the checkout POST already knows where the order is going
  # (Stripe only collects the address on the screen after the price is fixed).

  test "delivery_postcode stores a valid postcode in the session" do
    get cart_url

    post delivery_postcode_cart_url, params: { delivery_postcode: "BT1 6EE" }

    assert_redirected_to cart_path
    assert_equal "BT1 6EE", session[:delivery_postcode]
  end

  test "delivery_postcode prices the cart for the entered destination" do
    get cart_url
    post cart_cart_items_path, params: { cart_item: { sku: @product_variant.sku, quantity: 1 } }

    post delivery_postcode_cart_url, params: { delivery_postcode: "BT1 6EE" }
    follow_redirect!

    assert_response :success
    # The surcharged rate is shown on the cart, not the mainland £6.99, so the
    # customer sees the real cost before reaching Stripe.
    assert_select "#shipping", text: /#{Regexp.escape(ActiveSupport::NumberHelper.number_to_currency(Shipping.cost_for_zone_in_pounds(:northern_ireland), unit: "£"))}/
    assert_select "[data-test=delivery-zone-note]", text: /Northern Ireland/
  end

  # --- the postcode field in the drawer ---
  # The drawer is a checkout entry point in its own right, so it carries the
  # calculator too: sending a customer to /cart to type a postcode drops them out
  # of the flow they were in, and the drawer is the surface that survives if the
  # cart page is ever retired.

  test "the drawer carries the delivery postcode field" do
    get cart_url
    post cart_cart_items_path, params: { cart_item: { sku: @product_variant.sku, quantity: 1 } }

    get product_url(products(:one))

    assert_select "#drawer_cart_content form[action=?]", delivery_postcode_cart_path
  end

  test "the drawer omits the non-mainland explainer" do
    # The drawer is a narrow column where the field, the totals and the checkout
    # button all have to fit; the explainer pushed them down for a case most
    # customers aren't in. Entering a postcode still reports the zone and the
    # transit time, which is the part that applies to them.
    get cart_url
    post cart_cart_items_path, params: { cart_item: { sku: @product_variant.sku, quantity: 1 } }

    get product_url(products(:one))

    assert_select "#drawer_cart_content form[action=?]", delivery_postcode_cart_path
    assert_select "#drawer_cart_content [data-test=non-mainland-note]", count: 0
  end

  test "the cart page keeps the non-mainland explainer" do
    # It has room for it, and it's the page a customer lands on from the
    # drawer's needs-a-postcode link, so the explanation stays reachable.
    get cart_url
    post cart_cart_items_path, params: { cart_item: { sku: @product_variant.sku, quantity: 1 } }

    get cart_url

    assert_select "[data-test=non-mainland-note]"
  end

  test "a turbo stream submission updates the drawer in place" do
    # A redirect would navigate away and close the drawer, losing the customer's
    # place. The cart mutations already answer with a drawer replacement; this
    # follows the same contract.
    get cart_url
    post cart_cart_items_path, params: { cart_item: { sku: @product_variant.sku, quantity: 1 } }

    post delivery_postcode_cart_url,
         params: { delivery_postcode: "BT1 6EE" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=replace][target=drawer_cart_content]" do
      assert_select "[data-test=delivery-zone-note]", text: /Northern Ireland/
    end
  end

  test "a turbo stream submission repricing the drawer also refreshes the cart summary" do
    # The cart page mounts the same field, so a Turbo submission from there must
    # refresh its summary too, not only the drawer's.
    get cart_url
    post cart_cart_items_path, params: { cart_item: { sku: @product_variant.sku, quantity: 1 } }

    post delivery_postcode_cart_url,
         params: { delivery_postcode: "BT1 6EE" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_select "turbo-stream[action=replace][target=cart_summary]"
  end

  test "clearing the postcode reprices the re-rendered surfaces, not just the session" do
    # The before_action can only SET the cart's postcode, never clear it, so
    # without an explicit reprice the drawer would keep quoting the destination
    # the customer just removed.
    get cart_url
    post cart_cart_items_path, params: { cart_item: { sku: @product_variant.sku, quantity: 1 } }
    post delivery_postcode_cart_url, params: { delivery_postcode: "BT1 6EE" }

    post delivery_postcode_cart_url,
         params: { delivery_postcode: "" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_select "turbo-stream[action=replace][target=drawer_cart_content]" do
      assert_select "[data-test=delivery-zone-note]", count: 0,
                    text: /Northern Ireland/
    end
  end

  test "a non-turbo submission still redirects to the cart" do
    # Without JS the form is a plain POST, so it must keep working.
    get cart_url

    post delivery_postcode_cart_url, params: { delivery_postcode: "BT1 6EE" }

    assert_redirected_to cart_path
  end

  test "a rejected turbo stream submission reports the error without navigating" do
    get cart_url
    post cart_cart_items_path, params: { cart_item: { sku: @product_variant.sku, quantity: 1 } }

    post delivery_postcode_cart_url,
         params: { delivery_postcode: "JE2 3AB" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_select "turbo-stream[action=replace][target=drawer_cart_content]" do
      # Shown inline in the drawer, not only in the flash: a Turbo submission
      # never re-renders the layout that hosts the flash, so a customer working
      # in the drawer would otherwise see nothing happen at all.
      assert_select "[data-test=delivery-postcode-error]", text: /don't deliver/i
    end
  end

  test "delivery_postcode rejects an unparseable postcode without storing it" do
    get cart_url

    post delivery_postcode_cart_url, params: { delivery_postcode: "not a postcode" }

    assert_redirected_to cart_path
    assert_nil session[:delivery_postcode]
    assert flash[:alert].present?, "expected an explanation the postcode was not recognised"
  end

  test "delivery_postcode discards the previous postcode when a new one is rejected" do
    # Otherwise the customer is told their postcode wasn't recognised while the
    # cart quietly keeps quoting (and checkout keeps pricing) the OLD one, which
    # the field still displays: they'd be shown a price for a destination they
    # just replaced.
    get cart_url
    post delivery_postcode_cart_url, params: { delivery_postcode: "BT1 6EE" }
    assert_equal "BT1 6EE", session[:delivery_postcode]

    post delivery_postcode_cart_url, params: { delivery_postcode: "not a postcode" }

    assert_nil session[:delivery_postcode], "a rejected submission must not leave the old destination priced"
  end

  test "delivery_postcode explains that we do not ship to the Channel Islands" do
    # "We didn't recognise that postcode" would be untrue and unhelpful: JE2 3AB
    # is a perfectly valid postcode, we simply do not deliver there.
    get cart_url

    post delivery_postcode_cart_url, params: { delivery_postcode: "JE2 3AB" }

    assert_nil session[:delivery_postcode]
    assert_match(/don't deliver/i, flash[:alert],
                 "expected to be told we don't ship there, not that the postcode was unrecognised")
  end

  test "delivery_postcode clears a stored postcode when submitted blank" do
    get cart_url
    post delivery_postcode_cart_url, params: { delivery_postcode: "BT1 6EE" }

    post delivery_postcode_cart_url, params: { delivery_postcode: "" }

    assert_nil session[:delivery_postcode]
  end

  test "delivery_postcode accepts a messily formatted postcode" do
    get cart_url

    post delivery_postcode_cart_url, params: { delivery_postcode: "  iv51 9yb " }

    assert_equal :highlands, ShippingZone.for(session[:delivery_postcode])
  end

  # Checkout refuses an order with no destination, so the cart must not offer a
  # button that would bounce the customer straight back to the cart.

  test "checkout is disabled until a delivery postcode is given" do
    get cart_url
    post cart_cart_items_path, params: { cart_item: { sku: @product_variant.sku, quantity: 1 } }

    get cart_url

    assert_select "button[type=submit][disabled]", text: /Proceed to Checkout/
    assert_select "[data-test=checkout-blocked-note]"
  end

  test "checkout is enabled once a delivery postcode is given" do
    get cart_url
    post cart_cart_items_path, params: { cart_item: { sku: @product_variant.sku, quantity: 1 } }
    post delivery_postcode_cart_url, params: { delivery_postcode: "WD18 9SB" }

    get cart_url

    assert_select "button[type=submit]:not([disabled])", text: /Proceed to Checkout/
    assert_select "[data-test=checkout-blocked-note]", count: 0
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
