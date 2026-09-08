# frozen_string_literal: true

require "test_helper"

class AgentCatalogApiTest < ActionDispatch::IntegrationTest
  test "lists active catalog products as JSON" do
    get "/api/v1/products", params: { per_page: 100 }

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
    assert_nil cookies[:datafast_visitor_id]
    assert_nil response.headers["WWW-Authenticate"]

    body = response.parsed_body
    slugs = body["data"].map { |row| row["slug"] }
    assert_includes slugs, products(:one).slug
    refute_includes slugs, products(:inactive_product).slug

    product = body["data"].find { |row| row["slug"] == products(:one).slug }
    assert_equal products(:one).sku, product["sku"]
    assert_equal "GBP", product.dig("price", "currency")
    assert product["url"].include?("/products/#{products(:one).slug}")
  end

  test "filters products by search query" do
    get "/api/v1/products", params: { q: products(:one).sku }

    slugs = response.parsed_body["data"].map { |row| row["slug"] }
    assert_includes slugs, products(:one).slug
    refute_includes slugs, products(:two).slug
  end

  test "shows a product by slug" do
    product = products(:one)
    get "/api/v1/products/#{product.slug}"

    assert_response :success
    body = response.parsed_body["data"]
    assert_equal product.slug, body["slug"]
    assert_equal product.sku, body["sku"]
    assert body["description"].present?
  end

  test "unknown product slug is 404" do
    get "/api/v1/products/not-a-real-product"
    assert_response :not_found
  end

  test "lists categories with nested children" do
    get "/api/v1/categories"

    assert_response :success
    slugs = response.parsed_body["data"].map { |row| row["slug"] }
    assert_includes slugs, categories(:one).slug
  end

  test "catalog endpoints do not require authentication" do
    get "/api/v1/products/#{products(:one).slug}"
    assert_response :success

    get "/api/v1/categories"
    assert_response :success
    assert_nil response.headers["WWW-Authenticate"]
  end

  test "shows a category by slug" do
    get "/api/v1/categories/#{categories(:one).slug}"

    assert_response :success
    body = response.parsed_body["data"]
    assert_equal categories(:one).slug, body["slug"]
    assert_equal categories(:one).name, body["name"]
  end
end
