require "test_helper"

class PendingOrderTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @schedule = ReorderSchedule.create!(
      user: @user,
      frequency: :every_month,
      next_scheduled_date: 1.month.from_now.to_date,
      stripe_payment_method_id: "pm_test_123"
    )
    @pending_order = PendingOrder.new(
      reorder_schedule: @schedule,
      scheduled_for: 3.days.from_now.to_date,
      items_snapshot: {
        "items" => [
          {
            "product_id" => 1,
            "product_name" => "Kraft Napkins",
            "variant_name" => "Pack of 500",
            "quantity" => 2,
            "price" => "8.00",
            "available" => true
          }
        ],
        "subtotal" => "16.00",
        "vat" => "3.20",
        "shipping" => "0.00",
        "total" => "19.20",
        "unavailable_items" => []
      }
    )
  end

  # ==========================================================================
  # Associations
  # ==========================================================================

  test "belongs to reorder_schedule" do
    assert_respond_to @pending_order, :reorder_schedule
    assert_equal @schedule, @pending_order.reorder_schedule
  end

  test "belongs to order (optional)" do
    assert_respond_to @pending_order, :order
    assert_nil @pending_order.order
    assert @pending_order.valid?
  end

  # ==========================================================================
  # Validations
  # ==========================================================================

  test "valid with all required attributes" do
    assert @pending_order.valid?
  end

  test "invalid without reorder_schedule" do
    @pending_order.reorder_schedule = nil
    assert_not @pending_order.valid?
    assert_includes @pending_order.errors[:reorder_schedule], "must exist"
  end

  test "invalid without items_snapshot" do
    @pending_order.items_snapshot = nil
    assert_not @pending_order.valid?
    assert_includes @pending_order.errors[:items_snapshot], "can't be blank"
  end

  test "invalid without scheduled_for" do
    @pending_order.scheduled_for = nil
    assert_not @pending_order.valid?
    assert_includes @pending_order.errors[:scheduled_for], "can't be blank"
  end

  test "invalid with invalid status" do
    @pending_order.status = :invalid_status
    assert_not @pending_order.valid?
    assert_includes @pending_order.errors[:status], "is not included in the list"
  end

  # ==========================================================================
  # Enums
  # ==========================================================================

  test "status enum values" do
    assert_equal({ "pending" => 0, "confirmed" => 1, "expired" => 2 },
                 PendingOrder.statuses)
  end

  test "default status is pending" do
    assert_equal "pending", @pending_order.status
  end

  # ==========================================================================
  # Scopes
  # ==========================================================================

  test "pending scope returns only pending orders" do
    @pending_order.save!
    confirmed_order = PendingOrder.create!(
      reorder_schedule: @schedule,
      status: :confirmed,
      scheduled_for: 5.days.from_now.to_date,
      items_snapshot: { "items" => [] },
      confirmed_at: Time.current
    )

    pending_orders = PendingOrder.pending
    assert_includes pending_orders, @pending_order
    assert_not_includes pending_orders, confirmed_order
  end

  test "expired_unprocessed scope returns pending orders past scheduled date" do
    past_order = PendingOrder.create!(
      reorder_schedule: @schedule,
      status: :pending,
      scheduled_for: 1.day.ago.to_date,
      items_snapshot: { "items" => [] }
    )
    future_order = @pending_order
    future_order.save!

    expired = PendingOrder.expired_unprocessed
    assert_includes expired, past_order
    assert_not_includes expired, future_order
  end

  # ==========================================================================
  # State Methods
  # ==========================================================================

  test "confirm! changes status to confirmed and sets order and confirmed_at" do
    @pending_order.save!
    order = orders(:one)

    freeze_time do
      @pending_order.confirm!(order)

      assert @pending_order.confirmed?
      assert_equal order, @pending_order.order
      assert_equal Time.current, @pending_order.confirmed_at
    end
  end

  test "expire! changes status to expired and sets expired_at" do
    @pending_order.save!

    freeze_time do
      @pending_order.expire!

      assert @pending_order.expired?
      assert_equal Time.current, @pending_order.expired_at
    end
  end

  # ==========================================================================
  # Snapshot Accessors
  # ==========================================================================

  test "items returns items array from snapshot" do
    items = @pending_order.items
    assert_equal 1, items.length
    assert_equal "Kraft Napkins", items.first[:product_name]
    assert_equal 2, items.first[:quantity]
  end

  test "items returns empty array if no items in snapshot" do
    @pending_order.items_snapshot = {}
    assert_equal [], @pending_order.items
  end

  test "total_amount returns total from snapshot as decimal" do
    assert_equal BigDecimal("19.20"), @pending_order.total_amount
  end

  test "total_amount returns 0 if no total in snapshot" do
    @pending_order.items_snapshot = {}
    assert_equal 0, @pending_order.total_amount
  end

  test "subtotal_amount returns subtotal from snapshot as decimal" do
    assert_equal BigDecimal("16.00"), @pending_order.subtotal_amount
  end

  test "vat_amount returns vat from snapshot as decimal" do
    assert_equal BigDecimal("3.20"), @pending_order.vat_amount
  end

  test "unavailable_items returns unavailable_items array from snapshot" do
    @pending_order.items_snapshot["unavailable_items"] = [
      { "product_id" => 999, "product_name" => "Discontinued Item" }
    ]
    unavailable = @pending_order.unavailable_items
    assert_equal 1, unavailable.length
    assert_equal "Discontinued Item", unavailable.first[:product_name]
  end

  test "unavailable_items returns empty array if none in snapshot" do
    assert_equal [], @pending_order.unavailable_items
  end

  # ==========================================================================
  # Token Generation
  # ==========================================================================

  test "confirmation_token generates signed global ID" do
    @pending_order.save!
    token = @pending_order.confirmation_token

    assert_not_nil token
    assert token.is_a?(String)

    # Verify token can be decoded
    located = GlobalID::Locator.locate_signed(token, for: "pending_order_confirm")
    assert_equal @pending_order, located
  end

  test "edit_token generates signed global ID for editing" do
    @pending_order.save!
    token = @pending_order.edit_token

    assert_not_nil token
    assert token.is_a?(String)

    # Verify token can be decoded
    located = GlobalID::Locator.locate_signed(token, for: "pending_order_edit")
    assert_equal @pending_order, located
  end

  test "confirmation_token expires after 72 hours" do
    @pending_order.save!
    token = @pending_order.confirmation_token

    travel 4.days do
      located = GlobalID::Locator.locate_signed(token, for: "pending_order_confirm")
      assert_nil located
    end
  end
end
