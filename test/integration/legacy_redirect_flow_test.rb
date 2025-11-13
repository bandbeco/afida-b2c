# frozen_string_literal: true

require "test_helper"

class LegacyRedirectFlowTest < ActionDispatch::IntegrationTest
  # T037: End-to-end redirect flow
  test "should redirect legacy URL to new product page with variant" do
    product = Product.first

    redirect = LegacyRedirect.create!(
      legacy_path: "/product/integration-test-redirect",
      target_slug: product.slug,
      variant_params: { size: "12\"", colour: "Kraft" },
      active: true,
      hit_count: 0
    )

    # Make request to legacy URL
    get "/product/integration-test-redirect"

    # Verify 301 redirect
    assert_response :moved_permanently

    # Verify redirected to correct product (query param order may vary)
    location = response.headers["Location"]
    assert_includes location, "/products/#{product.slug}"
    assert_includes location, "size=12%22"
    assert_includes location, "colour=Kraft"

    # Verify hit counter was incremented
    assert_equal 1, redirect.reload.hit_count
  end

  # T038: Variant selection flow
  test "should redirect with variant selection and preserve query parameters" do
    product = Product.first

    LegacyRedirect.create!(
      legacy_path: "/product/variant-test",
      target_slug: product.slug,
      variant_params: { size: "8oz" },
      active: true
    )

    # Make request with existing query parameters
    get "/product/variant-test?utm_source=google&ref=email"

    # Verify 301 redirect
    assert_response :moved_permanently

    # Verify variant and UTM parameters are both preserved
    location = response.headers["Location"]
    assert_includes location, "size=8oz"
    assert_includes location, "utm_source=google"
    assert_includes location, "ref=email"
  end

  # Additional test: inactive redirect should 404
  test "should return 404 for inactive redirect" do
    product = Product.first

    LegacyRedirect.create!(
      legacy_path: "/product/inactive-test",
      target_slug: product.slug,
      active: false
    )

    # Make request to legacy URL
    get "/product/inactive-test"

    # Should pass through to routing, resulting in 404
    assert_response :not_found
  end
end
