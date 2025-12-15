# frozen_string_literal: true

require "application_system_test_case"

class AccountNavigationTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
  end

  test "logged in user sees account dropdown in navbar" do
    sign_in @user

    # After sign in, should be on root and see avatar
    assert_selector ".avatar-placeholder"
  end

  test "account dropdown contains settings link" do
    sign_in @user
    open_account_menu

    # Should see Account Settings link in dropdown (use visible: :all due to DaisyUI positioning)
    assert_selector "[data-testid='account-dropdown'] a", text: "Account Settings", visible: :all
  end

  test "account dropdown contains orders link" do
    sign_in @user
    open_account_menu

    assert_selector "[data-testid='account-dropdown'] a", text: "Orders", visible: :all
  end

  test "account dropdown contains logout link" do
    sign_in @user
    open_account_menu

    assert_selector "[data-testid='account-dropdown']", text: "Logout", visible: :all
  end

  test "clicking account settings navigates to settings page" do
    sign_in @user
    open_account_menu

    # Use find with visible: :all to click link in DaisyUI dropdown
    find("[data-testid='account-dropdown'] a", text: "Account Settings", visible: :all).click

    assert_current_path account_path
    assert_text "Account Settings"
  end

  test "account settings page shows user email" do
    sign_in @user

    visit account_path

    # The email field should be disabled and show the user's email
    assert_selector "input[value='#{@user.email_address}'][disabled]"
  end

  test "user can update their name from settings page" do
    sign_in @user

    visit account_path

    fill_in "user[first_name]", with: "UpdatedFirst"
    fill_in "user[last_name]", with: "UpdatedLast"
    click_button "Save Changes"

    assert_text "Account updated successfully"

    @user.reload
    assert_equal "UpdatedFirst", @user.first_name
    assert_equal "UpdatedLast", @user.last_name
  end

  test "user can change password from settings page" do
    sign_in @user

    visit account_path

    fill_in "user[password]", with: "newsecurepassword"
    fill_in "user[password_confirmation]", with: "newsecurepassword"
    click_button "Save Changes"

    assert_text "Account updated successfully"

    # Verify can log in with new password
    open_account_menu
    find("[data-testid='account-dropdown'] a", text: "Logout", visible: :all).click

    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "newsecurepassword"
    click_button "Sign In"

    assert_current_path root_path
  end

  private

  def sign_in(user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign In"
    # Wait for redirect to complete and avatar to appear (confirms user is logged in)
    assert_selector ".avatar-placeholder", wait: 5
  end

  def open_account_menu
    # DaisyUI <details> dropdown opens on click (no JS needed)
    find("[data-testid='account-dropdown'] summary").click
    # Wait for dropdown to have 'open' attribute and menu to be visible
    assert_selector "[data-testid='account-dropdown'][open]", wait: 3
  end
end
