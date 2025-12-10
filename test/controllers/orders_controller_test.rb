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
end
