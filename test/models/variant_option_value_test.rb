# frozen_string_literal: true

require "test_helper"

class VariantOptionValueTest < ActiveSupport::TestCase
  # ==========================================================================
  # Fixtures Setup
  # ==========================================================================

  setup do
    @variant = product_variants(:single_wall_8oz_white)
    @size_option = product_options(:size)
    @colour_option = product_options(:colour)
    @size_8oz = product_option_values(:size_8oz)
    @size_12oz = product_option_values(:size_12oz)
    @colour_white = product_option_values(:colour_white)
  end

  # ==========================================================================
  # Association Tests
  # ==========================================================================

  test "belongs to product_variant" do
    vov = variant_option_values(:single_wall_8oz_white_size)
    assert_equal @variant, vov.product_variant
  end

  test "belongs to product_option_value" do
    vov = variant_option_values(:single_wall_8oz_white_size)
    assert_equal @size_8oz, vov.product_option_value
  end

  test "belongs to product_option" do
    vov = variant_option_values(:single_wall_8oz_white_size)
    assert_equal @size_option, vov.product_option
  end

  # ==========================================================================
  # Validation Tests
  # ==========================================================================

  test "requires product_variant" do
    vov = VariantOptionValue.new(
      product_option_value: @size_8oz,
      product_option: @size_option
    )
    assert_not vov.valid?
    assert_includes vov.errors[:product_variant], "must exist"
  end

  test "requires product_option_value" do
    vov = VariantOptionValue.new(
      product_variant: @variant,
      product_option: @size_option
    )
    assert_not vov.valid?
    assert_includes vov.errors[:product_option_value], "must exist"
  end

  # ==========================================================================
  # Callback Tests
  # ==========================================================================

  test "auto-populates product_option_id from product_option_value on create" do
    new_variant = ProductVariant.create!(
      product: products(:one),
      name: "Test Variant",
      sku: "TEST-VOV-001",
      price: 10.00
    )

    vov = VariantOptionValue.new(
      product_variant: new_variant,
      product_option_value: @size_12oz
    )

    # product_option should be nil before save (we'll set it via callback)
    vov.save!

    assert_equal @size_option, vov.product_option
  end

  # ==========================================================================
  # Uniqueness Constraint Tests (US4)
  # ==========================================================================

  test "prevents duplicate option value assignments to same variant" do
    # Try to assign 8oz size again to a variant that already has it
    duplicate = VariantOptionValue.new(
      product_variant: @variant,
      product_option_value: @size_8oz,
      product_option: @size_option
    )

    assert_not duplicate.valid?
  end

  test "allows same option value on different variants" do
    other_variant = product_variants(:single_wall_12oz_white)

    # 8oz size should be assignable to another variant
    # (Though 12oz already has a size, let's use a fresh variant)
    new_variant = ProductVariant.create!(
      product: products(:one),
      name: "Another Variant",
      sku: "TEST-VOV-002",
      price: 12.00
    )

    vov = VariantOptionValue.new(
      product_variant: new_variant,
      product_option_value: @size_8oz,
      product_option: @size_option
    )

    assert vov.valid?
  end

  test "enforces one value per option type per variant" do
    # single_wall_8oz_white already has size=8oz
    # Try to add size=12oz - should fail (one size per variant)
    conflicting = VariantOptionValue.new(
      product_variant: @variant,
      product_option_value: @size_12oz,
      product_option: @size_option
    )

    assert_not conflicting.valid?
    assert_includes conflicting.errors[:product_option_id], "already has a value for this option"
  end

  test "allows different option types on same variant" do
    # single_wall_8oz_white has size and colour
    # Verify both exist (from fixtures)
    size_vov = variant_option_values(:single_wall_8oz_white_size)
    colour_vov = variant_option_values(:single_wall_8oz_white_colour)

    assert_equal @variant, size_vov.product_variant
    assert_equal @variant, colour_vov.product_variant
    assert_not_equal size_vov.product_option, colour_vov.product_option
  end
end
