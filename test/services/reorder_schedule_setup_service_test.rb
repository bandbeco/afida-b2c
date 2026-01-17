require "test_helper"
require "ostruct"

class ReorderScheduleSetupServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @order = orders(:one)
    # Ensure order has items
    @order_item = order_items(:one)
  end

  # ==========================================================================
  # Create Stripe Setup Session
  # ==========================================================================

  test "create_stripe_session creates setup mode session for user" do
    service = ReorderScheduleSetupService.new(user: @user)

    # Mock Stripe calls
    Stripe::Customer.stubs(:create).returns(OpenStruct.new(id: "cus_test_123"))
    Stripe::Customer.stubs(:retrieve).returns(OpenStruct.new(id: "cus_test_123"))

    success_url = "https://example.com/success?session_id={CHECKOUT_SESSION_ID}"
    cancel_url = "https://example.com/cancel"

    Stripe::Checkout::Session.expects(:create).with(
      mode: "setup",
      customer: "cus_test_123",
      payment_method_types: [ "card" ],
      success_url: success_url,
      cancel_url: cancel_url,
      metadata: has_entries(order_id: @order.id.to_s, user_id: @user.id.to_s)
    ).returns(OpenStruct.new(id: "cs_test_session", url: "https://checkout.stripe.com/..."))

    result = service.create_stripe_session(
      order: @order,
      success_url: success_url,
      cancel_url: cancel_url
    )

    assert result.success?
    assert_equal "cs_test_session", result.session.id
  end

  test "create_stripe_session returns error on Stripe failure" do
    service = ReorderScheduleSetupService.new(user: @user)

    Stripe::Customer.stubs(:create).returns(OpenStruct.new(id: "cus_test_123"))
    Stripe::Customer.stubs(:retrieve).returns(OpenStruct.new(id: "cus_test_123"))
    Stripe::Checkout::Session.stubs(:create).raises(Stripe::StripeError.new("Network error"))

    result = service.create_stripe_session(
      order: @order,
      success_url: "https://example.com/success",
      cancel_url: "https://example.com/cancel"
    )

    assert_not result.success?
    assert_includes result.error, "Network error"
  end

  # ==========================================================================
  # Complete Setup from Stripe Session
  # ==========================================================================

  test "complete_setup creates schedule from stripe session" do
    service = ReorderScheduleSetupService.new(user: @user)

    # Mock Stripe session retrieval with proper payment method structure
    card = OpenStruct.new(brand: "visa", last4: "4242")
    payment_method = OpenStruct.new(id: "pm_test_456", card: card)
    setup_intent = OpenStruct.new(payment_method: payment_method)
    session = OpenStruct.new(
      id: "cs_test_session",
      setup_intent: setup_intent,
      metadata: { "order_id" => @order.id.to_s, "user_id" => @user.id.to_s, "frequency" => "every_month" }
    )
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    result = service.complete_setup(session_id: "cs_test_session", frequency: "every_month")

    assert result.success?
    assert_instance_of ReorderSchedule, result.schedule
    assert_equal @user, result.schedule.user
    assert_equal "every_month", result.schedule.frequency
    assert_equal "pm_test_456", result.schedule.stripe_payment_method_id
    assert_equal "active", result.schedule.status
  end

  test "complete_setup creates schedule items from order items" do
    service = ReorderScheduleSetupService.new(user: @user)

    card = OpenStruct.new(brand: "visa", last4: "4242")
    payment_method = OpenStruct.new(id: "pm_test_456", card: card)
    setup_intent = OpenStruct.new(payment_method: payment_method)
    session = OpenStruct.new(
      id: "cs_test_session",
      setup_intent: setup_intent,
      metadata: { "order_id" => @order.id.to_s, "user_id" => @user.id.to_s, "frequency" => "every_month" }
    )
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    result = service.complete_setup(session_id: "cs_test_session", frequency: "every_month")

    assert result.success?
    assert result.schedule.reorder_schedule_items.count > 0

    schedule_item = result.schedule.reorder_schedule_items.first
    assert_equal @order_item.product_id, schedule_item.product_id
    assert_equal @order_item.quantity, schedule_item.quantity
  end

  test "complete_setup sets next_scheduled_date based on frequency" do
    service = ReorderScheduleSetupService.new(user: @user)

    card = OpenStruct.new(brand: "visa", last4: "4242")
    payment_method = OpenStruct.new(id: "pm_test_456", card: card)
    setup_intent = OpenStruct.new(payment_method: payment_method)
    session = OpenStruct.new(
      id: "cs_test_session",
      setup_intent: setup_intent,
      metadata: { "order_id" => @order.id.to_s, "user_id" => @user.id.to_s, "frequency" => "every_month" }
    )
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    freeze_time do
      result = service.complete_setup(session_id: "cs_test_session", frequency: "every_month")

      assert_equal Date.current + 1.month, result.schedule.next_scheduled_date
    end
  end

  test "complete_setup returns error for invalid session" do
    service = ReorderScheduleSetupService.new(user: @user)

    Stripe::Checkout::Session.stubs(:retrieve).raises(Stripe::InvalidRequestError.new("Invalid session", nil))

    result = service.complete_setup(session_id: "invalid_session", frequency: "every_month")

    assert_not result.success?
    assert_includes result.error, "Invalid session"
  end

  # ==========================================================================
  # Frequency Calculation
  # ==========================================================================

  test "calculates next date for every_week" do
    service = ReorderScheduleSetupService.new(user: @user)

    freeze_time do
      next_date = service.send(:calculate_next_date, "every_week")
      assert_equal Date.current + 1.week, next_date
    end
  end

  test "calculates next date for every_two_weeks" do
    service = ReorderScheduleSetupService.new(user: @user)

    freeze_time do
      next_date = service.send(:calculate_next_date, "every_two_weeks")
      assert_equal Date.current + 2.weeks, next_date
    end
  end

  test "calculates next date for every_month" do
    service = ReorderScheduleSetupService.new(user: @user)

    freeze_time do
      next_date = service.send(:calculate_next_date, "every_month")
      assert_equal Date.current + 1.month, next_date
    end
  end

  test "calculates next date for every_3_months" do
    service = ReorderScheduleSetupService.new(user: @user)

    freeze_time do
      next_date = service.send(:calculate_next_date, "every_3_months")
      assert_equal Date.current + 3.months, next_date
    end
  end

  # ==========================================================================
  # STRUCTURED EVENT EMISSION TESTS (US4: Scheduled Reorders)
  # ==========================================================================

  test "emits reorder.scheduled event when schedule is created" do
    service = ReorderScheduleSetupService.new(user: @user)

    card = OpenStruct.new(brand: "visa", last4: "4242")
    payment_method = OpenStruct.new(id: "pm_test_456", card: card)
    setup_intent = OpenStruct.new(payment_method: payment_method)
    session = OpenStruct.new(
      id: "cs_test_session",
      setup_intent: setup_intent,
      metadata: { "order_id" => @order.id.to_s, "user_id" => @user.id.to_s, "frequency" => "every_month" }
    )
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    assert_event_reported("reorder.scheduled") do
      service.complete_setup(session_id: "cs_test_session", frequency: "every_month")
    end
  end
end
