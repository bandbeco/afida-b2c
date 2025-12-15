# frozen_string_literal: true

require "test_helper"

class PostCheckoutRegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @guest_order = orders(:guest_order)
    @valid_password = "securepassword123"
  end

  # ============================================
  # Successful conversion tests
  # ============================================

  test "create converts guest to account with valid password" do
    # Simulate having just completed checkout by visiting confirmation page first
    # This sets up the session properly
    get confirmation_order_url(@guest_order, token: @guest_order.signed_access_token)
    assert_response :success

    post post_checkout_registration_url, params: {
      user: {
        password: @valid_password,
        password_confirmation: @valid_password
      }
    }

    # Should create a new user
    user = User.find_by(email_address: @guest_order.email)
    assert_not_nil user, "User should be created"

    # Order should be linked to new user
    @guest_order.reload
    assert_equal user, @guest_order.user

    # Should redirect back to confirmation (token changes due to timestamp, so just check path)
    assert_response :redirect
    assert_match %r{/orders/#{@guest_order.id}/confirmation}, response.location
    assert_equal "Account created! You can now view your order history.", flash[:notice]
  end

  test "create logs in the new user" do
    # Set up session by visiting confirmation with token
    get confirmation_order_url(@guest_order, token: @guest_order.signed_access_token)

    post post_checkout_registration_url, params: {
      user: {
        password: @valid_password,
        password_confirmation: @valid_password
      }
    }

    # Follow redirect
    follow_redirect!
    assert_response :success

    # Should be able to access authenticated routes
    get orders_url
    assert_response :success
  end

  # ============================================
  # Validation error tests
  # ============================================

  test "create fails with blank password" do
    get confirmation_order_url(@guest_order, token: @guest_order.signed_access_token)

    assert_no_difference "User.count" do
      post post_checkout_registration_url, params: {
        user: {
          password: "",
          password_confirmation: ""
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create fails with password mismatch" do
    get confirmation_order_url(@guest_order, token: @guest_order.signed_access_token)

    assert_no_difference "User.count" do
      post post_checkout_registration_url, params: {
        user: {
          password: @valid_password,
          password_confirmation: "different_password"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create fails with short password" do
    get confirmation_order_url(@guest_order, token: @guest_order.signed_access_token)

    assert_no_difference "User.count" do
      post post_checkout_registration_url, params: {
        user: {
          password: "short",
          password_confirmation: "short"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  # ============================================
  # Email already registered tests
  # ============================================

  test "create fails when email already registered" do
    # Create a user with the guest order's email
    User.create!(
      email_address: @guest_order.email,
      password: "existing_password"
    )

    get confirmation_order_url(@guest_order, token: @guest_order.signed_access_token)

    assert_no_difference "User.count" do
      post post_checkout_registration_url, params: {
        user: {
          password: @valid_password,
          password_confirmation: @valid_password
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "a[href=?]", new_session_path, text: /sign in/i
  end

  # ============================================
  # Authorization tests
  # ============================================

  test "create requires recent order in session" do
    # No order in session - go directly to the registration endpoint
    assert_no_difference "User.count" do
      post post_checkout_registration_url, params: {
        user: {
          password: @valid_password,
          password_confirmation: @valid_password
        }
      }
    end

    assert_redirected_to root_path
    assert_equal "No recent order found.", flash[:alert]
  end

  test "create fails if order already has a user" do
    order_with_user = orders(:one) # This order belongs to user :one

    # Visit confirmation with token to set session
    get confirmation_order_url(order_with_user, token: order_with_user.signed_access_token)

    assert_no_difference "User.count" do
      post post_checkout_registration_url, params: {
        user: {
          password: @valid_password,
          password_confirmation: @valid_password
        }
      }
    end

    assert_redirected_to root_path
    assert_equal "This order already has an account.", flash[:alert]
  end

  test "logged in user cannot access conversion" do
    sign_in users(:one)

    # Even with recent order in session, logged in users shouldn't convert
    get confirmation_order_url(@guest_order, token: @guest_order.signed_access_token)

    assert_no_difference "User.count" do
      post post_checkout_registration_url, params: {
        user: {
          password: @valid_password,
          password_confirmation: @valid_password
        }
      }
    end

    assert_redirected_to root_path
  end

  private

  def sign_in(user)
    post session_url, params: {
      email_address: user.email_address,
      password: "password"
    }
  end
end
