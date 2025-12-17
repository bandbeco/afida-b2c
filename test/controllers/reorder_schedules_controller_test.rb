require "test_helper"
require "ostruct"

class ReorderSchedulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @order = orders(:one)
  end

  # ==========================================================================
  # Authentication
  # ==========================================================================

  test "requires authentication for index" do
    get reorder_schedules_url
    assert_redirected_to new_session_url
  end

  test "requires authentication for show" do
    schedule = create_schedule_for(@user)
    get reorder_schedule_url(schedule)
    assert_redirected_to new_session_url
  end

  test "requires authentication for setup" do
    get setup_reorder_schedules_url(order_id: @order.id)
    assert_redirected_to new_session_url
  end

  # ==========================================================================
  # Index
  # ==========================================================================

  test "index shows user schedules" do
    sign_in(@user)
    schedule = create_schedule_for(@user)

    get reorder_schedules_url

    assert_response :success
    assert_select "h1", /Scheduled Reorders/i
  end

  test "index does not show other users schedules" do
    sign_in(@user)
    other_user = users(:two)
    other_schedule = create_schedule_for(other_user)

    get reorder_schedules_url

    assert_response :success
    assert_no_match other_schedule.id.to_s, response.body
  end

  # ==========================================================================
  # Show
  # ==========================================================================

  test "show displays schedule details" do
    sign_in(@user)
    schedule = create_schedule_for(@user)

    get reorder_schedule_url(schedule)

    assert_response :success
  end

  test "show redirects for other users schedule" do
    sign_in(@user)
    other_user = users(:two)
    other_schedule = create_schedule_for(other_user)

    get reorder_schedule_url(other_schedule)

    assert_redirected_to reorder_schedules_url
    assert_equal "Schedule not found", flash[:alert]
  end

  # ==========================================================================
  # Setup Flow
  # ==========================================================================

  test "setup shows frequency selection form" do
    sign_in(@user)

    get setup_reorder_schedules_url(order_id: @order.id)

    assert_response :success
    assert_select "form"
  end

  test "setup redirects to add address when user has no addresses" do
    sign_in(@user)
    @user.addresses.destroy_all

    get setup_reorder_schedules_url(order_id: @order.id)

    assert_redirected_to new_account_address_path(return_to: setup_reorder_schedules_path(order_id: @order.id))
    assert_match(/address/, flash[:alert])
  end

  test "setup redirects for invalid order" do
    sign_in(@user)

    get setup_reorder_schedules_url(order_id: 999999)

    assert_redirected_to orders_url
    assert_equal "Order not found", flash[:alert]
  end

  test "setup redirects for other users order" do
    sign_in(@user)
    other_order = orders(:two)

    get setup_reorder_schedules_url(order_id: other_order.id)

    assert_redirected_to orders_url
    assert_equal "Order not found", flash[:alert]
  end

  # ==========================================================================
  # Create (redirects to Stripe)
  # ==========================================================================

  test "create redirects to Stripe checkout" do
    sign_in(@user)

    # Mock Stripe customer and session creation
    Stripe::Customer.stubs(:create).returns(OpenStruct.new(id: "cus_test_123"))
    Stripe::Customer.stubs(:retrieve).returns(OpenStruct.new(id: "cus_test_123"))
    Stripe::Checkout::Session.stubs(:create).returns(
      OpenStruct.new(id: "cs_test_session", url: "https://checkout.stripe.com/pay/cs_test_session")
    )

    post reorder_schedules_url, params: {
      reorder_schedule: { order_id: @order.id, frequency: "every_month" }
    }

    assert_redirected_to "https://checkout.stripe.com/pay/cs_test_session"
  end

  test "create redirects to add address when user has no addresses" do
    sign_in(@user)
    @user.addresses.destroy_all

    post reorder_schedules_url, params: {
      reorder_schedule: { order_id: @order.id, frequency: "every_month" }
    }

    assert_redirected_to new_account_address_path
    assert_match(/address/, flash[:alert])
  end

  # ==========================================================================
  # Setup Success (after Stripe redirect)
  # ==========================================================================

  test "setup_success creates schedule and redirects to show" do
    sign_in(@user)

    # Mock Stripe session retrieval with nested payment_method object
    card = OpenStruct.new(brand: "visa", last4: "4242")
    payment_method = OpenStruct.new(id: "pm_test_456", card: card)
    setup_intent = OpenStruct.new(payment_method: payment_method)
    session = OpenStruct.new(
      id: "cs_test_session",
      setup_intent: setup_intent,
      metadata: {
        "order_id" => @order.id.to_s,
        "user_id" => @user.id.to_s,
        "frequency" => "every_month"
      }
    )
    Stripe::Checkout::Session.stubs(:retrieve).returns(session)

    assert_difference "ReorderSchedule.count", 1 do
      get setup_success_reorder_schedules_url(session_id: "cs_test_session")
    end

    schedule = ReorderSchedule.last
    assert_redirected_to reorder_schedule_url(schedule)
    assert_equal "every_month", schedule.frequency
    assert_equal @user, schedule.user
  end

  # ==========================================================================
  # Setup Cancel
  # ==========================================================================

  test "setup_cancel redirects to order with flash message" do
    sign_in(@user)

    get setup_cancel_reorder_schedules_url

    assert_redirected_to orders_url
    assert_equal "Reorder schedule setup was cancelled.", flash[:notice]
  end

  # ==========================================================================
  # Pause Action
  # ==========================================================================

  test "pause requires authentication" do
    schedule = create_schedule_for(@user)
    patch pause_reorder_schedule_url(schedule)
    assert_redirected_to new_session_url
  end

  test "pause changes schedule status to paused" do
    sign_in(@user)
    schedule = create_schedule_for(@user)
    assert_equal "active", schedule.status

    patch pause_reorder_schedule_url(schedule)

    schedule.reload
    assert_equal "paused", schedule.status
    assert_redirected_to reorder_schedule_url(schedule)
  end

  test "pause sets flash notice" do
    sign_in(@user)
    schedule = create_schedule_for(@user)

    patch pause_reorder_schedule_url(schedule)

    assert flash[:notice].present?
    assert_match(/paused/i, flash[:notice])
  end

  test "pause does not allow pausing other users schedule" do
    sign_in(@user)
    other_user = users(:two)
    other_schedule = create_schedule_for(other_user)

    patch pause_reorder_schedule_url(other_schedule)

    assert_redirected_to reorder_schedules_url
    other_schedule.reload
    assert_equal "active", other_schedule.status
  end

  test "pause handles already paused schedule gracefully" do
    sign_in(@user)
    schedule = create_schedule_for(@user)
    schedule.pause!

    patch pause_reorder_schedule_url(schedule)

    # Should still redirect, no error
    assert_redirected_to reorder_schedule_url(schedule)
  end

  # ==========================================================================
  # Resume Action
  # ==========================================================================

  test "resume requires authentication" do
    schedule = create_schedule_for(@user)
    schedule.pause!
    patch resume_reorder_schedule_url(schedule)
    assert_redirected_to new_session_url
  end

  test "resume changes schedule status to active" do
    sign_in(@user)
    schedule = create_schedule_for(@user)
    schedule.pause!
    assert_equal "paused", schedule.status

    patch resume_reorder_schedule_url(schedule)

    schedule.reload
    assert_equal "active", schedule.status
    assert_redirected_to reorder_schedule_url(schedule)
  end

  test "resume sets flash notice" do
    sign_in(@user)
    schedule = create_schedule_for(@user)
    schedule.pause!

    patch resume_reorder_schedule_url(schedule)

    assert flash[:notice].present?
    assert_match(/resumed/i, flash[:notice])
  end

  test "resume with asap calculates next date from today" do
    sign_in(@user)
    schedule = create_schedule_for(@user)
    schedule.update!(next_scheduled_date: 2.months.ago.to_date)
    schedule.pause!

    patch resume_reorder_schedule_url(schedule), params: { resume_type: "asap" }

    schedule.reload
    assert_equal "active", schedule.status
    # Next date should be one month from today
    assert_equal Date.current + 1.month, schedule.next_scheduled_date
  end

  test "resume with original_schedule advances until future date" do
    sign_in(@user)
    schedule = create_schedule_for(@user)
    original_date = 2.months.ago.to_date
    schedule.update!(next_scheduled_date: original_date)
    schedule.pause!

    patch resume_reorder_schedule_url(schedule), params: { resume_type: "original_schedule" }

    schedule.reload
    assert_equal "active", schedule.status
    # Should advance the original schedule forward until it's in the future
    # 2 months ago + 3 months = 1 month from now
    expected_date = original_date + 3.months
    assert_equal expected_date, schedule.next_scheduled_date
    assert schedule.next_scheduled_date > Date.current
  end

  test "resume defaults to asap when no resume_type provided" do
    sign_in(@user)
    schedule = create_schedule_for(@user)
    schedule.update!(next_scheduled_date: 2.months.ago.to_date)
    schedule.pause!

    patch resume_reorder_schedule_url(schedule)

    schedule.reload
    # Default is asap, so should be one month from today
    assert_equal Date.current + 1.month, schedule.next_scheduled_date
  end

  test "resume does not allow resuming other users schedule" do
    sign_in(@user)
    other_user = users(:two)
    other_schedule = create_schedule_for(other_user)
    other_schedule.pause!

    patch resume_reorder_schedule_url(other_schedule)

    assert_redirected_to reorder_schedules_url
    other_schedule.reload
    assert_equal "paused", other_schedule.status
  end

  # ==========================================================================
  # Destroy (Cancel) Action
  # ==========================================================================

  test "destroy requires authentication" do
    schedule = create_schedule_for(@user)
    delete reorder_schedule_url(schedule)
    assert_redirected_to new_session_url
  end

  test "destroy changes schedule status to cancelled" do
    sign_in(@user)
    schedule = create_schedule_for(@user)

    delete reorder_schedule_url(schedule)

    schedule.reload
    assert_equal "cancelled", schedule.status
    assert_redirected_to reorder_schedules_url
  end

  test "destroy sets flash notice" do
    sign_in(@user)
    schedule = create_schedule_for(@user)

    delete reorder_schedule_url(schedule)

    assert flash[:notice].present?
    assert_match(/cancelled/i, flash[:notice])
  end

  test "destroy does not allow cancelling other users schedule" do
    sign_in(@user)
    other_user = users(:two)
    other_schedule = create_schedule_for(other_user)

    delete reorder_schedule_url(other_schedule)

    assert_redirected_to reorder_schedules_url
    other_schedule.reload
    assert_equal "active", other_schedule.status
  end

  # ==========================================================================
  # Edit Action
  # ==========================================================================

  test "edit requires authentication" do
    schedule = create_schedule_for(@user)
    get edit_reorder_schedule_url(schedule)
    assert_redirected_to new_session_url
  end

  test "edit shows schedule edit form" do
    sign_in(@user)
    schedule = create_schedule_for(@user)

    get edit_reorder_schedule_url(schedule)

    assert_response :success
    assert_select "form"
  end

  test "edit does not allow editing other users schedule" do
    sign_in(@user)
    other_user = users(:two)
    other_schedule = create_schedule_for(other_user)

    get edit_reorder_schedule_url(other_schedule)

    assert_redirected_to reorder_schedules_url
    assert_equal "Schedule not found", flash[:alert]
  end

  # ==========================================================================
  # Update Action (Frequency)
  # ==========================================================================

  test "update requires authentication" do
    schedule = create_schedule_for(@user)
    patch reorder_schedule_url(schedule), params: { reorder_schedule: { frequency: "every_week" } }
    assert_redirected_to new_session_url
  end

  test "update changes schedule frequency" do
    sign_in(@user)
    schedule = create_schedule_for(@user)
    assert_equal "every_month", schedule.frequency

    patch reorder_schedule_url(schedule), params: {
      reorder_schedule: { frequency: "every_week" }
    }

    schedule.reload
    assert_equal "every_week", schedule.frequency
    assert_redirected_to reorder_schedule_url(schedule)
  end

  test "update sets flash notice on success" do
    sign_in(@user)
    schedule = create_schedule_for(@user)

    patch reorder_schedule_url(schedule), params: {
      reorder_schedule: { frequency: "every_two_weeks" }
    }

    assert flash[:notice].present?
    assert_match(/updated/i, flash[:notice])
  end

  test "update does not allow updating other users schedule" do
    sign_in(@user)
    other_user = users(:two)
    other_schedule = create_schedule_for(other_user)

    patch reorder_schedule_url(other_schedule), params: {
      reorder_schedule: { frequency: "every_week" }
    }

    assert_redirected_to reorder_schedules_url
    other_schedule.reload
    assert_equal "every_month", other_schedule.frequency
  end

  test "update rejects invalid frequency" do
    sign_in(@user)
    schedule = create_schedule_for(@user)

    patch reorder_schedule_url(schedule), params: {
      reorder_schedule: { frequency: "invalid_frequency" }
    }

    assert_response :unprocessable_entity
    schedule.reload
    assert_equal "every_month", schedule.frequency
  end

  # ==========================================================================
  # Update Action (Items via nested attributes)
  # ==========================================================================

  test "update modifies schedule item quantity" do
    sign_in(@user)
    schedule = create_schedule_with_items_for(@user)
    item = schedule.reorder_schedule_items.first

    patch reorder_schedule_url(schedule), params: {
      reorder_schedule: {
        reorder_schedule_items_attributes: {
          "0" => { id: item.id, quantity: 10 }
        }
      }
    }

    item.reload
    assert_equal 10, item.quantity
    assert_redirected_to reorder_schedule_url(schedule)
  end

  test "update removes schedule item with _destroy" do
    sign_in(@user)
    schedule = create_schedule_with_items_for(@user)
    item = schedule.reorder_schedule_items.first

    assert_difference "ReorderScheduleItem.count", -1 do
      patch reorder_schedule_url(schedule), params: {
        reorder_schedule: {
          reorder_schedule_items_attributes: {
            "0" => { id: item.id, _destroy: "1" }
          }
        }
      }
    end

    assert_redirected_to reorder_schedule_url(schedule)
  end

  test "update adds new schedule item" do
    sign_in(@user)
    schedule = create_schedule_for(@user)
    product_variant = product_variants(:one)

    assert_difference "ReorderScheduleItem.count", 1 do
      patch reorder_schedule_url(schedule), params: {
        reorder_schedule: {
          reorder_schedule_items_attributes: {
            "0" => { product_variant_id: product_variant.id, quantity: 5, price: product_variant.price }
          }
        }
      }
    end

    new_item = schedule.reorder_schedule_items.last
    assert_equal product_variant.id, new_item.product_variant_id
    assert_equal 5, new_item.quantity
  end

  # ==========================================================================
  # Skip Next Action
  # ==========================================================================

  test "skip_next requires authentication" do
    schedule = create_schedule_for(@user)
    patch skip_next_reorder_schedule_url(schedule)
    assert_redirected_to new_session_url
  end

  test "skip_next advances schedule to next date" do
    sign_in(@user)
    schedule = create_schedule_for(@user)
    original_date = schedule.next_scheduled_date

    patch skip_next_reorder_schedule_url(schedule)

    schedule.reload
    assert schedule.next_scheduled_date > original_date
    assert_redirected_to reorder_schedule_url(schedule)
  end

  test "skip_next sets flash notice" do
    sign_in(@user)
    schedule = create_schedule_for(@user)

    patch skip_next_reorder_schedule_url(schedule)

    assert flash[:notice].present?
    assert_match(/skipped/i, flash[:notice])
  end

  test "skip_next expires any pending order for the schedule" do
    sign_in(@user)
    schedule = create_schedule_for(@user)
    pending_order = schedule.pending_orders.create!(
      scheduled_for: schedule.next_scheduled_date,
      items_snapshot: { "items" => [], "total" => "0.00" }
    )
    assert pending_order.pending?

    patch skip_next_reorder_schedule_url(schedule)

    pending_order.reload
    assert pending_order.expired?
  end

  test "skip_next does not allow skipping other users schedule" do
    sign_in(@user)
    other_user = users(:two)
    other_schedule = create_schedule_for(other_user)
    original_date = other_schedule.next_scheduled_date

    patch skip_next_reorder_schedule_url(other_schedule)

    assert_redirected_to reorder_schedules_url
    other_schedule.reload
    assert_equal original_date, other_schedule.next_scheduled_date
  end

  test "skip_next cannot skip paused schedule" do
    sign_in(@user)
    schedule = create_schedule_for(@user)
    schedule.pause!
    original_date = schedule.next_scheduled_date

    patch skip_next_reorder_schedule_url(schedule)

    schedule.reload
    # Should not advance when paused
    assert_equal original_date, schedule.next_scheduled_date
    assert flash[:alert].present?
  end

  private

  def sign_in(user)
    post session_url, params: {
      email_address: user.email_address,
      password: "password"
    }
  end

  def create_schedule_for(user)
    ReorderSchedule.create!(
      user: user,
      frequency: :every_month,
      next_scheduled_date: 1.month.from_now.to_date,
      stripe_payment_method_id: "pm_test_#{SecureRandom.hex(4)}"
    )
  end

  def create_schedule_with_items_for(user)
    schedule = create_schedule_for(user)
    product_variant = product_variants(:one)
    schedule.reorder_schedule_items.create!(
      product_variant: product_variant,
      quantity: 2,
      price: product_variant.price
    )
    schedule
  end
end
