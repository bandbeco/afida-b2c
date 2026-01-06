require "application_system_test_case"

class ReorderScheduleSetupTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @order = orders(:one)
  end

  # ==========================================================================
  # US1: Flexibility Messaging Tests (T006-T007)
  # ==========================================================================

  test "flexibility messaging is visible without scrolling" do
    sign_in_as(@user)
    visit setup_reorder_schedules_path(order_id: @order.id)

    # Hero section with headline should be immediately visible
    assert_selector "h1", text: /Never Run Out/i, visible: true

    # Flexibility badges should be in the hero section
    assert_selector "[data-testid='flexibility-badges']", visible: true
    assert_text "Cancel anytime"
  end

  test "flexibility reassurance appears in hero and below CTA" do
    sign_in_as(@user)
    visit setup_reorder_schedules_path(order_id: @order.id)

    # Flexibility messaging in hero badges
    within "[data-testid='flexibility-badges']" do
      assert_text "Cancel anytime"
      assert_text "Skip"
      assert_text "Edit"
    end

    # Also appears in trust section below CTA
    within "[data-testid='trust-section']" do
      assert_text /cancel/i
    end
  end

  # ==========================================================================
  # US2: Frequency Selection Tests (T008-T009)
  # ==========================================================================

  test "frequency options display with Most popular badge on Every Month" do
    sign_in_as(@user)
    visit setup_reorder_schedules_path(order_id: @order.id)

    # Should have conversational label
    assert_text "How often do you need a refill?"

    # Every Month should have "Most popular" badge
    every_month_option = find("label", text: /Every Month/i)
    within(every_month_option) do
      assert_selector ".badge", text: /Most popular/i
    end
  end

  test "Every Month is pre-selected by default" do
    sign_in_as(@user)
    visit setup_reorder_schedules_path(order_id: @order.id)

    # Every Month radio should be checked
    every_month_radio = find("input[type='radio'][value='every_month']", visible: :all)
    assert every_month_radio.checked?
  end

  # ==========================================================================
  # US3: Order Summary Tests (T010-T011)
  # ==========================================================================

  test "compact order summary shows item count and total" do
    sign_in_as(@user)
    visit setup_reorder_schedules_path(order_id: @order.id)

    # Should show compact summary with format: "X items · £Y.YY per delivery"
    within "[data-testid='order-summary']" do
      assert_text(/\d+ items? · £[\d,]+\.\d{2} per delivery/i)
    end
  end

  test "order summary expands and collapses on click" do
    sign_in_as(@user)
    visit setup_reorder_schedules_path(order_id: @order.id)

    # Initially collapsed - full items list should be hidden
    assert_no_selector "[data-testid='order-items-expanded']", visible: true

    # Click to expand
    click_button "View items"

    # Now should see expanded items list
    assert_selector "[data-testid='order-items-expanded']", visible: true

    # Click to collapse
    click_button "Hide items"

    # Should be hidden again
    assert_no_selector "[data-testid='order-items-expanded']", visible: true
  end

  # ==========================================================================
  # US4: How It Works Tests (T012)
  # ==========================================================================

  test "how it works section displays 3 steps" do
    sign_in_as(@user)
    visit setup_reorder_schedules_path(order_id: @order.id)

    within "[data-testid='how-it-works']" do
      # Should have exactly 3 steps
      assert_selector "[data-testid='step']", count: 3

      # Steps should have meaningful content
      assert_text "Choose"
      assert_text "Remind"
      assert_text "Confirm"
    end
  end

  # ==========================================================================
  # US5: CTA & Trust Tests (T013-T014)
  # ==========================================================================

  test "CTA button reads Set Up Automatic Delivery" do
    sign_in_as(@user)
    visit setup_reorder_schedules_path(order_id: @order.id)

    # Rails form_with generates input[type='submit'], not button
    assert_selector "input[type='submit'][value='Set Up Automatic Delivery']"
  end

  test "trust messaging below CTA includes Stripe and cancel mention" do
    sign_in_as(@user)
    visit setup_reorder_schedules_path(order_id: @order.id)

    within "[data-testid='trust-section']" do
      # Should mention secure payment (Stripe)
      assert_text(/Stripe|secure/i)

      # Should mention cancel anytime
      assert_text(/cancel anytime/i)
    end
  end

  # ==========================================================================
  # Original Tests (preserved)
  # ==========================================================================

  test "user can access schedule setup from order confirmation" do
    sign_in_as(@user)

    # Visit order confirmation page
    visit confirmation_order_path(@order)

    # Should see setup schedule button
    assert_selector "a", text: /set up.*reorder/i
  end

  test "user can access schedule setup from order history" do
    sign_in_as(@user)

    # Visit order show page
    visit order_path(@order)

    # Should see schedule link (separate from reorder link)
    assert_selector "a", text: /schedule/i
  end

  test "user can view their reorder schedules" do
    sign_in_as(@user)

    # Create a schedule
    schedule = ReorderSchedule.create!(
      user: @user,
      frequency: :every_month,
      next_scheduled_date: 1.month.from_now.to_date,
      stripe_payment_method_id: "pm_test_123"
    )

    # Visit schedules index
    visit reorder_schedules_path

    assert_selector "h1", text: /Scheduled Reorders/i
    assert_text "Every Month"
  end

  test "user can view schedule details" do
    sign_in_as(@user)

    # Create a schedule with items
    schedule = ReorderSchedule.create!(
      user: @user,
      frequency: :every_month,
      next_scheduled_date: 1.month.from_now.to_date,
      stripe_payment_method_id: "pm_test_123"
    )

    variant = product_variants(:one)
    ReorderScheduleItem.create!(
      reorder_schedule: schedule,
      product_variant: variant,
      quantity: 2,
      price: variant.price
    )

    visit reorder_schedule_path(schedule)

    assert_text "Every Month"
    assert_text variant.name
  end

  private

  def sign_in_as(user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign In"

    # Wait for redirect and confirm user is logged in by checking for avatar
    assert_selector ".avatar-placeholder", wait: 5
  end
end
