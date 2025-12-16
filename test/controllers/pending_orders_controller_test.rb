require "test_helper"
require "ostruct"

class PendingOrdersControllerTest < ActionDispatch::IntegrationTest
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
    # Create token that expires immediately
    travel 8.days do
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

  private

  def mock_successful_payment
    payment_intent = OpenStruct.new(
      id: "pi_test_#{SecureRandom.hex(8)}",
      status: "succeeded"
    )
    Stripe::PaymentIntent.stubs(:create).returns(payment_intent)
  end
end
