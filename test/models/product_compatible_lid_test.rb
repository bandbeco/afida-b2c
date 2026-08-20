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

  # The container -> lid join is the only curated direction. Lid pages read it
  # backwards to answer "what does this lid fit?", so the reverse view must come
  # from the same rows rather than a second curation surface.
  test "a lid lists the containers mapped to it" do
    lid = products(:flat_lid_8oz)

    assert_includes lid.compatible_containers, products(:branded_cup_8oz)
  end

  test "compatible_containers excludes inactive containers" do
    lid = products(:flat_lid_8oz)
    products(:branded_cup_8oz).update!(active: false)

    assert_not_includes lid.compatible_containers, products(:branded_cup_8oz)
  end

  test "compatible_containers honours the join sort order" do
    lid = products(:flat_lid_8oz)
    ProductCompatibleLid.create!(product: products(:two), compatible_lid: lid, sort_order: 1)
    ProductCompatibleLid.create!(product: products(:one), compatible_lid: lid, sort_order: 0)

    assert_equal [ products(:one), products(:two), products(:branded_cup_8oz) ],
                 lid.compatible_containers.to_a
  end
end
