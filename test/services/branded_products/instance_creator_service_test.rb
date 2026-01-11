require "test_helper"

class BrandedProducts::InstanceCreatorServiceTest < ActiveSupport::TestCase
  setup do
    @order = orders(:acme_order)
    @order_item = order_items(:acme_branded_item)
    @service = BrandedProducts::InstanceCreatorService.new(@order_item)
  end

  test "creates instance product from order item" do
    assert_difference "Product.count", 1 do
      result = @service.create_instance_product(
        name: "ACME Coffee 12oz Branded Cups",
        sku: "BRANDED-ACME-12DW-002",
        initial_stock: 5000,
        reorder_price: 0.18
      )

      assert result.success?, "Expected success but got error: #{result.error}"
      assert_instance_of Product, result.product
    end
  end

  test "sets correct product attributes" do
    result = @service.create_instance_product(
      name: "ACME Coffee 12oz Branded Cups",
      sku: "BRANDED-ACME-12DW-003",
      initial_stock: 5000,
      reorder_price: 0.18
    )

    assert result.success?, "Expected success but got error: #{result.error}"
    product = result.product
    assert_equal "customized_instance", product.product_type
    assert_equal @order.organization, product.organization
    assert_equal @order_item.product, product.parent_product
    assert_equal @order_item.product.category, product.category
  end

  test "creates product with correct attributes" do
    result = @service.create_instance_product(
      name: "ACME Coffee 12oz Branded Cups",
      sku: "BRANDED-ACME-12DW-004",
      initial_stock: 5000,
      reorder_price: 0.18
    )

    product = result.product
    assert_equal "BRANDED-ACME-12DW-004", product.sku
    assert_equal 5000, product.stock_quantity
    assert_equal 0.18, product.price
  end

  test "copies design attachment to product" do
    # Attach design to order item
    @order_item.design.attach(
      io: File.open(Rails.root.join("test", "fixtures", "files", "test_design.pdf")),
      filename: "test_design.pdf"
    )

    result = @service.create_instance_product(
      name: "ACME Coffee 12oz Branded Cups",
      sku: "BRANDED-ACME-12DW-005",
      initial_stock: 5000,
      reorder_price: 0.18
    )

    assert result.product.product_photo.attached?
  end

  test "generates slug from name" do
    result = @service.create_instance_product(
      name: "ACME Coffee 12oz Branded Cups",
      sku: "BRANDED-ACME-12DW-006",
      initial_stock: 5000,
      reorder_price: 0.18
    )

    assert_equal "acme-coffee-12oz-branded-cups", result.product.slug
  end

  test "requires order item to have configuration" do
    order_item = order_items(:one) # standard order item, no configuration
    service = BrandedProducts::InstanceCreatorService.new(order_item)

    result = service.create_instance_product(
      name: "Test",
      sku: "TEST-001",
      initial_stock: 1000,
      reorder_price: 0.50
    )

    assert_not result.success?
    assert_includes result.error, "configuration"
  end

  test "requires order to have organization" do
    @order.update!(organization_id: nil)
    @order.reload

    result = @service.create_instance_product(
      name: "Test",
      sku: "TEST-001",
      initial_stock: 1000,
      reorder_price: 0.50
    )

    assert_not result.success?
    assert_includes result.error, "organization"
  end

  test "validates required parameters" do
    result = @service.create_instance_product(
      name: "",
      sku: "",
      initial_stock: nil,
      reorder_price: nil
    )

    assert_not result.success?
    assert result.error.present?
  end

  test "updates order branded_order_status" do
    @order.update!(branded_order_status: "stock_received")

    @service.create_instance_product(
      name: "ACME Coffee 12oz Branded Cups",
      sku: "BRANDED-ACME-12DW-007",
      initial_stock: 5000,
      reorder_price: 0.18
    )

    @order.reload
    assert_equal "instance_created", @order.branded_order_status
  end
end
