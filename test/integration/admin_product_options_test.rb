# frozen_string_literal: true

require "test_helper"

class AdminProductOptionsTest < ActionDispatch::IntegrationTest
  setup do
    @headers = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" }
    @admin = users(:acme_admin)

    # Sign in as admin
    post session_url, params: { email_address: @admin.email_address, password: "password" }, headers: @headers
  end

  # T029: Verify admin can view products with option values via join table
  test "admin can view product with variants using new option value structure" do
    product = products(:single_wall_cups)

    get admin_product_path(product)
    assert_response :success

    # Product page should load without error - verify product name appears somewhere
    assert_match product.name, response.body
  end

  # T030: Verify admin product form loads correctly with new associations
  test "admin can edit product form with new option value associations" do
    product = products(:single_wall_cups)

    get edit_admin_product_path(product)
    assert_response :success

    # Form should load without error
    assert_select "form"
  end

  # T031: Verify variants endpoint returns option_values correctly
  test "admin variants JSON endpoint returns option_values_hash data" do
    product = products(:single_wall_cups)

    get variants_admin_product_path(product, format: :json), headers: @headers
    assert_response :success

    json = JSON.parse(response.body)
    assert json.key?("variants"), "Response should have variants key"
    assert json["variants"].is_a?(Array), "Variants should be an array"

    # Find a variant that should have option values
    variant_with_options = json["variants"].find { |v| v["option_values"].present? }
    assert variant_with_options, "At least one variant should have option_values"

    # Verify option_values structure
    option_values = variant_with_options["option_values"]
    assert option_values.is_a?(Hash), "option_values should be a hash"
    assert option_values.key?("size") || option_values.key?("colour"),
           "Option values should include size or colour"
  end

  # T032: Verify product update works with new structure
  test "admin can update product without breaking option value associations" do
    product = products(:single_wall_cups)
    original_variant_count = product.variants.count

    # Update a simple product attribute
    patch admin_product_path(product), params: {
      product: {
        description_short: "Updated description for testing"
      }
    }

    assert_redirected_to admin_products_path
    product.reload

    # Verify the update worked
    assert_equal "Updated description for testing", product.description_short

    # Verify variant option values are still intact
    assert_equal original_variant_count, product.variants.count
    variant = product.variants.find_by(sku: "CUP-SW-8-WHT")
    assert variant.option_values_hash.key?("size"), "Variant should still have size option"
    assert variant.option_values_hash.key?("colour"), "Variant should still have colour option"
  end
end
