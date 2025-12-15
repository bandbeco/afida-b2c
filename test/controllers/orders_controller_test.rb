require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user_one = users(:one)
    @user_two = users(:two)
    @order_one = orders(:one)      # belongs to user_one
    @order_two = orders(:two)      # belongs to user_two
    @guest_order = orders(:guest_order)  # no user association
    @valid_password = "password"
  end

  # Helper to sign in a user
  def sign_in(user)
    post session_url, params: {
      email_address: user.email_address,
      password: @valid_password
    }
  end

  # GET /orders (index)
  test "index requires authentication" do
    get orders_url
    assert_redirected_to new_session_path
  end

  test "index shows only current user's orders" do
    sign_in @user_one
    get orders_url
    assert_response :success
    assert_select "h1", "Your Orders"
  end

  # GET /orders/:id (show) - Authorization tests

  # T012: User viewing own order (allowed)
  test "show displays own order" do
    sign_in @user_one
    get order_url(@order_one)
    assert_response :success
    # Show page now has neutral header (not celebratory)
    assert_select "h1", /Order #/
  end

  # T013: User viewing another user's order (denied)
  test "show redirects when accessing another user's order" do
    sign_in @user_one
    get order_url(@order_two)  # order_two belongs to user_two
    assert_redirected_to root_path
    assert_equal "Order not found", flash[:alert]
  end

  # T014: User viewing guest order (denied - no token or flash)
  test "show redirects when accessing guest order without authorization" do
    sign_in @user_one
    get order_url(@guest_order)  # guest_order has no user
    assert_redirected_to root_path
    assert_equal "Order not found", flash[:alert]
  end

  # Guest access without any credentials should be denied
  test "unauthenticated user cannot view order without token" do
    get order_url(@order_one)
    assert_redirected_to root_path
    assert_equal "Order not found", flash[:alert]
  end

  # Additional authorization tests - verify bidirectional protection
  test "user two cannot view user one's order" do
    sign_in @user_two
    get order_url(@order_one)
    assert_redirected_to root_path
    assert_equal "Order not found", flash[:alert]
  end

  # ============================================
  # Guest checkout access via signed token
  # ============================================

  test "guest can view order with valid signed token" do
    token = @guest_order.signed_access_token
    get order_url(@guest_order, token: token)
    assert_response :success
    # Show page now has neutral header (not celebratory)
    assert_select "h1", /Order #/
  end

  test "guest cannot view order with invalid token" do
    get order_url(@guest_order, token: "invalid_token_here")
    assert_redirected_to root_path
    assert_equal "Order not found", flash[:alert]
  end

  test "guest cannot view order with empty token" do
    get order_url(@guest_order, token: "")
    assert_redirected_to root_path
    assert_equal "Order not found", flash[:alert]
  end

  test "guest cannot view order with tampered token" do
    # Generate a token using different data (old style token won't work)
    tampered_token = Digest::SHA256.hexdigest("999-fake_session-#{Rails.application.secret_key_base}")
    get order_url(@guest_order, token: tampered_token)
    assert_redirected_to root_path
    assert_equal "Order not found", flash[:alert]
  end

  test "token for one order cannot access another order" do
    # Get valid token for guest_order but try to access order_one
    token = @guest_order.signed_access_token
    get order_url(@order_one, token: token)
    assert_redirected_to root_path
    assert_equal "Order not found", flash[:alert]
  end

  # ============================================
  # Session-based access (immediately after checkout)
  # Note: Full session-based access is tested in system tests
  # as integration tests can't easily manipulate sessions
  # ============================================

  # ============================================
  # Owner always has access regardless of token
  # ============================================

  test "order owner can view order without token" do
    sign_in @user_one
    get order_url(@order_one)
    assert_response :success
  end

  test "order owner can view order with invalid token" do
    sign_in @user_one
    get order_url(@order_one, token: "wrong_token")
    assert_response :success
  end

  test "order owner can view order with wrong token" do
    sign_in @user_one
    # Use guest order's token on user's order
    wrong_token = @guest_order.signed_access_token
    get order_url(@order_one, token: wrong_token)
    assert_response :success
  end

  # ============================================
  # Confirmation page tests
  # ============================================

  test "confirmation page accessible to order owner" do
    sign_in @user_one
    get confirmation_order_url(@order_one)
    assert_response :success
    assert_select "h1", "Thank You for Your Order!"
  end

  test "confirmation page accessible with signed token" do
    token = @guest_order.signed_access_token
    get confirmation_order_url(@guest_order, token: token)
    assert_response :success
    assert_select "h1", "Thank You for Your Order!"
  end

  test "confirmation page fires GA4 only once" do
    sign_in @user_one
    assert_nil @order_one.ga4_purchase_tracked_at

    # First visit should track GA4
    get confirmation_order_url(@order_one)
    assert_response :success
    @order_one.reload
    assert_not_nil @order_one.ga4_purchase_tracked_at
    first_tracked_at = @order_one.ga4_purchase_tracked_at

    # Second visit should NOT re-track (atomic update)
    get confirmation_order_url(@order_one)
    assert_response :success
    @order_one.reload
    assert_equal first_tracked_at, @order_one.ga4_purchase_tracked_at
  end

  test "confirmation page denied without authorization" do
    get confirmation_order_url(@guest_order)
    assert_redirected_to root_path
    assert_equal "Order not found", flash[:alert]
  end

  # ============================================
  # Reorder action tests
  # ============================================

  test "reorder requires authentication" do
    post reorder_order_url(@order_one)
    assert_redirected_to new_session_path
  end

  test "reorder redirects to cart on success" do
    sign_in @user_one

    # Create an order item that can be reordered
    active_variant = ProductVariant.create!(
      product: products(:one),
      name: "Reorderable Product",
      sku: "REORDER-CTRL-1",
      price: 16.00,
      active: true
    )
    @order_one.order_items.create!(
      product_variant: active_variant,
      product: active_variant.product,
      product_name: active_variant.name,
      product_sku: active_variant.sku,
      price: active_variant.price,
      quantity: 2,
      line_total: active_variant.price * 2
    )

    post reorder_order_url(@order_one)

    assert_redirected_to cart_url
    assert flash[:notice].present?
    assert flash[:notice].include?("added")
  end

  test "reorder shows success message with added count" do
    sign_in @user_one

    # Clear fixture items for accurate count test
    @order_one.order_items.destroy_all

    active_variant = ProductVariant.create!(
      product: products(:one),
      name: "Reorderable Success",
      sku: "REORDER-SUCCESS-1",
      price: 16.00,
      active: true
    )
    @order_one.order_items.create!(
      product_variant: active_variant,
      product: active_variant.product,
      product_name: active_variant.name,
      product_sku: active_variant.sku,
      price: active_variant.price,
      quantity: 1,
      line_total: active_variant.price
    )

    post reorder_order_url(@order_one)

    assert_redirected_to cart_url
    assert_match(/1 item/, flash[:notice])
  end

  test "reorder shows partial success with unavailable items" do
    sign_in @user_one

    active_variant = ProductVariant.create!(
      product: products(:one),
      name: "Active Variant",
      sku: "REORDER-ACTIVE-CTRL-1",
      price: 16.00,
      active: true
    )
    inactive_variant = ProductVariant.create!(
      product: products(:one),
      name: "Inactive Variant",
      sku: "REORDER-INACTIVE-CTRL-1",
      price: 16.00,
      active: false
    )

    @order_one.order_items.create!(
      product_variant: active_variant,
      product: active_variant.product,
      product_name: active_variant.name,
      product_sku: active_variant.sku,
      price: active_variant.price,
      quantity: 1,
      line_total: active_variant.price
    )
    @order_one.order_items.create!(
      product_variant: inactive_variant,
      product: inactive_variant.product,
      product_name: inactive_variant.name,
      product_sku: inactive_variant.sku,
      price: inactive_variant.price,
      quantity: 1,
      line_total: inactive_variant.price
    )

    post reorder_order_url(@order_one)

    assert_redirected_to cart_url
    assert_match(/no longer available/, flash[:notice])
  end

  test "reorder shows error when all items unavailable" do
    sign_in @user_one

    # Clear existing items and add only inactive ones
    @order_one.order_items.destroy_all

    inactive_variant = ProductVariant.create!(
      product: products(:one),
      name: "All Inactive",
      sku: "REORDER-ALLINACTIVE-1",
      price: 16.00,
      active: false
    )
    @order_one.order_items.create!(
      product_variant: inactive_variant,
      product: inactive_variant.product,
      product_name: inactive_variant.name,
      product_sku: inactive_variant.sku,
      price: inactive_variant.price,
      quantity: 1,
      line_total: inactive_variant.price
    )

    post reorder_order_url(@order_one)

    assert_redirected_to orders_url
    assert flash[:alert].present?
  end

  test "reorder denies access to other user's order" do
    sign_in @user_one
    post reorder_order_url(@order_two)  # order_two belongs to user_two
    assert_redirected_to orders_url
    assert_equal "Order not found", flash[:alert]
  end

  test "reorder adds items to cart and redirects" do
    sign_in @user_one

    # Clear fixture items for accurate count test
    @order_one.order_items.destroy_all

    active_variant = ProductVariant.create!(
      product: products(:one),
      name: "Add To Cart Test",
      sku: "REORDER-CART-1",
      price: 16.00,
      active: true
    )
    @order_one.order_items.create!(
      product_variant: active_variant,
      product: active_variant.product,
      product_name: active_variant.name,
      product_sku: active_variant.sku,
      price: active_variant.price,
      quantity: 3,
      line_total: active_variant.price * 3
    )

    post reorder_order_url(@order_one)

    # Verify the redirect and success message
    assert_redirected_to cart_url
    assert flash[:notice].present?
    assert_match(/added/, flash[:notice])

    # Verify item was actually added to a cart (user's session cart)
    # Note: The app uses session-based cart assignment, so we verify
    # by checking a cart exists with the reordered variant
    cart_with_item = CartItem.find_by(product_variant: active_variant)&.cart
    assert_not_nil cart_with_item, "Reordered item should exist in a cart"
    assert_equal 3, cart_with_item.cart_items.find_by(product_variant: active_variant).quantity
  end
end
