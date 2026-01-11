require "test_helper"

class BrandedProductPricingServiceTest < ActiveSupport::TestCase
  setup do
    @product = products(:branded_template_variant)
    @service = BrandedProductPricingService.new(@product)
  end

  test "calculates price for valid configuration" do
    result = @service.calculate(size: "8oz", quantity: 1000)

    assert result.success?
    assert_equal 0.30, result.price_per_unit
    assert_equal 300.00, result.total_price
    assert_equal 1000, result.quantity
  end

  test "uses correct tier pricing based on quantity" do
    # 1500 units should use 1000 tier pricing
    result = @service.calculate(size: "8oz", quantity: 1500)

    assert result.success?
    assert_equal 0.30, result.price_per_unit # 1000 tier
    assert_equal 450.00, result.total_price # 1500 * 0.30
  end

  test "uses higher tier when quantity exceeds threshold" do
    result = @service.calculate(size: "8oz", quantity: 5000)

    assert result.success?
    assert_equal 0.18, result.price_per_unit # 5000 tier
    assert_equal 900.00, result.total_price
  end

  test "returns error for invalid size" do
    result = @service.calculate(size: "99oz", quantity: 1000)

    assert_not result.success?
    assert_equal "No pricing found for this configuration", result.error
  end

  test "returns error for quantity below minimum" do
    result = @service.calculate(size: "8oz", quantity: 500)

    assert_not result.success?
    assert_equal "Quantity below minimum order", result.error
  end

  test "returns error for missing parameters" do
    result = @service.calculate(size: nil, quantity: 1000)

    assert_not result.success?
    assert_includes result.error, "required"
  end

  test "includes case quantity in result" do
    result = @service.calculate(size: "8oz", quantity: 1000)

    assert result.success?
    assert_equal 500, result.case_quantity
  end

  test "calculates number of cases needed" do
    result = @service.calculate(size: "8oz", quantity: 1000)

    assert result.success?
    assert_equal 2, result.cases_needed # 1000 / 500 = 2
  end

  test "available sizes returns all sizes for product" do
    sizes = @service.available_sizes

    assert_includes sizes, "8oz"
    assert_includes sizes, "12oz"
    assert_includes sizes, "16oz"
  end

  test "available quantities returns all tiers for size" do
    quantities = @service.available_quantities("8oz")

    assert_includes quantities, 1000
    assert_includes quantities, 2000
    assert_includes quantities, 5000
  end
end
