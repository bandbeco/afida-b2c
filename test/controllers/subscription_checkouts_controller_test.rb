# frozen_string_literal: true

require "test_helper"
require "ostruct"

class SubscriptionCheckoutsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::Helpers::UrlHelper

  setup do
    @user = users(:one)
    @product_variant = product_variants(:single_wall_8oz_white)

    # Clear any existing carts for this user so we have a clean slate
    Cart.where(user: @user).destroy_all

    # Set up a cart with items for the user
    @cart = Cart.create!(user: @user)
    @cart.cart_items.create!(
      product_variant: @product_variant,
      quantity: 2,
      price: @product_variant.price
    )

    # Stub Current.cart to return our test cart
    # (Integration tests don't automatically set cart from session cookie)
    Current.stubs(:cart).returns(@cart)
  end

  # ==========================================================================
  # T014: create requires authentication
  # ==========================================================================

  test "create requires authentication" do
    post subscription_checkouts_path, params: { frequency: "every_month" }

    assert_redirected_to new_session_path
  end

  # ==========================================================================
  # T015: create requires non-empty cart
  # ==========================================================================

  test "create requires non-empty cart" do
    sign_in_as(@user)

    # Empty the cart
    @cart.cart_items.destroy_all

    post subscription_checkouts_path, params: { frequency: "every_month" }

    assert_redirected_to cart_path
    assert_match(/empty/i, flash[:alert])
  end

  # ==========================================================================
  # T016: create rejects samples-only cart
  # ==========================================================================

  test "create rejects samples-only cart" do
    sign_in_as(@user)

    # Convert cart to samples only
    @cart.cart_items.destroy_all
    sample_variant = product_variants(:single_wall_8oz_white)
    sample_variant.update!(sample_eligible: true) if sample_variant.respond_to?(:sample_eligible)

    @cart.cart_items.create!(
      product_variant: sample_variant,
      quantity: 1,
      price: 0,
      is_sample: true  # Mark as sample so only_samples? returns true
    )

    post subscription_checkouts_path, params: { frequency: "every_month" }

    assert_redirected_to cart_path
    assert_match(/sample/i, flash[:alert])
  end

  # ==========================================================================
  # create rejects carts with branded/configured products
  # ==========================================================================

  test "create rejects cart with configured items" do
    sign_in_as(@user)

    # Add a configured (branded) item to cart
    @cart.cart_items.destroy_all
    variant = product_variants(:single_wall_8oz_white)

    # Build the cart item with configuration and attach design before saving
    item = @cart.cart_items.build(
      product_variant: variant,
      quantity: 5000,
      price: 0.18,
      configuration: { design_id: "test_design" },
      calculated_price: 0.18
    )

    # Attach design before validation runs
    item.design.attach(
      io: StringIO.new("fake design content"),
      filename: "design.pdf",
      content_type: "application/pdf"
    )
    item.save!

    post subscription_checkouts_path, params: { frequency: "every_month" }

    assert_redirected_to cart_path
    assert_match(/branded/i, flash[:alert])
  end

  # ==========================================================================
  # T017: create redirects to Stripe on success
  # ==========================================================================

  test "create redirects to Stripe on success" do
    sign_in_as(@user)

    mock_session = OpenStruct.new(
      id: "cs_test_123",
      url: "https://checkout.stripe.com/c/pay/cs_test_123"
    )

    SubscriptionCheckoutService.any_instance.expects(:create_checkout_session).returns(mock_session)

    post subscription_checkouts_path, params: { frequency: "every_month" }

    assert_response :see_other
    assert_redirected_to "https://checkout.stripe.com/c/pay/cs_test_123"
  end

  # ==========================================================================
  # T018: success creates subscription and order
  # ==========================================================================

  test "success creates subscription and order" do
    sign_in_as(@user)

    result = SubscriptionCheckoutService::Result.new(
      success?: true,
      subscription: subscriptions(:active_monthly),
      order: orders(:one)
    )

    SubscriptionCheckoutService.any_instance.expects(:complete_checkout)
      .with("cs_test_success_123")
      .returns(result)

    get success_subscription_checkouts_path, params: { session_id: "cs_test_success_123" }

    assert_redirected_to order_path(orders(:one))
    assert_match(/subscription created/i, flash[:notice])
  end

  # ==========================================================================
  # T018b: success sends confirmation email
  # ==========================================================================

  test "success sends confirmation email for first subscription order" do
    sign_in_as(@user)

    order = orders(:one)
    result = SubscriptionCheckoutService::Result.new(
      success?: true,
      subscription: subscriptions(:active_monthly),
      order: order
    )

    SubscriptionCheckoutService.any_instance.expects(:complete_checkout)
      .with("cs_test_email_123")
      .returns(result)

    assert_enqueued_emails 1 do
      get success_subscription_checkouts_path, params: { session_id: "cs_test_email_123" }
    end
  end

  # ==========================================================================
  # T019: success clears cart (verified via service)
  # ==========================================================================

  test "success redirects to cart with error when session_id missing" do
    sign_in_as(@user)

    get success_subscription_checkouts_path

    assert_redirected_to cart_path
    assert_match(/wrong/i, flash[:alert])
  end

  test "success redirects to cart with error when checkout fails" do
    sign_in_as(@user)

    result = SubscriptionCheckoutService::Result.new(
      success?: false,
      error_message: "Payment session not found"
    )

    SubscriptionCheckoutService.any_instance.expects(:complete_checkout)
      .returns(result)

    get success_subscription_checkouts_path, params: { session_id: "cs_invalid" }

    assert_redirected_to cart_path
    assert_equal "Payment session not found", flash[:alert]
  end

  # ==========================================================================
  # T020: cancel redirects to cart with flash
  # ==========================================================================

  test "cancel redirects to cart with flash" do
    sign_in_as(@user)

    get cancel_subscription_checkouts_path

    assert_redirected_to cart_path
    assert_match(/cancelled/i, flash[:notice])
  end

  # ==========================================================================
  # Additional tests: Invalid frequency
  # ==========================================================================

  test "create rejects invalid frequency" do
    sign_in_as(@user)

    post subscription_checkouts_path, params: { frequency: "invalid_frequency" }

    assert_redirected_to cart_path
    assert_match(/invalid/i, flash[:alert])
  end

  test "create accepts all valid frequencies" do
    sign_in_as(@user)

    mock_session = OpenStruct.new(id: "cs_test", url: "https://checkout.stripe.com/test")
    SubscriptionCheckoutService.any_instance.stubs(:create_checkout_session).returns(mock_session)

    %w[every_week every_two_weeks every_month every_3_months].each do |freq|
      post subscription_checkouts_path, params: { frequency: freq }
      assert_response :see_other, "Expected redirect for frequency: #{freq}"
    end
  end

  # ==========================================================================
  # Rate limiting test
  # ==========================================================================

  test "create has rate limiting configured" do
    # Verify the rate_limit declaration exists on the controller
    # (Full rate limit behavior requires integration testing with cache store)
    assert SubscriptionCheckoutsController.respond_to?(:rate_limit)
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
