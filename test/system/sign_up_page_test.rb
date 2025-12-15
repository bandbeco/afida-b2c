# frozen_string_literal: true

require "application_system_test_case"

class SignUpPageTest < ApplicationSystemTestCase
  test "sign-up page displays value proposition tagline" do
    visit new_registration_path

    assert_text "Reorder in seconds"
    assert_text "Your order history, saved and ready"
  end

  test "sign-up page displays account benefits" do
    visit new_registration_path

    # Check for benefits list
    assert_text "View your complete order history"
    assert_text "Reorder previous orders in one click"
    assert_text "Recurring orders coming soon"
  end

  test "sign-up page has functional registration form" do
    visit new_registration_path

    # Form should be present with all fields
    assert_selector "input[type='email']"
    assert_selector "input[type='password']", count: 2
    assert_selector "input[type='submit'][value='Sign Up']"
  end

  test "user can complete registration from sign-up page" do
    visit new_registration_path

    fill_in "Email", with: "newuser@example.com"
    fill_in "user[password]", with: "securepassword123"
    fill_in "user[password_confirmation]", with: "securepassword123"

    click_button "Sign Up"

    # Should be redirected and logged in
    assert_current_path root_path
    assert User.find_by(email_address: "newuser@example.com")
  end

  test "sign-up page shows link to login for existing users" do
    visit new_registration_path

    assert_text "Already have an account?"
    assert_link "Log In"
    click_link "Log In"

    assert_current_path new_session_path
  end
end
