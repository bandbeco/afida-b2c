require "test_helper"

class EmailSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  # =============================================================================
  # T011: Successful Signup Tests (US1)
  # =============================================================================

  test "successful signup creates email subscription" do
    assert_difference "EmailSubscription.count", 1 do
      post email_subscriptions_path, params: { email: "newvisitor@example.com" }
    end

    subscription = EmailSubscription.last
    assert_equal "newvisitor@example.com", subscription.email
    assert_not_nil subscription.discount_claimed_at
    assert_equal "cart_discount", subscription.source
  end

  test "successful signup returns turbo stream response" do
    post email_subscriptions_path,
         params: { email: "newvisitor@example.com" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
    assert_includes response.body, 'turbo-stream action="replace" target="discount-signup"'
  end

  # =============================================================================
  # T012: Session Discount Code Storage Tests (US1)
  # =============================================================================

  test "successful signup stores discount code in session" do
    post email_subscriptions_path,
         params: { email: "newvisitor@example.com" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal "WELCOME5", session[:discount_code]
  end

  test "successful signup does not store discount code if already present" do
    # Simulate already having a discount code in session
    post email_subscriptions_path,
         params: { email: "first@example.com" }

    # Try to sign up again with different email
    post email_subscriptions_path,
         params: { email: "second@example.com" }

    # Second subscription should be created (email list capture)
    # but session should still have original discount code
    assert_equal "WELCOME5", session[:discount_code]
  end

  # =============================================================================
  # T025: Logged-in User Eligibility Tests (US2)
  # =============================================================================

  test "logged-in user without orders can claim discount" do
    # User with no orders
    user = users(:user_without_orders)
    sign_in_as(user)

    assert_difference "EmailSubscription.count", 1 do
      post email_subscriptions_path, params: { email: user.email_address }
    end

    assert_equal "WELCOME5", session[:discount_code]
  end

  test "logged-in user submitting email with previous orders gets not eligible response" do
    # User is logged in, but submits an email that has previous orders
    # (the eligibility check is by email in orders table, not user association)
    user = users(:user_without_orders)
    sign_in_as(user)

    # Submit email that exists in orders fixture (user1@example.com)
    post email_subscriptions_path,
         params: { email: "user1@example.com" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.body, "discount-not-eligible"
    assert_nil session[:discount_code]
  end

  # =============================================================================
  # T032: Already Claimed Response Tests (US4)
  # =============================================================================

  test "already claimed email returns already claimed response" do
    # Uses fixture: email_subscriptions(:claimed_discount) has discount_claimed_at set
    post email_subscriptions_path,
         params: { email: "claimed@example.com" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.body, "discount-already-claimed"
    assert_nil session[:discount_code]
  end

  # =============================================================================
  # Newsletter-only Subscriber Tests
  # =============================================================================

  test "newsletter-only subscriber can claim discount" do
    # Uses fixture: email_subscriptions(:subscribed_only) has discount_claimed_at: nil
    subscription = email_subscriptions(:subscribed_only)

    assert_no_difference "EmailSubscription.count" do
      post email_subscriptions_path,
           params: { email: subscription.email },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_includes response.body, 'turbo-stream action="replace" target="discount-signup"'
    assert_equal "WELCOME5", session[:discount_code]

    # Verify discount_claimed_at was set on existing record
    subscription.reload
    assert_not_nil subscription.discount_claimed_at
    assert_equal "footer", subscription.source  # Preserves original source
  end

  # =============================================================================
  # T033: Not Eligible Response Tests (US4)
  # =============================================================================

  test "email with previous orders returns not eligible response" do
    # Uses fixture: orders(:one) has email "user1@example.com"
    post email_subscriptions_path,
         params: { email: "user1@example.com" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.body, "discount-not-eligible"
    assert_nil session[:discount_code]
  end

  test "invalid email format returns unprocessable entity" do
    post email_subscriptions_path,
         params: { email: "not-an-email" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :unprocessable_entity
  end

  # =============================================================================
  # STRUCTURED EVENT EMISSION TESTS (US2: Email Signup Funnel)
  # =============================================================================

  test "emits email_signup.completed event on successful signup" do
    assert_event_reported("email_signup.completed") do
      post email_subscriptions_path, params: { email: "events-test@example.com" }
    end
  end

  test "does not emit email_signup.completed when email already claimed" do
    assert_no_event_reported("email_signup.completed") do
      post email_subscriptions_path, params: { email: "claimed@example.com" }
    end
  end

  test "does not emit email_signup.completed when email has previous orders" do
    assert_no_event_reported("email_signup.completed") do
      post email_subscriptions_path, params: { email: "user1@example.com" }
    end
  end

  test "does not emit email_signup.completed for invalid email" do
    assert_no_event_reported("email_signup.completed") do
      post email_subscriptions_path, params: { email: "not-an-email" }
    end
  end

  private

  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password"
    }
  end
end
