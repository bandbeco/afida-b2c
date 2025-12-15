require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  setup do
    @subscription = subscriptions(:active_monthly)
    @user = users(:one)
    @valid_attributes = {
      user: @user,
      stripe_subscription_id: "sub_test_new_#{SecureRandom.hex(4)}",
      stripe_customer_id: "cus_test_new",
      stripe_price_id: "price_test_new",
      frequency: "every_month",
      status: "active",
      items_snapshot: {
        "items" => [ { "product_variant_id" => 1, "product_name" => "Test Product", "quantity" => 1, "price" => "10.00" } ],
        "subtotal" => "10.00",
        "vat" => "2.00",
        "total" => "12.00"
      },
      shipping_snapshot: {
        "name" => "Test User",
        "line1" => "123 Test St",
        "city" => "London",
        "postal_code" => "SW1A 1AA",
        "country" => "GB"
      }
    }
  end

  # Validation tests
  test "valid subscription with all attributes" do
    subscription = Subscription.new(@valid_attributes)
    assert subscription.valid?
  end

  test "requires user" do
    subscription = Subscription.new(@valid_attributes.except(:user))
    assert_not subscription.valid?
    assert_includes subscription.errors[:user], "must exist"
  end

  test "requires stripe_subscription_id" do
    subscription = Subscription.new(@valid_attributes.except(:stripe_subscription_id))
    assert_not subscription.valid?
    assert_includes subscription.errors[:stripe_subscription_id], "can't be blank"
  end

  test "requires unique stripe_subscription_id" do
    subscription = Subscription.new(@valid_attributes.merge(stripe_subscription_id: @subscription.stripe_subscription_id))
    assert_not subscription.valid?
    assert_includes subscription.errors[:stripe_subscription_id], "has already been taken"
  end

  test "requires stripe_customer_id" do
    subscription = Subscription.new(@valid_attributes.except(:stripe_customer_id))
    assert_not subscription.valid?
    assert_includes subscription.errors[:stripe_customer_id], "can't be blank"
  end

  test "requires stripe_price_id" do
    subscription = Subscription.new(@valid_attributes.except(:stripe_price_id))
    assert_not subscription.valid?
    assert_includes subscription.errors[:stripe_price_id], "can't be blank"
  end

  test "requires frequency" do
    subscription = Subscription.new(@valid_attributes.except(:frequency))
    assert_not subscription.valid?
    assert_includes subscription.errors[:frequency], "can't be blank"
  end

  test "requires valid frequency value" do
    subscription = Subscription.new(@valid_attributes.except(:frequency))
    subscription.frequency = "invalid_frequency"
    # With validate: true on enum, invalid values are rejected during validation
    assert_not subscription.valid?
    assert_includes subscription.errors[:frequency], "is not included in the list"
  end

  test "requires status" do
    subscription = Subscription.new(@valid_attributes.merge(status: nil))
    assert_not subscription.valid?
    assert_includes subscription.errors[:status], "can't be blank"
  end

  test "requires valid status value" do
    subscription = Subscription.new(@valid_attributes)
    subscription.status = "invalid_status"
    # With validate: true on enum, invalid values are rejected during validation
    assert_not subscription.valid?
    assert_includes subscription.errors[:status], "is not included in the list"
  end

  test "requires items_snapshot" do
    subscription = Subscription.new(@valid_attributes.merge(items_snapshot: nil))
    assert_not subscription.valid?
    assert_includes subscription.errors[:items_snapshot], "can't be blank"
  end

  test "requires shipping_snapshot" do
    subscription = Subscription.new(@valid_attributes.merge(shipping_snapshot: nil))
    assert_not subscription.valid?
    assert_includes subscription.errors[:shipping_snapshot], "can't be blank"
  end

  # Enum tests
  test "frequency enum includes all expected values" do
    expected_frequencies = %w[every_week every_two_weeks every_month every_3_months]
    assert_equal expected_frequencies.sort, Subscription.frequencies.keys.sort
  end

  test "status enum includes all expected values" do
    # Includes core states plus additional Stripe subscription states
    expected_statuses = %w[active cancelled incomplete incomplete_expired past_due paused trialing unpaid]
    assert_equal expected_statuses.sort, Subscription.statuses.keys.sort
  end

  test "frequency enum methods work" do
    @subscription.frequency = "every_month"
    assert @subscription.every_month?
    assert_not @subscription.every_week?
    assert_not @subscription.every_two_weeks?
    assert_not @subscription.every_3_months?
  end

  test "status enum methods work" do
    @subscription.status = "active"
    assert @subscription.active?
    assert_not @subscription.paused?
    assert_not @subscription.cancelled?
  end

  test "default status is active" do
    subscription = Subscription.new(@valid_attributes.except(:status))
    assert_equal "active", subscription.status
  end

  # Association tests
  test "belongs to user" do
    assert_respond_to @subscription, :user
    assert_equal users(:one), @subscription.user
  end

  test "has many orders" do
    assert_respond_to @subscription, :orders
  end

  test "destroying subscription nullifies order subscription_id" do
    subscription = Subscription.create!(@valid_attributes)

    # Create an order linked to this subscription
    order = Order.create!(
      user: @user,
      subscription: subscription,
      email: "test@example.com",
      stripe_session_id: "sess_sub_destroy_test",
      status: "pending",
      subtotal_amount: 100,
      vat_amount: 20,
      shipping_amount: 5,
      total_amount: 125,
      shipping_name: "Test User",
      shipping_address_line1: "123 Test St",
      shipping_city: "London",
      shipping_postal_code: "SW1A 1AA",
      shipping_country: "GB"
    )

    assert_equal subscription, order.subscription

    subscription.destroy!
    order.reload

    assert_nil order.subscription_id
  end

  # Scope tests
  test "active_subscriptions scope returns only active subscriptions" do
    active_subs = Subscription.active_subscriptions
    assert_includes active_subs, subscriptions(:active_monthly)
    assert_includes active_subs, subscriptions(:active_quarterly)
    assert_not_includes active_subs, subscriptions(:paused_subscription)
    assert_not_includes active_subs, subscriptions(:cancelled_subscription)
  end

  # Instance method tests
  test "next_billing_date returns current_period_end" do
    @subscription.current_period_end = 7.days.from_now
    assert_equal @subscription.current_period_end, @subscription.next_billing_date
  end

  test "cancel! sets status to cancelled and cancelled_at" do
    subscription = Subscription.create!(@valid_attributes)
    assert subscription.active?
    assert_nil subscription.cancelled_at

    subscription.cancel!

    assert subscription.cancelled?
    assert_not_nil subscription.cancelled_at
    assert subscription.cancelled_at <= Time.current
  end

  test "pause! sets status to paused" do
    subscription = Subscription.create!(@valid_attributes)
    assert subscription.active?

    subscription.pause!

    assert subscription.paused?
  end

  test "resume! sets status to active" do
    subscription = Subscription.create!(@valid_attributes.merge(status: "paused"))
    assert subscription.paused?

    subscription.resume!

    assert subscription.active?
  end

  test "items returns items from items_snapshot" do
    # Create a subscription with properly structured items_snapshot
    subscription = Subscription.create!(@valid_attributes)
    items = subscription.items
    assert_kind_of Array, items
    assert items.length > 0
    assert items.first.key?("product_name")
  end

  test "items returns empty array when items_snapshot has no items key" do
    subscription = Subscription.new(@valid_attributes.merge(items_snapshot: {}))
    assert_equal [], subscription.items
  end

  test "total_amount returns total from items_snapshot" do
    subscription = Subscription.create!(@valid_attributes)
    assert_equal BigDecimal("12.00"), subscription.total_amount
  end

  test "total_amount returns 0 when total is missing" do
    subscription = Subscription.new(@valid_attributes.merge(items_snapshot: { "items" => [] }))
    assert_equal 0, subscription.total_amount
  end

  test "frequency_display returns human-readable frequency" do
    @subscription.frequency = "every_week"
    assert_equal "Every week", @subscription.frequency_display

    @subscription.frequency = "every_two_weeks"
    assert_equal "Every two weeks", @subscription.frequency_display

    @subscription.frequency = "every_month"
    assert_equal "Every month", @subscription.frequency_display

    @subscription.frequency = "every_3_months"
    assert_equal "Every 3 months", @subscription.frequency_display
  end

  # User association tests
  test "user can have multiple subscriptions" do
    assert @user.subscriptions.count >= 1

    new_subscription = Subscription.create!(@valid_attributes)
    assert_includes @user.subscriptions.reload, new_subscription
  end

  test "destroying user destroys subscriptions" do
    # Create a new user with a subscription to test cascading delete
    test_user = User.create!(
      email_address: "subscription_test@example.com",
      password: "password123"
    )

    subscription = Subscription.create!(
      @valid_attributes.merge(
        user: test_user,
        stripe_subscription_id: "sub_cascade_test_#{SecureRandom.hex(4)}"
      )
    )

    assert_difference "Subscription.count", -1 do
      test_user.destroy!
    end
  end
end
