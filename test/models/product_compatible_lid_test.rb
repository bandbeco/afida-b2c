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

  test "destroying the default row promotes the lowest sort_order survivor" do
    # Fixtures: flat_lid_8oz is the default (sort_order 1), domed_lid_8oz is not (sort_order 2)
    product_compatible_lids(:one).destroy!

    assert product_compatible_lids(:two).reload.default?,
           "Remaining lid should be promoted to default"
  end

  test "destroying a non-default row leaves the default untouched" do
    product_compatible_lids(:two).destroy!

    assert product_compatible_lids(:one).reload.default?
  end

  test "destroying the last row promotes nothing" do
    product_compatible_lids(:two).destroy!

    assert_nothing_raised { product_compatible_lids(:one).destroy! }
  end
end
