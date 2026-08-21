require "test_helper"

class CartsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product_variant = products(:one)
  end

  # DELETE /cart
  #
  # Emptying the cart is a real button in the UI, and it ran against an @cart
  # that this controller never assigned, so every click 500'd on nil. Every
  # other action here reads Current.cart; so does this one now.
  test "should empty the cart" do
    post cart_cart_items_url, params: { cart_item: { sku: @product_variant.sku, quantity: 2 } }
    cart = Cart.find(session[:cart_id])
    assert_equal 1, cart.cart_items.count

    delete cart_url

    assert_redirected_to root_path
    assert_equal 0, cart.reload.cart_items.count
  end

  # Destroying the record left session[:cart_id] pointing at a deleted row, so
  # the next request had to fall back to building a fresh cart. Emptying the
  # items keeps the visitor's cart identity, and with it any recovery link and
  # applied discount.
  test "emptying the cart keeps the same cart" do
    get cart_url
    cart_id = session[:cart_id]

    delete cart_url

    get cart_url
    assert_equal cart_id, session[:cart_id]
  end

  test "emptying an already empty cart is harmless" do
    get cart_url

    delete cart_url

    assert_redirected_to root_path
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

  # Cart preview shipping line: always deferred. The cart collects no
  # destination any more; shipping is priced live on the checkout page.
  test "cart page defers the shipping line to checkout" do
    get cart_url
    cart = Cart.find(session[:cart_id])
    cart.cart_items.create!(product: products(:one), quantity: 1, price: products(:one).price)

    get cart_url
    assert_response :success
    assert_select "#shipping", text: /Calculated at checkout/
  end

  test "cart page defers shipping even above the free-shipping threshold" do
    # Free delivery is a MAINLAND promise, and the cart no longer knows the
    # destination, so promising "Free" here could understate an off-mainland
    # customer's cost.
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

    get cart_url
    assert_response :success
    assert_select "#shipping", text: /Calculated at checkout/
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

  # --- the drawer shell ---
  # The slide-out panel used to be pasted into every page that mounts a drawer.
  # They drifted: the price-list copy had lost the flex layout the content
  # partial needs, so that one page laid out differently for no reason anyone
  # chose. These pin the single shell, since a stray hand-rolled copy would
  # reintroduce exactly that.

  test "every page mounting the cart drawer renders exactly one shell" do
    pages = [ root_path, shop_path, price_list_path, product_path(products(:one)) ]

    pages.each do |page|
      get page

      assert_response :success, "#{page} should render"
      assert_select "##{'drawer_cart_content'}", count: 1,
                    message: "#{page} should mount exactly one cart drawer"
    end
  end

  test "the drawer panel is wider than a phone column on larger screens" do
    # The panel steps up from w-80 so the totals and the checkout button stop
    # competing for a 320px column. Pinned because the width is what keeps the
    # summary readable.
    get product_path(products(:one))

    assert_select ".drawer-side div.w-80.sm\\:w-96", count: 1
  end

  # The cart no longer knows the destination (shipping is priced live on the
  # checkout page from the address the customer types there), so the button is
  # never gated on one: checkout is offered whenever there is something to buy.

  test "checkout is offered whenever the cart has items" do
    get cart_url
    post cart_cart_items_path, params: { cart_item: { sku: @product_variant.sku, quantity: 1 } }

    get cart_url

    assert_select "button[type=submit]:not([disabled])", text: /Proceed to Checkout/
    assert_select "[data-test=checkout-blocked-note]", count: 0
  end

  # "Don't forget lids" reminder

  test "cart page suggests the default lid for a lidless container" do
    get cart_url
    cart = Cart.find(session[:cart_id])
    cup = products(:branded_cup_8oz) # mapped to flat_lid_8oz (default) + domed_lid_8oz
    cart.cart_items.create!(product: cup, quantity: 1, price: cup.price)

    get cart_url

    assert_response :success
    assert_select "#lid-reminder" do
      assert_select "input[name='cart_item[sku]'][value=?]", products(:flat_lid_8oz).sku
      assert_select "input[name='cart_item[from_cart_page]']"
    end
  end

  test "cart page lid reminder falls back to a 1000-unit pack when the lid has no pac_size" do
    products(:flat_lid_8oz).update!(pac_size: nil)
    get cart_url
    cart = Cart.find(session[:cart_id])
    cup = products(:branded_cup_8oz)
    cart.cart_items.create!(product: cup, quantity: 1, price: cup.price)

    get cart_url

    assert_response :success
    assert_select "#lid-reminder" do
      assert_no_match(/\(0 units\)/, css_select("#lid-reminder").to_s)
      assert_match(/1 pack \(1,000 units\)/, css_select("#lid-reminder").to_s)
      assert_match(/pack of 1,000/, css_select("#lid-reminder").to_s)
    end
  end

  test "cart page shows no lid reminder when a compatible lid is already in the cart" do
    get cart_url
    cart = Cart.find(session[:cart_id])
    cup = products(:branded_cup_8oz)
    lid = products(:domed_lid_8oz)
    cart.cart_items.create!(product: cup, quantity: 1, price: cup.price)
    cart.cart_items.create!(product: lid, quantity: 1, price: lid.price)

    get cart_url

    assert_response :success
    assert_select "#lid-reminder", count: 0
  end

  test "cart page shows no lid reminder for products without compatible lids" do
    get cart_url
    cart = Cart.find(session[:cart_id])
    cart.cart_items.create!(product: products(:one), quantity: 1, price: products(:one).price)

    get cart_url

    assert_response :success
    assert_select "#lid-reminder", count: 0
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
