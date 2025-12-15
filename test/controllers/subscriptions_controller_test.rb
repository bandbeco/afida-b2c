# frozen_string_literal: true

require "test_helper"

class SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @active_subscription = subscriptions(:active_monthly)
    @paused_subscription = subscriptions(:paused_subscription)
  end

  # ============================================
  # Authentication Tests
  # ============================================

  test "index requires authentication" do
    get subscriptions_path
    assert_redirected_to new_session_path
  end

  test "destroy requires authentication" do
    delete subscription_path(@active_subscription)
    assert_redirected_to new_session_path
  end

  test "pause requires authentication" do
    patch pause_subscription_path(@active_subscription)
    assert_redirected_to new_session_path
  end

  test "resume requires authentication" do
    patch resume_subscription_path(@paused_subscription)
    assert_redirected_to new_session_path
  end

  # ============================================
  # Index Tests
  # ============================================

  test "index shows user subscriptions" do
    sign_in_as(@user)
    get subscriptions_path
    assert_response :success
    assert_select "h1", text: /Subscriptions/
  end

  test "index only shows current user subscriptions" do
    sign_in_as(@user)
    get subscriptions_path
    assert_response :success

    # User one has active_monthly and paused_subscription
    assert_match @active_subscription.stripe_subscription_id, response.body
    assert_match @paused_subscription.stripe_subscription_id, response.body

    # User two's subscription should not be visible
    other_subscription = subscriptions(:active_quarterly)
    assert_no_match other_subscription.stripe_subscription_id, response.body
  end

  test "index shows empty state when no subscriptions" do
    # Use a user who has no subscriptions in fixtures
    # (one, two, consumer all have subscriptions)
    user_without_subs = users(:acme_owner)
    sign_in_as(user_without_subs)
    get subscriptions_path
    assert_response :success
    assert_match(/no subscriptions/i, response.body)
  end

  # ============================================
  # Destroy (Cancel) Tests
  # ============================================

  test "destroy cancels subscription" do
    sign_in_as(@user)
    assert_changes -> { @active_subscription.reload.status }, from: "active", to: "cancelled" do
      delete subscription_path(@active_subscription)
    end
    assert_redirected_to subscriptions_path
    follow_redirect!
    assert_match(/cancelled/i, response.body)
  end

  test "destroy sets cancelled_at timestamp" do
    sign_in_as(@user)
    freeze_time do
      delete subscription_path(@active_subscription)
      assert_equal Time.current, @active_subscription.reload.cancelled_at
    end
  end

  test "cannot cancel another user subscription" do
    sign_in_as(@other_user)
    assert_no_changes -> { @active_subscription.reload.status } do
      delete subscription_path(@active_subscription)
    end
    assert_response :not_found
  end

  test "cannot cancel already cancelled subscription" do
    sign_in_as(@other_user)
    cancelled = subscriptions(:cancelled_subscription)
    delete subscription_path(cancelled)
    assert_redirected_to subscriptions_path
    follow_redirect!
    assert_match(/already been cancelled/i, response.body)
  end

  # ============================================
  # Pause Tests
  # ============================================

  test "pause pauses active subscription" do
    sign_in_as(@user)
    assert_changes -> { @active_subscription.reload.status }, from: "active", to: "paused" do
      patch pause_subscription_path(@active_subscription)
    end
    assert_redirected_to subscriptions_path
    follow_redirect!
    assert_match(/paused/i, response.body)
  end

  test "cannot pause another user subscription" do
    sign_in_as(@other_user)
    assert_no_changes -> { @active_subscription.reload.status } do
      patch pause_subscription_path(@active_subscription)
    end
    assert_response :not_found
  end

  test "cannot pause already paused subscription" do
    sign_in_as(@user)
    patch pause_subscription_path(@paused_subscription)
    assert_redirected_to subscriptions_path
    follow_redirect!
    assert_match(/already paused/i, response.body)
  end

  test "cannot pause cancelled subscription" do
    sign_in_as(@other_user)
    cancelled = subscriptions(:cancelled_subscription)
    patch pause_subscription_path(cancelled)
    assert_redirected_to subscriptions_path
    follow_redirect!
    assert_match(/cannot be paused/i, response.body)
  end

  # ============================================
  # Resume Tests
  # ============================================

  test "resume resumes paused subscription" do
    sign_in_as(@user)
    assert_changes -> { @paused_subscription.reload.status }, from: "paused", to: "active" do
      patch resume_subscription_path(@paused_subscription)
    end
    assert_redirected_to subscriptions_path
    follow_redirect!
    assert_match(/resumed/i, response.body)
  end

  test "cannot resume another user subscription" do
    sign_in_as(@other_user)
    assert_no_changes -> { @paused_subscription.reload.status } do
      patch resume_subscription_path(@paused_subscription)
    end
    assert_response :not_found
  end

  test "cannot resume active subscription" do
    sign_in_as(@user)
    patch resume_subscription_path(@active_subscription)
    assert_redirected_to subscriptions_path
    follow_redirect!
    assert_match(/already active/i, response.body)
  end

  test "cannot resume cancelled subscription" do
    sign_in_as(@other_user)
    cancelled = subscriptions(:cancelled_subscription)
    patch resume_subscription_path(cancelled)
    assert_redirected_to subscriptions_path
    follow_redirect!
    assert_match(/cannot be resumed/i, response.body)
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
