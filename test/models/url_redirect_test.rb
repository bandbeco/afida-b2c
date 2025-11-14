# frozen_string_literal: true

require "test_helper"

class UrlRedirectTest < ActiveSupport::TestCase
  # Validation Tests (T005)
  test "should require source_path" do
    redirect = UrlRedirect.new(target_slug: "test-product")
    assert_not redirect.valid?
    assert_includes redirect.errors[:source_path], "can't be blank"
  end

  test "should require target_slug" do
    redirect = UrlRedirect.new(source_path: "/product/test")
    assert_not redirect.valid?
    assert_includes redirect.errors[:target_slug], "can't be blank"
  end

  test "should require source_path to start with /product/" do
    redirect = UrlRedirect.new(
      source_path: "/category/test",
      target_slug: "test-product"
    )
    assert_not redirect.valid?
    assert_includes redirect.errors[:source_path], "must start with /product/"
  end

  test "should require unique source_path (case-insensitive)" do
    product = Product.first

    UrlRedirect.create!(
      source_path: "/product/test",
      target_slug: product.slug
    )

    redirect = UrlRedirect.new(
      source_path: "/product/TEST",  # Different case
      target_slug: product.slug
    )
    assert_not redirect.valid?
    assert_includes redirect.errors[:source_path], "has already been taken"
  end

  test "should validate target_slug exists in products" do
    redirect = UrlRedirect.new(
      source_path: "/product/test",
      target_slug: "nonexistent-product"
    )
    assert_not redirect.valid?
    assert_includes redirect.errors[:target_slug], "product not found"
  end

  test "should be valid with all required attributes" do
    # First create a product to reference
    product = Product.first  # Use any existing product

    redirect = UrlRedirect.new(
      source_path: "/product/test-valid",
      target_slug: product.slug,
      variant_params: { size: "12\"" }
    )
    assert redirect.valid?
  end

  # Scope Tests (T007)
  test "active scope should return only active redirects" do
    product = Product.first

    active1 = UrlRedirect.create!(
      source_path: "/product/active1",
      target_slug: product.slug,
      active: true
    )
    active2 = UrlRedirect.create!(
      source_path: "/product/active2",
      target_slug: product.slug,
      active: true
    )
    inactive = UrlRedirect.create!(
      source_path: "/product/inactive",
      target_slug: product.slug,
      active: false
    )

    active_redirects = UrlRedirect.active
    assert_includes active_redirects, active1
    assert_includes active_redirects, active2
    assert_not_includes active_redirects, inactive
  end

  test "inactive scope should return only inactive redirects" do
    product = Product.first

    active = UrlRedirect.create!(
      source_path: "/product/active",
      target_slug: product.slug,
      active: true
    )
    inactive1 = UrlRedirect.create!(
      source_path: "/product/inactive1",
      target_slug: product.slug,
      active: false
    )
    inactive2 = UrlRedirect.create!(
      source_path: "/product/inactive2",
      target_slug: product.slug,
      active: false
    )

    inactive_redirects = UrlRedirect.inactive
    assert_includes inactive_redirects, inactive1
    assert_includes inactive_redirects, inactive2
    assert_not_includes inactive_redirects, active
  end

  test "most_used scope should order by hit_count descending" do
    product = Product.first

    low = UrlRedirect.create!(
      source_path: "/product/low",
      target_slug: product.slug,
      hit_count: 5
    )
    high = UrlRedirect.create!(
      source_path: "/product/high",
      target_slug: product.slug,
      hit_count: 100
    )
    medium = UrlRedirect.create!(
      source_path: "/product/medium",
      target_slug: product.slug,
      hit_count: 50
    )

    ordered = UrlRedirect.most_used.to_a
    assert_equal high, ordered.first
    assert_equal medium, ordered.second
    assert_equal low, ordered.third
  end

  # Class Method Tests (T009)
  test "find_by_path should find redirect by exact path" do
    product = Product.first
    redirect = UrlRedirect.create!(
      source_path: "/product/test-exact",
      target_slug: product.slug
    )

    found = UrlRedirect.find_by_path("/product/test-exact")
    assert_equal redirect, found
  end

  test "find_by_path should be case-insensitive" do
    product = Product.first
    redirect = UrlRedirect.create!(
      source_path: "/product/test-case",
      target_slug: product.slug
    )

    found = UrlRedirect.find_by_path("/product/TEST-CASE")
    assert_equal redirect, found
  end

  test "find_by_path should return nil when not found" do
    found = UrlRedirect.find_by_path("/product/nonexistent")
    assert_nil found
  end

  # Instance Method Tests (T011)
  test "record_hit! should increment hit_count" do
    product = Product.first
    redirect = UrlRedirect.create!(
      source_path: "/product/test-hit",
      target_slug: product.slug,
      hit_count: 5
    )

    redirect.record_hit!
    assert_equal 6, redirect.reload.hit_count
  end

  test "target_url should build URL with variant parameters" do
    product = Product.first
    redirect = UrlRedirect.create!(
      source_path: "/product/test-url",
      target_slug: product.slug,
      variant_params: { size: "12\"", colour: "Kraft" }
    )

    expected_url = "/products/#{product.slug}?colour=Kraft&size=12%22"
    assert_equal expected_url, redirect.target_url
  end

  test "target_url should handle empty variant_params" do
    product = Product.first
    redirect = UrlRedirect.create!(
      source_path: "/product/test-no-params",
      target_slug: product.slug,
      variant_params: {}
    )

    expected_url = "/products/#{product.slug}"
    assert_equal expected_url, redirect.target_url
  end

  test "deactivate! should set active to false" do
    product = Product.first
    redirect = UrlRedirect.create!(
      source_path: "/product/test-deactivate",
      target_slug: product.slug,
      active: true
    )

    redirect.deactivate!
    assert_equal false, redirect.reload.active
  end

  test "activate! should set active to true" do
    product = Product.first
    redirect = UrlRedirect.create!(
      source_path: "/product/test-activate",
      target_slug: product.slug,
      active: false
    )

    redirect.activate!
    assert_equal true, redirect.reload.active
  end
end
