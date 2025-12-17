require "test_helper"

class BrandedProducts::LidsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cup_product = products(:branded_cup_8oz)
  end

  test "returns compatible lids for 8oz cups" do
    get branded_products_compatible_lids_path,
        params: { product_id: @cup_product.id, size: "8oz" },
        as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json["lids"].is_a?(Array)
    # Should return products with 8oz lid variants
    assert json["lids"].length > 0, "Expected to find lids for 8oz cups"
    json["lids"].each do |lid|
      assert_match /Lid/i, lid["name"], "Product should be a lid"
    end
  end

  test "returns empty array when no compatible lids for size" do
    # 12oz lids are not in fixtures, so should return empty
    get branded_products_compatible_lids_path,
        params: { product_id: @cup_product.id, size: "12oz" },
        as: :json

    assert_response :success
    json = JSON.parse(response.body)

    # No 12oz lid variants exist in fixtures
    assert_equal [], json["lids"]
  end

  test "returns empty array for invalid size" do
    get branded_products_compatible_lids_path,
        params: { product_id: @cup_product.id, size: "99oz" },
        as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal [], json["lids"]
  end

  test "returns empty array when product_id is missing" do
    get branded_products_compatible_lids_path,
        params: { size: "8oz" },
        as: :json

    assert_response :success
    json = JSON.parse(response.body)

    # product_id is required for looking up compatible lids
    assert_equal [], json["lids"]
  end

  test "returns lids with required attributes" do
    get branded_products_compatible_lids_path,
        params: { product_id: @cup_product.id, size: "8oz" },
        as: :json

    json = JSON.parse(response.body)
    lid = json["lids"].first

    # Verify response includes all required attributes
    assert lid["product_id"].present?
    assert lid["variant_id"].present?
    assert lid["name"].present?
    assert lid["price"].present?
    assert lid["pac_size"].present?
    assert lid["sku"].present?
  end
end
