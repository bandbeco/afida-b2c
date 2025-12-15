# frozen_string_literal: true

require "application_system_test_case"

class AccountConversionTest < ApplicationSystemTestCase
  # Note: Full E2E tests with Stripe checkout are complex to set up.
  # These tests focus on the conversion form behavior after checkout.
  #
  # The comprehensive test coverage includes:
  # - PostCheckoutRegistrationsController tests (test/controllers/post_checkout_registrations_controller_test.rb)
  #
  # System tests here verify the UI elements and form behavior.

  test "guest sees account conversion form on confirmation page" do
    order = orders(:guest_order)

    visit confirmation_order_path(order, token: order.signed_access_token)

    # Should see the conversion prompt
    assert_text "Create an account"
    assert_text "Save your order history"

    # Should see password fields
    assert_selector "input[type='password'][name='user[password]']"
    assert_selector "input[type='password'][name='user[password_confirmation]']"

    # Should see the order email pre-filled or displayed
    assert_text order.email
  end

  test "logged in user does not see conversion form" do
    order = orders(:one) # Order with user
    user = users(:one)

    sign_in_as(user)

    visit confirmation_order_path(order, token: order.signed_access_token)

    # Should NOT see the conversion prompt
    assert_no_text "Create an account"
    assert_no_selector "input[name='user[password]']"
  end

  test "conversion form shows validation errors" do
    order = orders(:guest_order)

    visit confirmation_order_path(order, token: order.signed_access_token)

    # Submit with mismatched passwords
    fill_in "Password", with: "password123"
    fill_in "Confirm password", with: "different"
    click_button "Create Account"

    # Should show error
    assert_text "doesn't match" # or similar validation message
  end

  private

  def sign_in_as(user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign In"
  end
end
