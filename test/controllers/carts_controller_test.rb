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

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
