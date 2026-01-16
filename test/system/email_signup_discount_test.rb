require "application_system_test_case"

class EmailSignupDiscountTest < ApplicationSystemTestCase
  include StripeTestHelper

  setup do
    @product = products(:widget)
  end

  # =============================================================================
  # T013: Guest Discount Flow (US1)
  # =============================================================================

  test "guest visitor can claim discount on cart page" do
    # Add item to cart
    visit product_path(@product)
    click_on "Add to Cart"

    # Navigate to cart page
    visit cart_path

    # Fill in email signup form
    within "#discount-signup" do
      fill_in "email", with: "newguest@example.com"
      click_on "Get 5% off"
    end

    # Verify success message appears
    assert_selector "[data-test='discount-success']"
    assert_text "5% off"

    # Verify subscription was created
    assert EmailSubscription.exists?(email: "newguest@example.com")
  end

  # =============================================================================
  # T026: Logged-in New Customer Flow (US2)
  # =============================================================================

  test "logged-in user without orders can claim discount" do
    user = users(:user_without_orders)
    sign_in_as(user)

    # Add item to cart
    visit product_path(@product)
    click_on "Add to Cart"

    # Navigate to cart page
    visit cart_path

    # Verify form is visible
    assert_selector "#discount-signup"

    # Fill in email signup form
    within "#discount-signup" do
      fill_in "email", with: user.email_address
      click_on "Get 5% off"
    end

    # Verify success
    assert_selector "[data-test='discount-success']"
  end

  # =============================================================================
  # T029: Returning Customer Excluded (US3)
  # =============================================================================

  test "logged-in user with orders does not see signup form" do
    user = users(:one) # Has orders
    sign_in_as(user)

    # Add item to cart
    visit product_path(@product)
    click_on "Add to Cart"

    # Navigate to cart page
    visit cart_path

    # Verify form is NOT visible
    assert_no_selector "#discount-signup"
  end

  # =============================================================================
  # T034: Rejection Messages (US4)
  # =============================================================================

  test "already subscribed email shows already claimed message" do
    # Add item to cart first
    visit product_path(@product)
    click_on "Add to Cart"
    visit cart_path

    # Use email from fixture
    within "#discount-signup" do
      fill_in "email", with: "claimed@example.com"
      click_on "Get 5% off"
    end

    # Verify "already claimed" message
    assert_selector "[data-test='discount-already-claimed']"
  end

  test "email with previous orders shows not eligible message" do
    # Add item to cart first
    visit product_path(@product)
    click_on "Add to Cart"
    visit cart_path

    # Use email from orders fixture
    within "#discount-signup" do
      fill_in "email", with: "user1@example.com"
      click_on "Get 5% off"
    end

    # Verify "not eligible" message
    assert_selector "[data-test='discount-not-eligible']"
  end

  private

  def sign_in_as(user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password"
    click_on "Sign in"
  end
end
