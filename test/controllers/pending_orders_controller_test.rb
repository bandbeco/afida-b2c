require "test_helper"
require "ostruct"

class PendingOrdersControllerTest < ActionDispatch::IntegrationTest
  include StripeTestHelper

  setup do
    @user = users(:one)
    @user.update!(stripe_customer_id: "cus_test_123")
    @product_variant = product_variants(:one)

    @schedule = ReorderSchedule.create!(
      user: @user,
      frequency: :every_month,
      status: :active,
      next_scheduled_date: Date.current,
      stripe_payment_method_id: "pm_test_456"
    )

    @pending_order = PendingOrder.create!(
      reorder_schedule: @schedule,
      scheduled_for: Date.current,
      items_snapshot: {
        "items" => [
          {
            "product_variant_id" => @product_variant.id,
            "product_name" => "Test Product",
            "variant_name" => "Pack of 500",
            "quantity" => 2,
            "price" => "10.00",
            "available" => true
          }
        ],
        "subtotal" => "20.00",
        "vat" => "4.00",
        "shipping" => "0.00",
        "total" => "24.00",
        "unavailable_items" => []
      }
    )

    @confirm_token = @pending_order.confirmation_token
    @edit_token = @pending_order.edit_token
  end

  # ==========================================================================
  # Show Action (Review Page)
  # ==========================================================================

  test "show requires valid token" do
    get pending_order_path(@pending_order), params: { token: "invalid_token" }
    assert_response :not_found
  end

  test "show accepts valid confirmation token" do
    get pending_order_path(@pending_order), params: { token: @confirm_token }
    assert_response :success
  end

  test "show rejects edit token" do
    # Edit token should NOT work for show action (requires confirmation token)
    get pending_order_path(@pending_order), params: { token: @edit_token }
    assert_response :not_found
  end

  test "show displays order summary" do
    get pending_order_path(@pending_order), params: { token: @confirm_token }

    assert_response :success
    assert_select "h1", /Your Order is Ready/i
    assert_select "h2", /Order Items/i
    assert_select "h2", /Order Summary/i
  end

  test "show displays confirm button" do
    get pending_order_path(@pending_order), params: { token: @confirm_token }

    assert_response :success
    assert_select "button", /Confirm/i
  end

  test "show displays payment method info" do
    @schedule.update!(card_brand: "visa", card_last4: "4242")

    get pending_order_path(@pending_order), params: { token: @confirm_token }

    assert_response :success
    assert_match /Visa/i, response.body
    assert_match /4242/, response.body
  end

  test "show returns 410 for already confirmed order" do
    @pending_order.update!(status: :confirmed, confirmed_at: Time.current)

    get pending_order_path(@pending_order), params: { token: @confirm_token }

    assert_response :gone
  end

  test "show returns 410 for expired order" do
    @pending_order.expire!

    get pending_order_path(@pending_order), params: { token: @confirm_token }

    assert_response :gone
  end

  test "show displays unavailable items warning" do
    @pending_order.update!(
      items_snapshot: @pending_order.items_snapshot.merge(
        "unavailable_items" => [
          { "product_name" => "Old Product", "reason" => "Discontinued" }
        ]
      )
    )

    get pending_order_path(@pending_order), params: { token: @confirm_token }

    assert_response :success
    assert_match /no longer available/i, response.body
    assert_match /Old Product/i, response.body
  end

  # ==========================================================================
  # Token Authentication
  # ==========================================================================

  test "confirm requires valid token" do
    post confirm_pending_order_path(@pending_order), params: { token: "invalid_token" }
    assert_response :not_found
  end

  test "confirm accepts valid confirmation token" do
    mock_successful_payment

    post confirm_pending_order_path(@pending_order), params: { token: @confirm_token }
    assert_response :redirect
  end

  test "confirm rejects edit token" do
    # Edit token should NOT work for confirm action
    post confirm_pending_order_path(@pending_order), params: { token: @edit_token }
    assert_response :not_found
  end

  test "expired token returns 404" do
    # Token expires after 72 hours
    travel 4.days do
      post confirm_pending_order_path(@pending_order), params: { token: @confirm_token }
      assert_response :not_found
    end
  end

  # ==========================================================================
  # Confirm Action - Success
  # ==========================================================================

  test "confirm creates order and redirects to confirmation page" do
    mock_successful_payment

    assert_difference "Order.count", 1 do
      post confirm_pending_order_path(@pending_order), params: { token: @confirm_token }
    end

    assert_redirected_to confirmation_order_path(Order.last)
  end

  test "confirm sets success flash message" do
    mock_successful_payment

    post confirm_pending_order_path(@pending_order), params: { token: @confirm_token }

    assert flash[:notice].present?
  end

  test "confirm marks pending order as confirmed" do
    mock_successful_payment

    post confirm_pending_order_path(@pending_order), params: { token: @confirm_token }

    @pending_order.reload
    assert @pending_order.confirmed?
  end

  # ==========================================================================
  # Confirm Action - Failures
  # ==========================================================================

  test "confirm returns 410 for already confirmed order" do
    @pending_order.update!(status: :confirmed, confirmed_at: Time.current)

    post confirm_pending_order_path(@pending_order), params: { token: @confirm_token }

    assert_response :gone
  end

  test "confirm returns 410 for expired order" do
    @pending_order.expire!

    post confirm_pending_order_path(@pending_order), params: { token: @confirm_token }

    assert_response :gone
  end

  test "confirm shows error on payment failure" do
    Stripe::PaymentIntent.stubs(:create).raises(
      Stripe::CardError.new("Your card was declined", "card_declined", code: "card_declined")
    )

    post confirm_pending_order_path(@pending_order), params: { token: @confirm_token }

    assert_response :unprocessable_entity
    assert flash[:alert].present?
  end

  test "confirm handles empty pending order" do
    @pending_order.update!(items_snapshot: { "items" => [], "total" => "0.00" })

    post confirm_pending_order_path(@pending_order), params: { token: @confirm_token }

    assert_response :unprocessable_entity
  end

  # ==========================================================================
  # Edit Action
  # ==========================================================================

  test "edit requires valid edit token" do
    get edit_pending_order_path(@pending_order), params: { token: "invalid_token" }
    assert_response :not_found
  end

  test "edit accepts valid edit token" do
    get edit_pending_order_path(@pending_order), params: { token: @edit_token }
    assert_response :success
  end

  test "edit rejects confirmation token" do
    # Confirmation token should NOT work for edit action
    get edit_pending_order_path(@pending_order), params: { token: @confirm_token }
    assert_response :not_found
  end

  test "edit displays pending order items" do
    get edit_pending_order_path(@pending_order), params: { token: @edit_token }

    assert_response :success
    assert_select "form"
  end

  test "edit returns 410 for already confirmed order" do
    @pending_order.update!(status: :confirmed, confirmed_at: Time.current)

    get edit_pending_order_path(@pending_order), params: { token: @edit_token }

    assert_response :gone
  end

  test "edit returns 410 for expired order" do
    @pending_order.expire!

    get edit_pending_order_path(@pending_order), params: { token: @edit_token }

    assert_response :gone
  end

  # ==========================================================================
  # Update Action
  # ==========================================================================

  test "update requires valid edit token" do
    patch pending_order_path(@pending_order), params: {
      token: "invalid_token",
      pending_order: { items: [] }
    }
    assert_response :not_found
  end

  test "update modifies pending order items" do
    patch pending_order_path(@pending_order), params: {
      token: @edit_token,
      pending_order: {
        items: [
          { product_variant_id: @product_variant.id, quantity: 5 }
        ]
      }
    }

    assert_response :redirect

    @pending_order.reload
    item = @pending_order.items.first
    assert_equal 5, item["quantity"]
  end

  test "update recalculates totals" do
    patch pending_order_path(@pending_order), params: {
      token: @edit_token,
      pending_order: {
        items: [
          { product_variant_id: @product_variant.id, quantity: 10 }
        ]
      }
    }

    @pending_order.reload
    # 10 items at current variant price (9.99) = 99.90 subtotal
    expected_subtotal = @product_variant.price * 10
    assert_equal expected_subtotal.round(2), @pending_order.subtotal_amount.round(2)
  end

  test "update rejects zero quantity" do
    patch pending_order_path(@pending_order), params: {
      token: @edit_token,
      pending_order: {
        items: [
          { product_variant_id: @product_variant.id, quantity: 0 }
        ]
      }
    }

    assert_response :unprocessable_entity
  end

  test "update allows removing items" do
    # Add second item to pending order
    @pending_order.update!(
      items_snapshot: {
        "items" => [
          { "product_variant_id" => @product_variant.id, "quantity" => 2, "price" => "10.00", "available" => true },
          { "product_variant_id" => product_variants(:two).id, "quantity" => 1, "price" => "15.00", "available" => true }
        ],
        "subtotal" => "35.00",
        "vat" => "7.00",
        "total" => "42.00"
      }
    )

    # Update with only one item (removing the second)
    patch pending_order_path(@pending_order), params: {
      token: @edit_token,
      pending_order: {
        items: [
          { product_variant_id: @product_variant.id, quantity: 2 }
        ]
      }
    }

    @pending_order.reload
    assert_equal 1, @pending_order.items.count
  end

  test "update rejects empty items list" do
    patch pending_order_path(@pending_order), params: {
      token: @edit_token,
      pending_order: { items: [] }
    }

    assert_response :unprocessable_entity
  end

  # ==========================================================================
  # SGID Token Verification
  # ==========================================================================

  test "token is tied to specific pending order" do
    other_pending_order = PendingOrder.create!(
      reorder_schedule: @schedule,
      scheduled_for: Date.tomorrow,
      items_snapshot: { "items" => [], "total" => "0.00" }
    )

    # Try to use token from one pending order on another
    post confirm_pending_order_path(other_pending_order), params: { token: @confirm_token }

    # Should fail because token is for @pending_order, not other_pending_order
    assert_response :not_found
  end

  # ==========================================================================
  # Update Payment Method Action
  # ==========================================================================

  test "update_payment_method requires valid token" do
    post update_payment_method_pending_order_path(@pending_order), params: { token: "invalid_token" }
    assert_response :not_found
  end

  test "update_payment_method accepts valid confirmation token" do
    stub_stripe_session_create

    post update_payment_method_pending_order_path(@pending_order), params: { token: @confirm_token }

    # Should redirect to Stripe Checkout
    assert_response :redirect
    assert_match %r{checkout\.stripe\.com}, response.location
  end

  test "update_payment_method rejects edit token" do
    post update_payment_method_pending_order_path(@pending_order), params: { token: @edit_token }
    assert_response :not_found
  end

  test "update_payment_method returns 410 for already confirmed order" do
    @pending_order.update!(status: :confirmed, confirmed_at: Time.current)

    post update_payment_method_pending_order_path(@pending_order), params: { token: @confirm_token }

    assert_response :gone
  end

  test "update_payment_method returns 410 for expired order" do
    @pending_order.expire!

    post update_payment_method_pending_order_path(@pending_order), params: { token: @confirm_token }

    assert_response :gone
  end

  test "update_payment_method creates stripe customer if not exists" do
    @user.update!(stripe_customer_id: nil)
    stub_stripe_customer_create(id: "cus_new_test_123")
    stub_stripe_session_create

    post update_payment_method_pending_order_path(@pending_order), params: { token: @confirm_token }

    @user.reload
    assert @user.stripe_customer_id.present?
  end

  # ==========================================================================
  # Update Payment Method Success Action
  # ==========================================================================

  test "update_payment_method_success requires valid token" do
    get update_payment_method_success_pending_order_path(@pending_order), params: {
      token: "invalid_token",
      session_id: "sess_test_123"
    }
    assert_response :not_found
  end

  test "update_payment_method_success requires session_id" do
    get update_payment_method_success_pending_order_path(@pending_order), params: { token: @confirm_token }

    assert_response :redirect
    assert_match /Invalid payment session/, flash[:alert]
  end

  test "update_payment_method_success updates schedule payment method" do
    # Stub a setup mode session that can be retrieved
    session = stub_stripe_session_retrieve(mode: "setup")
    mock_successful_payment

    get update_payment_method_success_pending_order_path(@pending_order), params: {
      token: @confirm_token,
      session_id: session.id
    }

    @schedule.reload
    assert_equal "visa", @schedule.card_brand
    assert_equal "4242", @schedule.card_last4
    assert @schedule.stripe_payment_method_id.start_with?("pm_test_")
  end

  test "update_payment_method_success confirms order after updating payment method" do
    session = stub_stripe_session_retrieve(mode: "setup")
    mock_successful_payment

    assert_difference "Order.count", 1 do
      get update_payment_method_success_pending_order_path(@pending_order), params: {
        token: @confirm_token,
        session_id: session.id
      }
    end

    assert_redirected_to confirmation_order_path(Order.last)
    assert_match /Payment method updated/, flash[:notice]
  end

  test "update_payment_method_success shows error if charge fails after card update" do
    session = stub_stripe_session_retrieve(mode: "setup")
    Stripe::PaymentIntent.stubs(:create).raises(
      Stripe::CardError.new("Your card was declined", "card_declined", code: "card_declined")
    )

    get update_payment_method_success_pending_order_path(@pending_order), params: {
      token: @confirm_token,
      session_id: session.id
    }

    # Should still update the payment method
    @schedule.reload
    assert_equal "visa", @schedule.card_brand

    # But show error page for failed charge
    assert_response :unprocessable_entity
    assert flash[:alert].present?
  end

  private

  def mock_successful_payment
    payment_intent = OpenStruct.new(
      id: "pi_test_#{SecureRandom.hex(8)}",
      status: "succeeded"
    )
    Stripe::PaymentIntent.stubs(:create).returns(payment_intent)
  end
end
