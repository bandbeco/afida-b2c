require "test_helper"

class ProductCompatibleLidTest < ActiveSupport::TestCase
  test "belongs to product" do
    compatibility = product_compatible_lids(:one)
    assert_instance_of Product, compatibility.product
  end

  test "belongs to compatible_lid (Product)" do
    compatibility = product_compatible_lids(:one)
    assert_instance_of Product, compatibility.compatible_lid
  end

  test "validates uniqueness of product and compatible_lid combination" do
    existing = product_compatible_lids(:one)
    duplicate = ProductCompatibleLid.new(
      product: existing.product,
      compatible_lid: existing.compatible_lid
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:compatible_lid_id], "has already been taken"
  end

  test "orders by sort_order by default" do
    # Assumes fixtures have different sort_orders
    compatibilities = ProductCompatibleLid.all
    assert_equal compatibilities, compatibilities.sort_by(&:sort_order)
  end

  test "only one default per product" do
    product = products(:branded_cup_8oz)

    # Create first default with a different lid (paper_lids)
    first = ProductCompatibleLid.create!(
      product: product,
      compatible_lid: products(:paper_lids),
      default: true,
      sort_order: 3
    )

    # Create second default with another different lid - should unset first
    second = ProductCompatibleLid.create!(
      product: product,
      compatible_lid: products(:recyclable_lid_black_80mm),
      default: true,
      sort_order: 4
    )

    first.reload
    assert_not first.default, "First should no longer be default"
    assert second.default, "Second should be default"
  end
end
