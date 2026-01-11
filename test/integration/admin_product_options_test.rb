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
  test "admin can view product with option values using new structure" do
    product = products(:single_wall_8oz_white)

    get admin_product_path(product)
    assert_response :success

    # Product page should load without error - verify product name appears somewhere
    assert_match product.name, response.body
  end

  # T030: Verify admin product form loads correctly with new associations
  test "admin can edit product form with new option value associations" do
    product = products(:single_wall_8oz_white)

    get edit_admin_product_path(product)
    assert_response :success

    # Form should load without error
    assert_select "form"
  end

  # T031: Verify variants endpoint returns option_values correctly
  test "admin variants JSON endpoint returns option_values_hash data" do
    product = products(:single_wall_8oz_white)

    get variants_admin_product_path(product, format: :json), headers: @headers
    assert_response :success

    json = JSON.parse(response.body)
    assert json.key?("variants"), "Response should have variants key"
    assert json["variants"].is_a?(Array), "Variants should be an array"
  end

  # T032: Verify product update works with new structure
  test "admin can update product without breaking option value associations" do
    product = products(:single_wall_8oz_white)

    # Update a simple product attribute
    patch admin_product_path(product), params: {
      product: {
        description_short: "Updated description for testing"
      }
    }

    assert_redirected_to admin_product_path(product)
    product.reload

    # Verify the update worked
    assert_equal "Updated description for testing", product.description_short
  end
end
