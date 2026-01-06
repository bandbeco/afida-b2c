require "test_helper"

class ProductOptionValueTest < ActiveSupport::TestCase
  test "valid product option value" do
    value = ProductOptionValue.new(
      product_option: product_options(:size),
      value: "20oz",
      position: 4
    )
    assert value.valid?
  end

  test "requires product_option" do
    value = ProductOptionValue.new(value: "Test")
    assert_not value.valid?
    assert_includes value.errors[:product_option], "must exist"
  end

  test "requires value" do
    value = ProductOptionValue.new(product_option: product_options(:size))
    assert_not value.valid?
    assert_includes value.errors[:value], "can't be blank"
  end

  test "belongs to product option" do
    value = product_option_values(:size_8oz)
    assert_equal product_options(:size), value.product_option
  end

  test "unique value per option" do
    duplicate = ProductOptionValue.new(
      product_option: product_options(:size),
      value: "8oz"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:value], "has already been taken"
  end

  test "same value allowed for different options" do
    # Same value text can exist for both Size and Colour (hypothetically)
    # Use unique value not in fixtures to avoid conflicts
    value1 = ProductOptionValue.create!(
      product_option: product_options(:size),
      value: "TestUniqueValue"
    )
    value2 = ProductOptionValue.new(
      product_option: product_options(:colour),
      value: "TestUniqueValue"
    )
    assert value2.valid?
  end

  # T035: Test deletion prevention when variants reference option value
  test "cannot delete option value that is referenced by variants" do
    option_value = product_option_values(:size_8oz)

    # This option value is used by single_wall_8oz_white and single_wall_8oz_black
    assert option_value.variant_option_values.any?,
           "Test requires option value to be in use"

    # Attempt to delete should fail - destroy! raises RecordNotDestroyed when restrict_with_error
    assert_raises(ActiveRecord::RecordNotDestroyed) do
      option_value.destroy!
    end

    # Value should still exist
    assert ProductOptionValue.exists?(option_value.id)

    # Verify the error message
    assert_not option_value.destroy
    assert_includes option_value.errors[:base].first, "Cannot delete record"
  end

  test "can delete option value that is not referenced by any variant" do
    # Create an unused option value
    unused_value = ProductOptionValue.create!(
      product_option: product_options(:size),
      value: "UnusedSizeForDeletion"
    )

    assert_no_difference "VariantOptionValue.count" do
      assert_difference "ProductOptionValue.count", -1 do
        unused_value.destroy!
      end
    end
  end
end
