require "test_helper"
require "ostruct"

class PendingOrderConfirmationServiceTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
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
  end

  # ==========================================================================
  # Successful Confirmation
  # ==========================================================================

  test "confirm! charges payment and creates order" do
    mock_successful_payment

    service = PendingOrderConfirmationService.new(@pending_order)

    assert_difference "Order.count", 1 do
      result = service.confirm!
      assert result.success?
    end
  end

  test "confirm! creates order with correct amounts" do
    mock_successful_payment

    service = PendingOrderConfirmationService.new(@pending_order)
    result = service.confirm!

    order = result.order
    assert_equal 20.00, order.subtotal_amount
    assert_equal 4.00, order.vat_amount
    assert_equal 24.00, order.total_amount
  end

  test "confirm! creates order items from snapshot" do
    mock_successful_payment

    service = PendingOrderConfirmationService.new(@pending_order)

    assert_difference "OrderItem.count", 1 do
      result = service.confirm!
    end

    order = Order.last
    order_item = order.order_items.first

    assert_equal @product_variant.id, order_item.product_variant_id
    assert_equal 2, order_item.quantity
    assert_equal 10.00, order_item.price
  end

  test "confirm! links order to reorder schedule" do
    mock_successful_payment

    service = PendingOrderConfirmationService.new(@pending_order)
    result = service.confirm!

    assert_equal @schedule, result.order.reorder_schedule
  end

  test "confirm! marks pending order as confirmed" do
    mock_successful_payment

    service = PendingOrderConfirmationService.new(@pending_order)
    service.confirm!

    @pending_order.reload
    assert @pending_order.confirmed?
    assert @pending_order.confirmed_at.present?
    assert @pending_order.order.present?
  end

  test "confirm! advances schedule to next date" do
    mock_successful_payment

    service = PendingOrderConfirmationService.new(@pending_order)

    freeze_time do
      service.confirm!
      @schedule.reload
      assert_equal Date.current + 1.month, @schedule.next_scheduled_date
    end
  end

  test "confirm! sends order confirmation email" do
    mock_successful_payment

    service = PendingOrderConfirmationService.new(@pending_order)

    assert_enqueued_emails 1 do
      service.confirm!
    end
  end

  test "confirm! stores stripe payment intent id on order" do
    mock_successful_payment

    service = PendingOrderConfirmationService.new(@pending_order)
    result = service.confirm!

    assert result.order.stripe_session_id.present?
  end

  # ==========================================================================
  # Payment Failures
  # ==========================================================================

  test "confirm! returns error on payment failure" do
    Stripe::PaymentIntent.stubs(:create).raises(
      Stripe::CardError.new("Your card was declined", "card_declined", code: "card_declined")
    )

    service = PendingOrderConfirmationService.new(@pending_order)
    result = service.confirm!

    assert_not result.success?
    assert_includes result.error, "declined"
  end

  test "confirm! does not create order on payment failure" do
    Stripe::PaymentIntent.stubs(:create).raises(
      Stripe::CardError.new("Your card was declined", "card_declined", code: "card_declined")
    )

    service = PendingOrderConfirmationService.new(@pending_order)

    assert_no_difference "Order.count" do
      service.confirm!
    end
  end

  test "confirm! does not mark pending order as confirmed on payment failure" do
    Stripe::PaymentIntent.stubs(:create).raises(
      Stripe::CardError.new("Your card was declined", "card_declined", code: "card_declined")
    )

    service = PendingOrderConfirmationService.new(@pending_order)
    service.confirm!

    @pending_order.reload
    assert @pending_order.pending?
    assert_nil @pending_order.confirmed_at
  end

  test "confirm! does not advance schedule on payment failure" do
    original_date = @schedule.next_scheduled_date

    Stripe::PaymentIntent.stubs(:create).raises(
      Stripe::CardError.new("Your card was declined", "card_declined", code: "card_declined")
    )

    service = PendingOrderConfirmationService.new(@pending_order)
    service.confirm!

    @schedule.reload
    assert_equal original_date, @schedule.next_scheduled_date
  end

  # ==========================================================================
  # Invalid States
  # ==========================================================================

  test "confirm! fails for already confirmed pending order" do
    @pending_order.update!(status: :confirmed, confirmed_at: Time.current)

    service = PendingOrderConfirmationService.new(@pending_order)
    result = service.confirm!

    assert_not result.success?
    assert_includes result.error, "already"
  end

  test "confirm! fails for expired pending order" do
    @pending_order.expire!

    service = PendingOrderConfirmationService.new(@pending_order)
    result = service.confirm!

    assert_not result.success?
    assert_includes result.error, "expired"
  end

  test "confirm! fails for empty order" do
    @pending_order.update!(items_snapshot: { "items" => [], "total" => "0.00" })

    service = PendingOrderConfirmationService.new(@pending_order)
    result = service.confirm!

    assert_not result.success?
    assert_includes result.error, "empty"
  end

  # ==========================================================================
  # Shipping Address
  # ==========================================================================

  test "confirm! uses user default shipping address" do
    mock_successful_payment

    # User one already has addresses from fixtures (office is default)
    address = @user.default_address
    assert address.present?, "Test requires user to have an address"

    service = PendingOrderConfirmationService.new(@pending_order)
    result = service.confirm!

    assert result.success?
    assert_equal address.recipient_name, result.order.shipping_name
    assert_equal address.line1, result.order.shipping_address_line1
    assert_equal address.line2, result.order.shipping_address_line2
    assert_equal address.city, result.order.shipping_city
    assert_equal address.postcode, result.order.shipping_postal_code
    assert_equal address.country, result.order.shipping_country
  end

  test "confirm! fails when user has no delivery address" do
    mock_successful_payment

    # Remove all addresses from user
    @user.addresses.destroy_all

    service = PendingOrderConfirmationService.new(@pending_order)
    result = service.confirm!

    assert_not result.success?
    assert_includes result.error, "address"
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
