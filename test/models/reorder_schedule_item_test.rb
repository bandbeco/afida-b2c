require "test_helper"

class ReorderScheduleItemTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @schedule = ReorderSchedule.create!(
      user: @user,
      frequency: :every_month,
      next_scheduled_date: 1.month.from_now.to_date,
      stripe_payment_method_id: "pm_test_123"
    )
    @variant = products(:one)
    @item = ReorderScheduleItem.new(
      reorder_schedule: @schedule,
      product: @variant,
      quantity: 2,
      price: @variant.price
    )
  end

  # ==========================================================================
  # Associations
  # ==========================================================================

  test "belongs to reorder_schedule" do
    assert_respond_to @item, :reorder_schedule
    assert_equal @schedule, @item.reorder_schedule
  end

  test "belongs to product" do
    assert_respond_to @item, :product
    assert_equal @variant, @item.product
  end

  # ==========================================================================
  # Validations
  # ==========================================================================

  test "valid with all required attributes" do
    assert @item.valid?
  end

  test "invalid without reorder_schedule" do
    @item.reorder_schedule = nil
    assert_not @item.valid?
    assert_includes @item.errors[:reorder_schedule], "must exist"
  end

  test "invalid without product" do
    @item.product = nil
    assert_not @item.valid?
    assert_includes @item.errors[:product], "must exist"
  end

  test "invalid without quantity" do
    @item.quantity = nil
    assert_not @item.valid?
    assert_includes @item.errors[:quantity], "can't be blank"
  end

  test "invalid with quantity less than or equal to 0" do
    @item.quantity = 0
    assert_not @item.valid?
    assert_includes @item.errors[:quantity], "must be greater than 0"

    @item.quantity = -1
    assert_not @item.valid?
    assert_includes @item.errors[:quantity], "must be greater than 0"
  end

  test "invalid without price" do
    @item.price = nil
    assert_not @item.valid?
    assert_includes @item.errors[:price], "can't be blank"
  end

  test "invalid with negative price" do
    @item.price = -1
    assert_not @item.valid?
    assert_includes @item.errors[:price], "must be greater than or equal to 0"
  end

  test "allows zero price" do
    @item.price = 0
    assert @item.valid?
  end

  test "enforces uniqueness of product within schedule" do
    @item.save!
    duplicate = ReorderScheduleItem.new(
      reorder_schedule: @schedule,
      product: @variant,
      quantity: 3,
      price: @variant.price
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:product_id], "has already been taken"
  end

  test "allows same product in different schedules" do
    @item.save!
    other_schedule = ReorderSchedule.create!(
      user: @user,
      frequency: :every_week,
      next_scheduled_date: 1.week.from_now.to_date,
      stripe_payment_method_id: "pm_test_456"
    )
    other_item = ReorderScheduleItem.new(
      reorder_schedule: other_schedule,
      product: @variant,
      quantity: 1,
      price: @variant.price
    )
    assert other_item.valid?
  end

  # ==========================================================================
  # Availability
  # ==========================================================================

  test "available? returns true when product is active" do
    @variant.update!(active: true)

    assert @item.available?
  end

  test "available? returns false when product is inactive" do
    @variant.update!(active: false)

    assert_not @item.available?
  end

  # ==========================================================================
  # Current Price
  # ==========================================================================

  test "current_price returns product current price" do
    @variant.update!(price: 15.99)

    assert_equal 15.99, @item.current_price
  end

  test "current_price reflects price changes" do
    @item.save!
    original_price = @item.current_price

    @variant.update!(price: original_price + 5.00)

    assert_equal original_price + 5.00, @item.current_price
    assert_equal original_price, @item.price # stored price unchanged
  end
end
