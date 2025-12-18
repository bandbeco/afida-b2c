# frozen_string_literal: true

require "application_system_test_case"

class SignUpPageTest < ApplicationSystemTestCase
  test "sign-up page displays value proposition tagline" do
    visit new_registration_path

    assert_text "Your orders, remembered"
    assert_text "Reorder your favourites in seconds"
  end

  test "sign-up page displays account benefits" do
    visit new_registration_path

    # Check for benefits list
    assert_text "See what you've ordered and when"
    assert_text "Repeat any order in two clicks"
    assert_text "Set it and forget it"
  end

  test "sign-up page has functional registration form" do
    visit new_registration_path

    # Form should be present with all fields
    assert_selector "input[type='email']"
    assert_selector "input[type='password']"
    assert_selector "input[type='submit'][value='Sign Up']"
  end

  test "user can complete registration from sign-up page" do
    visit new_registration_path

    fill_in "Email", with: "newuser@example.com"
    fill_in "Password", with: "securepassword123"

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
