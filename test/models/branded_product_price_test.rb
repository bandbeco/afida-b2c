require "test_helper"

class BrandedProductPriceTest < ActiveSupport::TestCase
  test "valid branded product price" do
    price = BrandedProductPrice.new(
      product: products(:branded_template_variant),
      size: "8oz",
      quantity_tier: 3000,
      price_per_unit: 0.22,
      case_quantity: 500
    )
    assert price.valid?
  end

  test "requires product" do
    price = BrandedProductPrice.new(
      size: "8oz",
      quantity_tier: 1000,
      price_per_unit: 0.30
    )
    assert_not price.valid?
    assert_includes price.errors[:product], "must exist"
  end

  test "requires size" do
    price = BrandedProductPrice.new(
      product: products(:branded_template_variant),
      quantity_tier: 1000,
      price_per_unit: 0.30
    )
    assert_not price.valid?
    assert_includes price.errors[:size], "can't be blank"
  end

  test "requires quantity_tier" do
    price = BrandedProductPrice.new(
      product: products(:branded_template_variant),
      size: "8oz",
      price_per_unit: 0.30
    )
    assert_not price.valid?
    assert_includes price.errors[:quantity_tier], "can't be blank"
  end

  test "requires price_per_unit" do
    price = BrandedProductPrice.new(
      product: products(:branded_template_variant),
      size: "8oz",
      quantity_tier: 1000
    )
    assert_not price.valid?
    assert_includes price.errors[:price_per_unit], "can't be blank"
  end

  test "price_per_unit must be positive" do
    price = branded_product_prices(:dw_8oz_1000)
    price.price_per_unit = -0.10
    assert_not price.valid?
    assert_includes price.errors[:price_per_unit], "must be greater than 0"
  end

  test "quantity_tier must be positive" do
    price = branded_product_prices(:dw_8oz_1000)
    price.quantity_tier = -100
    assert_not price.valid?
    assert_includes price.errors[:quantity_tier], "must be greater than 0"
  end

  test "unique combination of product, size, and quantity_tier" do
    duplicate = BrandedProductPrice.new(
      product: products(:branded_template_variant),
      size: "8oz",
      quantity_tier: 1000,
      price_per_unit: 0.25
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:quantity_tier], "has already been taken"
  end

  test "calculates total price" do
    price = branded_product_prices(:dw_8oz_1000)
    expected = price.price_per_unit * price.quantity_tier
    assert_equal expected, price.total_price
  end

  test "find price for configuration" do
    price = BrandedProductPrice.find_for_configuration(
      products(:branded_template_variant),
      "8oz",
      1000
    )
    assert_equal branded_product_prices(:dw_8oz_1000), price
  end

  test "find price returns nil for invalid configuration" do
    price = BrandedProductPrice.find_for_configuration(
      products(:branded_template_variant),
      "99oz",
      1000
    )
    assert_nil price
  end
end
