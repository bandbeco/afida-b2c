# frozen_string_literal: true

require "test_helper"

class MarkdownForAgentsTest < ActionDispatch::IntegrationTest
  test "home page returns markdown when Accept: text/markdown" do
    get "/", headers: { "Accept" => "text/markdown" }

    assert_response :success
    assert_match(/\Atext\/markdown/, response.headers["Content-Type"])
    assert response.headers["x-markdown-tokens"].present?
    assert_match(/Accept/, response.headers["Vary"].to_s)
  end

  test "home page still returns HTML by default" do
    get "/"

    assert_response :success
    assert_match(/\Atext\/html/, response.headers["Content-Type"])
  end

  test "home page still returns HTML with Accept: text/html" do
    get "/", headers: { "Accept" => "text/html" }

    assert_response :success
    assert_match(/\Atext\/html/, response.headers["Content-Type"])
  end

  test "HEAD Accept markdown advertises the same type and length as GET" do
    headers = { "Accept" => "text/markdown" }
    get "/", headers: headers
    get_length = response.headers["Content-Length"]
    get_type = response.media_type

    head "/", headers: headers

    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_equal get_type, response.media_type
    assert_equal get_length, response.headers["Content-Length"]
    assert_equal "", response.body
  end

  test "product page returns markdown when Accept: text/markdown" do
    product = Product.active.first
    skip "no active product fixture" unless product

    get product_path(slug: product.slug), headers: { "Accept" => "text/markdown" }

    assert_response :success
    assert_match(/\Atext\/markdown/, response.headers["Content-Type"])
    assert response.headers["x-markdown-tokens"].to_i > 0
  end

  test "category page returns markdown when Accept: text/markdown" do
    category = Category.top_level.joins(:children).first
    skip "no top-level category with children fixture" unless category

    get category_path(id: category.slug), headers: { "Accept" => "text/markdown" }

    assert_response :success
    assert_match(/\Atext\/markdown/, response.headers["Content-Type"])
  end
end
