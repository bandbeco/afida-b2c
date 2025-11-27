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

  # T014: User viewing guest order (denied)
  test "show redirects when accessing guest order" do
    sign_in @user_one
    get order_url(@guest_order)  # guest_order has no user
    assert_redirected_to orders_path
    assert_equal "Order not found", flash[:alert]
  end

  test "show requires authentication" do
    get order_url(@order_one)
    assert_redirected_to new_session_path
  end

  # Additional authorization tests - verify bidirectional protection
  test "user two cannot view user one's order" do
    sign_in @user_two
    get order_url(@order_one)
    assert_redirected_to orders_path
    assert_equal "Order not found", flash[:alert]
  end
end
