require "test_helper"

class BrandedProducts::ConfiguratorControllerTest < ActionDispatch::IntegrationTest
  test "calculate pricing returns success for valid configuration" do
    post branded_products_calculate_price_path, params: {
      product_id: products(:branded_template_variant).id,
      size: "8oz",
      quantity: 1000
    }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json["success"]
    assert_equal "0.3", json["price_per_unit"]
    assert_equal "300.0", json["total_price"]
    assert_equal 1000, json["quantity"]
    assert_equal 500, json["case_quantity"]
  end

  test "calculate pricing returns error for invalid size" do
    post branded_products_calculate_price_path, params: {
      product_id: products(:branded_template_variant).id,
      size: "99oz",
      quantity: 1000
    }, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)

    assert_not json["success"]
    assert_not_nil json["error"]
  end

  test "calculate pricing returns error for quantity below minimum" do
    post branded_products_calculate_price_path, params: {
      product_id: products(:branded_template_variant).id,
      size: "8oz",
      quantity: 500
    }, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)

    assert_not json["success"]
    assert_includes json["error"], "minimum"
  end

  test "calculate pricing requires product_id" do
    post branded_products_calculate_price_path, params: {
      size: "8oz",
      quantity: 1000
    }, as: :json

    assert_response :bad_request
  end

  test "available options returns sizes and quantities" do
    get branded_products_available_options_path(product_id: products(:branded_template_variant).id), as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_includes json["sizes"], "8oz"
    assert_includes json["sizes"], "12oz"
    assert json["quantity_tiers"].is_a?(Hash)
    assert_includes json["quantity_tiers"]["8oz"], 1000
  end
end
