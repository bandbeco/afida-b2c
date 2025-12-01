require "test_helper"

class OrderTest < ActiveSupport::TestCase
  setup do
    @order = orders(:one)
    @valid_attributes = {
      email: "test@example.com",
      stripe_session_id: "sess_unique_123",
      order_number: "ORD-2025-999999",
      status: "pending",
      subtotal_amount: 100,
      vat_amount: 20,
      shipping_amount: 5,
      total_amount: 125,
      shipping_name: "John Doe",
      shipping_address_line1: "123 Main St",
      shipping_city: "London",
      shipping_postal_code: "SW1A 1AA",
      shipping_country: "GB"
    }
  end

  # Validation tests
  test "validates presence of email" do
    order = Order.new(@valid_attributes.except(:email))
    assert_not order.valid?
    assert_includes order.errors[:email], "can't be blank"
  end

  test "validates email format" do
    order = Order.new(@valid_attributes.merge(email: "invalid-email"))
    assert_not order.valid?
    assert_includes order.errors[:email], "is invalid"
  end

  test "normalizes email to lowercase" do
    order = Order.create!(@valid_attributes.merge(
      email: "TEST@EXAMPLE.COM",
      stripe_session_id: "sess_normalize_test",
      order_number: nil
    ))
    assert_equal "test@example.com", order.email
  end

  test "validates uniqueness of stripe_session_id" do
    order = Order.new(@valid_attributes.merge(stripe_session_id: @order.stripe_session_id))
    assert_not order.valid?
    assert_includes order.errors[:stripe_session_id], "has already been taken"
  end

  test "validates uniqueness of order_number" do
    order = Order.new(@valid_attributes.merge(order_number: @order.order_number))
    assert_not order.valid?
    assert_includes order.errors[:order_number], "has already been taken"
  end

  test "validates presence of required shipping fields" do
    order = Order.new(@valid_attributes.except(:shipping_name))
    assert_not order.valid?
    assert_includes order.errors[:shipping_name], "can't be blank"
  end

  test "validates amounts are non-negative" do
    order = Order.new(@valid_attributes.merge(subtotal_amount: -1))
    assert_not order.valid?
    assert_includes order.errors[:subtotal_amount], "must be greater than or equal to 0"
  end

  # Enum tests
  test "status enum includes all expected values" do
    expected_statuses = %w[pending paid processing shipped delivered cancelled refunded]
    assert_equal expected_statuses.sort, Order.statuses.keys.sort
  end

  test "status enum methods work" do
    @order.status = "shipped"
    assert @order.shipped?
    assert_not @order.pending?
  end

  # Method tests
  test "items_count returns sum of order item quantities" do
    # Check actual fixture data
    expected_count = @order.order_items.sum(:quantity)
    assert_equal expected_count, @order.items_count
  end

  test "full_shipping_address combines address parts" do
    address = @order.full_shipping_address
    assert_includes address, @order.shipping_address_line1
    assert_includes address, @order.shipping_city
    assert_includes address, @order.shipping_postal_code
    assert_includes address, @order.shipping_country
  end

  test "full_shipping_address handles missing address_line2" do
    @order.shipping_address_line2 = nil
    address = @order.full_shipping_address
    assert_not_includes address, "nil"
  end

  test "display_number formats order_number with hash" do
    assert_equal "##{@order.order_number}", @order.display_number
  end

  test "generate_order_number creates unique order number" do
    order = Order.create!(@valid_attributes.except(:order_number))
    assert_not_nil order.order_number
    assert_match /ORD-\d{4}-\d{6}/, order.order_number
  end

  test "generate_order_number includes current year" do
    order = Order.create!(@valid_attributes.except(:order_number).merge(
      stripe_session_id: "sess_year_test"
    ))
    current_year = Date.current.year
    assert_includes order.order_number, current_year.to_s
  end

  test "does not regenerate order_number if already set" do
    order = Order.create!(@valid_attributes)
    original_number = order.order_number
    order.update(subtotal_amount: 200)
    assert_equal original_number, order.order_number
  end

  # Association tests
  test "belongs to user optionally" do
    # Order fixture has user, so test with a new order
    guest_order = Order.create!(@valid_attributes.merge(
      stripe_session_id: "sess_guest_test",
      order_number: nil
    ))
    assert_nil guest_order.user

    guest_order.user = users(:one)
    assert_equal users(:one), guest_order.user
  end

  test "has many order_items" do
    assert_respond_to @order, :order_items
    assert @order.order_items.count > 0
  end

  test "destroying order destroys order_items" do
    order = Order.create!(@valid_attributes.except(:order_number))
    order.order_items.create!(
      product_variant: product_variants(:one),
      product_name: "Test Product",
      product_sku: "TEST123",
      price: 10.0,
      quantity: 1,
      line_total: 10.0
    )

    assert_difference "OrderItem.count", -1 do
      order.destroy
    end
  end

  # Scope tests
  test "recent scope orders by created_at descending" do
    old_order = Order.create!(@valid_attributes.except(:order_number).merge(
      stripe_session_id: "sess_old",
      created_at: 2.days.ago
    ))

    new_order = Order.create!(@valid_attributes.except(:order_number).merge(
      stripe_session_id: "sess_new"
    ))

    recent_orders = Order.recent.limit(2)
    assert_equal new_order, recent_orders.first
  end

  # Organization tests
  test "order can belong to organization" do
    order = orders(:acme_order)
    assert_equal organizations(:acme), order.organization
  end

  test "order tracks which user placed it" do
    order = orders(:acme_order)
    assert_equal users(:acme_admin), order.placed_by_user
  end

  test "B2B order has both organization and placed_by" do
    order = Order.create!(
      user: users(:acme_admin),
      organization: organizations(:acme),
      placed_by_user: users(:acme_admin),
      stripe_session_id: "test_session_123",
      total_amount: 1000,
      subtotal_amount: 833.33,
      vat_amount: 166.67,
      shipping_amount: 0,
      status: "pending",
      email: "admin@acme.com",
      shipping_name: "ACME Corp",
      shipping_address_line1: "100 Business Park",
      shipping_city: "London",
      shipping_postal_code: "EC1A 1BB",
      shipping_country: "GB"
    )
    assert order.persisted?
    assert order.b2b_order?
  end

  test "consumer order has no organization" do
    order = orders(:one)
    assert_nil order.organization_id
    assert_not order.b2b_order?
  end

  test "organization orders scope" do
    org_orders = Order.for_organization(organizations(:acme))
    assert_includes org_orders, orders(:acme_order)
    assert_not_includes org_orders, orders(:one)
  end

  # Branded order status tests
  test "order has branded_order_status enum" do
    order = orders(:acme_order)

    order.branded_order_status = "design_pending"
    assert order.valid?

    order.branded_order_status = "design_approved"
    assert order.valid?

    order.branded_order_status = "in_production"
    assert order.valid?

    order.branded_order_status = "production_complete"
    assert order.valid?

    order.branded_order_status = "stock_received"
    assert order.valid?

    order.branded_order_status = "instance_created"
    assert order.valid?
  end

  test "branded order scope" do
    # This test will be fully implemented when OrderItem has configuration support
    # For now, just verify the scope exists and returns an ActiveRecord::Relation
    branded_orders = Order.branded_orders
    assert_kind_of ActiveRecord::Relation, branded_orders
  end

  # Sample order tests
  test "with_samples scope returns orders containing sample items" do
    # Create sample-eligible variant
    sample_variant = ProductVariant.create!(
      product: products(:one),
      name: "Sample Order Test",
      sku: "SAMPLE-ORDER-TEST-1",
      price: 10.0,
      sample_eligible: true,
      active: true
    )

    # Create order with sample item
    sample_order = Order.create!(
      @valid_attributes.merge(
        stripe_session_id: "sess_sample_order_test",
        order_number: nil
      )
    )
    sample_order.order_items.create!(
      product_variant: sample_variant,
      product_name: "Sample Product",
      product_sku: sample_variant.sku,
      price: 0,
      quantity: 1,
      line_total: 0
    )

    # Create order without sample item
    regular_variant = ProductVariant.create!(
      product: products(:one),
      name: "Regular Order Test",
      sku: "REGULAR-ORDER-TEST-1",
      price: 20.0,
      sample_eligible: false,
      active: true
    )

    regular_order = Order.create!(
      @valid_attributes.merge(
        stripe_session_id: "sess_regular_order_test",
        order_number: nil
      )
    )
    regular_order.order_items.create!(
      product_variant: regular_variant,
      product_name: "Regular Product",
      product_sku: regular_variant.sku,
      price: 20.0,
      quantity: 1,
      line_total: 20.0
    )

    orders_with_samples = Order.with_samples
    assert_includes orders_with_samples, sample_order
    assert_not_includes orders_with_samples, regular_order
  end

  test "contains_samples? returns true when order has sample items" do
    sample_variant = ProductVariant.create!(
      product: products(:one),
      name: "Contains Samples Test",
      sku: "CONTAINS-SAMPLES-TEST-1",
      price: 10.0,
      sample_eligible: true,
      active: true
    )

    order = Order.create!(
      @valid_attributes.merge(
        stripe_session_id: "sess_contains_samples_test",
        order_number: nil
      )
    )
    order.order_items.create!(
      product_variant: sample_variant,
      product_name: "Sample Product",
      product_sku: sample_variant.sku,
      price: 0,
      quantity: 1,
      line_total: 0
    )

    assert order.contains_samples?
  end

  test "contains_samples? returns false when order has no sample items" do
    regular_variant = ProductVariant.create!(
      product: products(:one),
      name: "No Samples Test",
      sku: "NO-SAMPLES-TEST-1",
      price: 20.0,
      sample_eligible: false,
      active: true
    )

    order = Order.create!(
      @valid_attributes.merge(
        stripe_session_id: "sess_no_samples_test",
        order_number: nil
      )
    )
    order.order_items.create!(
      product_variant: regular_variant,
      product_name: "Regular Product",
      product_sku: regular_variant.sku,
      price: 20.0,
      quantity: 1,
      line_total: 20.0
    )

    assert_not order.contains_samples?
  end

  test "sample_request? returns true for samples-only order" do
    sample_variant = ProductVariant.create!(
      product: products(:one),
      name: "Sample Request Test",
      sku: "SAMPLE-REQUEST-TEST-1",
      price: 10.0,
      sample_eligible: true,
      active: true
    )

    order = Order.create!(
      @valid_attributes.merge(
        stripe_session_id: "sess_sample_request_test",
        order_number: nil
      )
    )
    order.order_items.create!(
      product_variant: sample_variant,
      product_name: "Sample Product",
      product_sku: sample_variant.sku,
      price: 0,
      quantity: 1,
      line_total: 0
    )

    assert order.sample_request?
  end

  test "sample_request? returns false for mixed order (samples + paid)" do
    sample_variant = ProductVariant.create!(
      product: products(:one),
      name: "Mixed Order Sample",
      sku: "MIXED-ORDER-SAMPLE-1",
      price: 10.0,
      sample_eligible: true,
      active: true
    )

    regular_variant = ProductVariant.create!(
      product: products(:one),
      name: "Mixed Order Regular",
      sku: "MIXED-ORDER-REGULAR-1",
      price: 20.0,
      sample_eligible: false,
      active: true
    )

    order = Order.create!(
      @valid_attributes.merge(
        stripe_session_id: "sess_mixed_order_test",
        order_number: nil
      )
    )
    order.order_items.create!(
      product_variant: sample_variant,
      product_name: "Sample Product",
      product_sku: sample_variant.sku,
      price: 0,
      quantity: 1,
      line_total: 0
    )
    order.order_items.create!(
      product_variant: regular_variant,
      product_name: "Regular Product",
      product_sku: regular_variant.sku,
      price: 20.0,
      quantity: 1,
      line_total: 20.0
    )

    assert_not order.sample_request?
    assert order.contains_samples?
  end

  test "sample_request? returns false for regular order" do
    regular_variant = ProductVariant.create!(
      product: products(:one),
      name: "Regular Only Test",
      sku: "REGULAR-ONLY-TEST-1",
      price: 20.0,
      sample_eligible: false,
      active: true
    )

    order = Order.create!(
      @valid_attributes.merge(
        stripe_session_id: "sess_regular_only_test",
        order_number: nil
      )
    )
    order.order_items.create!(
      product_variant: regular_variant,
      product_name: "Regular Product",
      product_sku: regular_variant.sku,
      price: 20.0,
      quantity: 1,
      line_total: 20.0
    )

    assert_not order.sample_request?
  end
end
