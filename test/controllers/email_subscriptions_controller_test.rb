require "test_helper"

class EmailSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  # The welcome coupon id the app stores in the session, read from the test
  # credentials so the assertions track the actual vault value (CI decrypts
  # test.yml.enc via RAILS_TEST_KEY, so this is the same in CI and locally). The
  # session carries the coupon id; SessionBuilder resolves it to the customer-facing
  # promotion code (and records that name on the order) only when calling Stripe.
  def welcome_coupon_id
    Rails.application.credentials.dig(:stripe, :welcome_coupon)
  end

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

  # When the cart has items, claiming the discount must refresh the cart summary in
  # the same response so the discount line, VAT and total appear without a full page
  # reload (the form submits via Turbo). The whole #cart_summary is replaced, so the
  # discount line and the reduced total arrive together. It keys off the freshly
  # stored session code, so the cart has to be given the discount rate before rendering.
  test "successful signup refreshes the cart summary with the discount" do
    add_item_to_session_cart

    post email_subscriptions_path,
         params: { email: "summary-refresh@example.com" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_select "turbo-stream[action=replace][target=cart_summary]" do
      assert_select "#discount_amount", text: /-/
      assert_select "#grand_total"
    end
  end

  test "successful signup does not refresh the cart summary when the cart is empty" do
    # No items, so there is no summary on screen to update; only the signup box
    # is replaced. Avoids targeting a cart-summary that is not in the DOM.
    post email_subscriptions_path,
         params: { email: "empty-summary@example.com" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_select "turbo-stream[target=cart_summary]", count: 0
  end

  # A samples-only cart pays only shipping, and SessionBuilder refuses every discount
  # for it at checkout. The preview must not promise a discount the customer won't
  # get: the refreshed summary carries no discount line and a Total that still
  # reflects full shipping + VAT, never a reduced figure.
  test "successful signup does not show a discount for a samples-only cart" do
    cart = add_item_to_session_cart
    cart.cart_items.update_all(is_sample: true, price: 0)

    post email_subscriptions_path,
         params: { email: "samples-discount@example.com" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    cost = BigDecimal(Shipping.standard_cost_in_pounds.to_s)
    expected_total = (cost + cost * BigDecimal(VAT_RATE.to_s)).round(2)
    assert_select "turbo-stream[action=replace][target=cart_summary]" do
      # No discount line (no leading-minus amount), and the Total is full shipping + VAT.
      assert_select "#discount_amount", count: 0
      assert_select "#grand_total",
                    text: /#{Regexp.escape(ActiveSupport::NumberHelper.number_to_currency(expected_total))}/
    end
  end

  # =============================================================================
  # T012: Session Discount Code Storage Tests (US1)
  # =============================================================================

  test "successful signup stores discount code in session" do
    post email_subscriptions_path,
         params: { email: "newvisitor@example.com" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal welcome_coupon_id, session[:discount_code]
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
    assert_equal welcome_coupon_id, session[:discount_code]
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

    assert_equal welcome_coupon_id, session[:discount_code]
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
    assert_equal welcome_coupon_id, session[:discount_code]

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

  # =============================================================================
  # Abandoned-cart trigger (cart.checkout_initiated)
  # =============================================================================

  # Note: Rails.event runs payloads through config.filter_parameters, and :email
  # is a filtered key, so the captured email reads "[FILTERED]" here. The email's
  # fidelity (typed + downcased, used as the Klaviyo profile) is asserted in the
  # subscriber tests, which receive the raw payload. At this boundary we assert
  # the event fires for the right cart with the right source.
  test "emits cart.checkout_initiated on successful signup when the cart has items" do
    cart = add_item_to_session_cart

    assert_event_reported("cart.checkout_initiated",
      payload: {
        cart_id: cart.id,
        source: "cart_discount"
      }
    ) do
      post email_subscriptions_path, params: { email: "abandon-test@example.com" }
    end
  end

  test "cart.checkout_initiated carries an integer cart_id" do
    add_item_to_session_cart

    assert_event_reported("cart.checkout_initiated",
      payload: {
        cart_id: ->(v) { v.is_a?(Integer) }
      }
    ) do
      post email_subscriptions_path, params: { email: "MixedCase@Example.com" }
    end
  end

  # Closes the loop the filtered-payload tests above leave open: although :email
  # reads "[FILTERED]" in the captured event, the real (typed + downcased) address
  # must reach the Klaviyo job unredacted. KlaviyoSubscriber resolves it from the
  # EmailSubscription rather than the filtered payload, and runs inline during the
  # request. We stub perform_later (the test queue adapter is async, so it does not
  # populate enqueued_jobs) and assert the Started Checkout call carries the address.
  test "the typed email reaches the Started Checkout job unfiltered and downcased" do
    add_item_to_session_cart

    KlaviyoEventJob.expects(:perform_later)
      .with("track", has_entries(metric: "Started Checkout", email: "mixedcase@example.com"))
      .once
    # Other events in the request (Subscribed) also enqueue; allow them.
    KlaviyoEventJob.stubs(:perform_later)
      .with("track", Not(has_entry(metric: "Started Checkout")))

    post email_subscriptions_path, params: { email: "MixedCase@Example.com" }
  end

  test "does not emit cart.checkout_initiated when the cart is empty" do
    assert_no_event_reported("cart.checkout_initiated") do
      post email_subscriptions_path, params: { email: "empty-cart@example.com" }
    end
  end

  test "does not emit cart.checkout_initiated for a sample-only cart" do
    cart = add_item_to_session_cart
    cart.cart_items.update_all(is_sample: true, price: 0)

    assert_no_event_reported("cart.checkout_initiated") do
      post email_subscriptions_path, params: { email: "samples-only@example.com" }
    end
  end

  test "does not emit cart.checkout_initiated when the email already claimed the discount" do
    add_item_to_session_cart

    assert_no_event_reported("cart.checkout_initiated") do
      post email_subscriptions_path, params: { email: "claimed@example.com" }
    end
  end

  test "does not emit cart.checkout_initiated when the email has previous orders" do
    add_item_to_session_cart

    assert_no_event_reported("cart.checkout_initiated") do
      post email_subscriptions_path, params: { email: "user1@example.com" }
    end
  end

  test "does not emit cart.checkout_initiated for an invalid email" do
    add_item_to_session_cart

    assert_no_event_reported("cart.checkout_initiated") do
      post email_subscriptions_path, params: { email: "not-an-email" }
    end
  end

  private

  # Adds a standard product to the guest cart bound to this integration session,
  # then returns the cart. Subsequent requests in the same test reuse session[:cart_id].
  def add_item_to_session_cart
    post cart_cart_items_path, params: {
      cart_item: { sku: products(:single_wall_8oz_white).sku, quantity: 1 }
    }
    Cart.find(session[:cart_id])
  end

  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password"
    }
  end
end
