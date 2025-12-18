require "application_system_test_case"

class ReorderScheduleSetupTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @order = orders(:one)
  end

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

    # Wait for redirect after successful sign-in
    assert_current_path root_path
  end
end
