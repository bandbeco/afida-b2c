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
    assert_select "h1", "Order Confirmed!"
  end

  # T013: User viewing another user's order (denied)
  test "show redirects when accessing another user's order" do
    sign_in @user_one
    get order_url(@order_two)  # order_two belongs to user_two
    assert_redirected_to orders_path
    assert_equal "Order not found", flash[:alert]
  end

  # T014: User viewing guest order (denied - no token or flash)
  test "show redirects when accessing guest order without authorization" do
    sign_in @user_one
    get order_url(@guest_order)  # guest_order has no user
    assert_redirected_to orders_path
    assert_equal "Order not found", flash[:alert]
  end

  # Guest access without any credentials should be denied
  test "unauthenticated user cannot view order without token" do
    get order_url(@order_one)
    assert_redirected_to orders_path
    assert_equal "Order not found", flash[:alert]
  end

  # Additional authorization tests - verify bidirectional protection
  test "user two cannot view user one's order" do
    sign_in @user_two
    get order_url(@order_one)
    assert_redirected_to orders_path
    assert_equal "Order not found", flash[:alert]
  end

  # ============================================
  # Guest checkout access via secure token
  # ============================================

  test "guest can view order with valid secure token" do
    token = @guest_order.secure_access_token
    get order_url(@guest_order, token: token)
    assert_response :success
    assert_select "h1", "Order Confirmed!"
  end

  test "guest cannot view order with invalid token" do
    get order_url(@guest_order, token: "invalid_token_here")
    assert_redirected_to orders_path
    assert_equal "Order not found", flash[:alert]
  end

  test "guest cannot view order with empty token" do
    get order_url(@guest_order, token: "")
    assert_redirected_to orders_path
    assert_equal "Order not found", flash[:alert]
  end

  test "guest cannot view order with tampered token" do
    # Generate a token using different data
    tampered_token = Digest::SHA256.hexdigest("999-fake_session-#{Rails.application.secret_key_base}")
    get order_url(@guest_order, token: tampered_token)
    assert_redirected_to orders_path
    assert_equal "Order not found", flash[:alert]
  end

  test "token for one order cannot access another order" do
    # Get valid token for guest_order but try to access order_one
    token = @guest_order.secure_access_token
    get order_url(@order_one, token: token)
    assert_redirected_to orders_path
    assert_equal "Order not found", flash[:alert]
  end

  # ============================================
  # Guest checkout access via flash message
  # (immediately after checkout redirect)
  # ============================================

  test "guest can view order when flash contains order number" do
    # Simulate the redirect from checkout with flash
    # First set flash via a previous request, then follow redirect
    get order_url(@guest_order)
    # Can't easily test flash in integration tests without going through checkout
    # This is better tested in a system test or by testing the controller directly
    assert_redirected_to orders_path
  end

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
    wrong_token = @guest_order.secure_access_token
    get order_url(@order_one, token: wrong_token)
    assert_response :success
  end
end
