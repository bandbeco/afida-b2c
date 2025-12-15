# frozen_string_literal: true

require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  # ============================================
  # Authentication tests
  # ============================================

  test "show requires authentication" do
    get account_url
    assert_redirected_to new_session_path
  end

  test "update requires authentication" do
    patch account_url, params: { user: { first_name: "Test" } }
    assert_redirected_to new_session_path
  end

  # ============================================
  # Show action tests
  # ============================================

  test "show displays account settings page" do
    sign_in @user

    get account_url
    assert_response :success
    assert_select "h1", /account|settings/i
  end

  test "show displays current user information" do
    sign_in @user

    get account_url
    assert_response :success
    assert_select "input[value=?]", @user.email_address
  end

  # ============================================
  # Update action tests
  # ============================================

  test "update changes user first name" do
    sign_in @user

    patch account_url, params: { user: { first_name: "Updated" } }

    @user.reload
    assert_equal "Updated", @user.first_name
    assert_redirected_to account_path
    assert_equal "Account updated successfully.", flash[:notice]
  end

  test "update changes user last name" do
    sign_in @user

    patch account_url, params: { user: { last_name: "NewLastName" } }

    @user.reload
    assert_equal "NewLastName", @user.last_name
    assert_redirected_to account_path
  end

  test "update changes multiple fields at once" do
    sign_in @user

    patch account_url, params: {
      user: {
        first_name: "John",
        last_name: "Doe"
      }
    }

    @user.reload
    assert_equal "John", @user.first_name
    assert_equal "Doe", @user.last_name
  end

  test "update does not change email address" do
    sign_in @user
    original_email = @user.email_address

    patch account_url, params: { user: { email_address: "hacker@evil.com" } }

    @user.reload
    assert_equal original_email, @user.email_address
  end

  test "update with empty params still succeeds" do
    sign_in @user

    # Empty update should succeed (no changes)
    patch account_url, params: { user: { first_name: "" } }

    assert_redirected_to account_path
  end

  # ============================================
  # Password change tests
  # ============================================

  test "update changes password when provided" do
    sign_in @user

    patch account_url, params: {
      user: {
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_redirected_to account_path

    # Verify new password works
    @user.reload
    assert @user.authenticate("newpassword123")
  end

  test "update fails with mismatched password confirmation" do
    sign_in @user

    patch account_url, params: {
      user: {
        password: "newpassword123",
        password_confirmation: "different"
      }
    }

    assert_response :unprocessable_entity
  end

  test "update fails with short password" do
    sign_in @user

    patch account_url, params: {
      user: {
        password: "short",
        password_confirmation: "short"
      }
    }

    assert_response :unprocessable_entity
  end

  test "update without password does not require confirmation" do
    sign_in @user

    patch account_url, params: { user: { first_name: "NoPassword" } }

    @user.reload
    assert_equal "NoPassword", @user.first_name
    assert_redirected_to account_path
  end

  private

  def sign_in(user)
    post session_url, params: {
      email_address: user.email_address,
      password: "password"
    }
  end
end
