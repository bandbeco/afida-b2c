# frozen_string_literal: true

require "test_helper"

class PendingOrderSnapshotBuilderTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @product = products(:one)
    @product = products(:one)
    @schedule = reorder_schedules(:active_monthly)
    @schedule_item = reorder_schedule_items(:active_monthly_item_one)

    # Ensure product and variant are active with consistent test price
    @product.update!(active: true)
    @product.update!(active: true, price: 10.00)

    # Update schedule item to use consistent test price
    @schedule_item.update!(price: 10.00)

    # Remove second fixture item to start with single-item schedule
    reorder_schedule_items(:active_monthly_item_two).destroy
  end

  # ==========================================================================
  # Instance Method: build (from schedule)
  # ==========================================================================

  test "build returns hash with required keys" do
    snapshot = PendingOrderSnapshotBuilder.new(@schedule).build

    assert snapshot.key?("items")
    assert snapshot.key?("subtotal")
    assert snapshot.key?("vat")
    assert snapshot.key?("shipping")
    assert snapshot.key?("total")
    assert snapshot.key?("unavailable_items")
  end

  test "build includes available items from schedule" do
    snapshot = PendingOrderSnapshotBuilder.new(@schedule).build

    assert_equal 1, snapshot["items"].count
    item = snapshot["items"].first
    assert_equal @product.id, item["product_id"]
    assert_equal @product.name, item["product_name"]
    assert_equal 2, item["quantity"]
    assert_equal true, item["available"]
  end

  test "build calculates correct line total" do
    snapshot = PendingOrderSnapshotBuilder.new(@schedule).build

    item = snapshot["items"].first
    assert_equal "10.00", item["price"]
    assert_equal "20.00", item["line_total"] # 10.00 * 2
  end

  test "build calculates correct subtotal" do
    snapshot = PendingOrderSnapshotBuilder.new(@schedule).build

    assert_equal "20.00", snapshot["subtotal"]
  end

  test "build calculates VAT at 20%" do
    snapshot = PendingOrderSnapshotBuilder.new(@schedule).build

    # VAT on £20 subtotal = £4
    assert_equal "4.00", snapshot["vat"]
  end

  test "build includes shipping for orders under threshold" do
    # Subtotal is £20, under £100 threshold
    snapshot = PendingOrderSnapshotBuilder.new(@schedule).build

    expected_shipping = "%.2f" % (Shipping::STANDARD_COST / 100.0)
    assert_equal expected_shipping, snapshot["shipping"]
  end

  test "build has free shipping for orders at or above threshold" do
    # Set price high enough to exceed threshold
    @product.update!(price: 60.00)
    @schedule_item.update!(price: 60.00)

    snapshot = PendingOrderSnapshotBuilder.new(@schedule).build

    # Subtotal is £120 (60 * 2), above £100 threshold
    assert_equal "0.00", snapshot["shipping"]
  end

  test "build calculates correct total" do
    snapshot = PendingOrderSnapshotBuilder.new(@schedule).build

    subtotal = 20.00
    vat = subtotal * VAT_RATE
    shipping = Shipping::STANDARD_COST / 100.0
    expected_total = "%.2f" % (subtotal + vat + shipping)

    assert_equal expected_total, snapshot["total"]
  end

  test "build marks inactive variant as unavailable" do
    @product.update!(active: false)

    snapshot = PendingOrderSnapshotBuilder.new(@schedule).build

    assert_equal 0, snapshot["items"].count
    assert_equal 1, snapshot["unavailable_items"].count

    unavailable = snapshot["unavailable_items"].first
    assert_equal @product.id, unavailable["product_id"]
    assert_includes unavailable["reason"], "no longer available"
  end

  test "build marks inactive product as unavailable" do
    @product.update!(active: false)
    @schedule.reload # Reload to pick up association changes

    snapshot = PendingOrderSnapshotBuilder.new(@schedule).build

    assert_equal 0, snapshot["items"].count
    assert_equal 1, snapshot["unavailable_items"].count

    unavailable = snapshot["unavailable_items"].first
    assert_equal @product.id, unavailable["product_id"]
    assert_includes unavailable["reason"], "no longer available"
  end

  test "build handles multiple items" do
    # Create second variant
    second_variant = Product.create!(
      category: categories(:cups),
      sku: "TEST-002",
      name: "Test Variant 2",
      price: 15.00,
      active: true
    )

    ReorderScheduleItem.create!(
      reorder_schedule: @schedule,
      product: second_variant,
      quantity: 3,
      price: 15.00
    )

    snapshot = PendingOrderSnapshotBuilder.new(@schedule).build

    assert_equal 2, snapshot["items"].count
    # Subtotal: (10 * 2) + (15 * 3) = 20 + 45 = 65
    assert_equal "65.00", snapshot["subtotal"]
  end

  # ==========================================================================
  # Class Method: build_from_items (from raw items array)
  # ==========================================================================

  test "build_from_items returns hash with required keys" do
    items = [ { product_id: @product.id, quantity: 2 } ]

    snapshot = PendingOrderSnapshotBuilder.build_from_items(items)

    assert snapshot.key?("items")
    assert snapshot.key?("subtotal")
    assert snapshot.key?("vat")
    assert snapshot.key?("shipping")
    assert snapshot.key?("total")
    assert snapshot.key?("unavailable_items")
  end

  test "build_from_items creates items from raw params" do
    items = [ { product_id: @product.id, quantity: 3 } ]

    snapshot = PendingOrderSnapshotBuilder.build_from_items(items)

    assert_equal 1, snapshot["items"].count
    item = snapshot["items"].first
    assert_equal @product.id, item["product_id"]
    assert_equal 3, item["quantity"]
    assert_equal "30.00", item["line_total"] # 10 * 3
  end

  test "build_from_items skips inactive variants" do
    @product.update!(active: false)
    items = [ { product_id: @product.id, quantity: 2 } ]

    snapshot = PendingOrderSnapshotBuilder.build_from_items(items)

    assert_equal 0, snapshot["items"].count
    assert_equal [], snapshot["unavailable_items"] # Note: build_from_items doesn't track unavailable
  end

  test "build_from_items skips inactive products" do
    @product.update!(active: false)
    items = [ { product_id: @product.id, quantity: 2 } ]

    snapshot = PendingOrderSnapshotBuilder.build_from_items(items)

    assert_equal 0, snapshot["items"].count
  end

  test "build_from_items skips non-existent variants" do
    items = [ { product_id: 999999, quantity: 2 } ]

    snapshot = PendingOrderSnapshotBuilder.build_from_items(items)

    assert_equal 0, snapshot["items"].count
  end

  test "build_from_items handles multiple items" do
    second_variant = Product.create!(
      category: categories(:cups),
      sku: "TEST-003",
      name: "Test Variant 3",
      price: 25.00,
      active: true
    )

    items = [
      { product_id: @product.id, quantity: 2 },
      { product_id: second_variant.id, quantity: 1 }
    ]

    snapshot = PendingOrderSnapshotBuilder.build_from_items(items)

    assert_equal 2, snapshot["items"].count
    # Subtotal: (10 * 2) + (25 * 1) = 45
    assert_equal "45.00", snapshot["subtotal"]
  end

  test "build_from_items converts quantity to integer" do
    items = [ { product_id: @product.id, quantity: "5" } ]

    snapshot = PendingOrderSnapshotBuilder.build_from_items(items)

    item = snapshot["items"].first
    assert_equal 5, item["quantity"]
    assert_equal "50.00", item["line_total"]
  end

  # ==========================================================================
  # Class Method: format_amount
  # ==========================================================================

  test "format_amount formats to two decimal places" do
    assert_equal "10.00", PendingOrderSnapshotBuilder.format_amount(10)
    assert_equal "10.50", PendingOrderSnapshotBuilder.format_amount(10.5)
    assert_equal "10.99", PendingOrderSnapshotBuilder.format_amount(10.99)
    assert_equal "10.10", PendingOrderSnapshotBuilder.format_amount(10.1)
  end

  test "format_amount rounds correctly" do
    # Ruby's % uses sprintf which rounds half to even (banker's rounding)
    assert_equal "10.12", PendingOrderSnapshotBuilder.format_amount(10.125)
    assert_equal "10.12", PendingOrderSnapshotBuilder.format_amount(10.124)
    assert_equal "10.13", PendingOrderSnapshotBuilder.format_amount(10.126)
  end

  # ==========================================================================
  # Consistency: Both methods produce same totals
  # ==========================================================================

  test "build and build_from_items produce consistent totals for same items" do
    # Build from schedule
    schedule_snapshot = PendingOrderSnapshotBuilder.new(@schedule).build

    # Build from raw items with same data
    items = [ { product_id: @product.id, quantity: 2 } ]
    items_snapshot = PendingOrderSnapshotBuilder.build_from_items(items)

    assert_equal schedule_snapshot["subtotal"], items_snapshot["subtotal"]
    assert_equal schedule_snapshot["vat"], items_snapshot["vat"]
    assert_equal schedule_snapshot["shipping"], items_snapshot["shipping"]
    assert_equal schedule_snapshot["total"], items_snapshot["total"]
  end
end
