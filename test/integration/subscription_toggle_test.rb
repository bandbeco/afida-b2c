# frozen_string_literal: true

require "test_helper"

class SubscriptionToggleTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @variant = product_variants(:single_wall_8oz_white)
  end

  # T065: Guest user sees disabled toggle with sign-in message
  test "guest user sees disabled toggle with sign-in prompt in cart" do
    # Add item to cart as guest (this creates a guest cart and sets session)
    # The controller expects cart_item: { variant_sku: ..., quantity: ... }
    post cart_cart_items_path, params: { cart_item: { variant_sku: @variant.sku, quantity: 1 } }

    # Now visit cart page
    get cart_path

    # Verify the subscription toggle is shown with disabled state
    assert_response :success
    assert_match(/Make this a recurring order/, response.body)
    assert_select "input[type='checkbox'][disabled]"
    assert_match(/Sign in/, response.body)
    assert_match(/to set up recurring orders/, response.body)
  end

  # T066: Sign-in link includes return URL to cart
  test "guest user sign-in link includes return_to parameter" do
    # Add item to cart as guest
    post cart_cart_items_path, params: { cart_item: { variant_sku: @variant.sku, quantity: 1 } }

    get cart_path

    assert_response :success
    # Check that the sign-in link has return_to=cart
    assert_select "a[href*='signin'][href*='return_to']" do |links|
      link = links.first
      assert link[:href].include?("/signin")
      assert link[:href].include?("return_to")
      assert link[:href].include?("cart")
    end
  end

  # T067-T070: Guest toggle partial shows correct state
  test "logged-in user sees enabled toggle" do
    # Sign in (must follow redirect to complete login)
    post session_path, params: { email_address: @user.email_address, password: "password" }
    follow_redirect!

    # Add item to cart
    post cart_cart_items_path, params: { cart_item: { variant_sku: @variant.sku, quantity: 1 } }

    get cart_path

    assert_response :success
    # Logged-in users should see an enabled toggle (not disabled)
    assert_select "input[type='checkbox'].toggle:not([disabled])"
    assert_match(/Make this a recurring order/, response.body)
  end

  test "samples-only cart shows disabled toggle for logged-in user" do
    # Sign in (must follow redirect to complete login)
    post session_path, params: { email_address: @user.email_address, password: "password" }
    follow_redirect!

    # Add a sample to cart (price = 0)
    @variant.update!(sample_eligible: true)
    post cart_cart_items_path, params: { product_variant_id: @variant.id, quantity: 1, sample: true }

    get cart_path

    assert_response :success
    # Should see disabled toggle with samples message
    assert_select "input[type='checkbox'][disabled]"
    assert_match(/Subscriptions are not available for sample orders/, response.body)
  end
end
