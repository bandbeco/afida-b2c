# frozen_string_literal: true

require "application_system_test_case"

class UrlRedirectSystemTest < ApplicationSystemTestCase
  # T040: Browser redirect test
  test "should redirect user in browser from source URL to new product page" do
    product = Product.first

    UrlRedirect.create!(
      source_path: "/product/system-test-redirect",
      target_slug: product.slug,
      variant_params: { size: "12\"" },
      active: true
    )

    # Visit source URL in browser
    visit "/product/system-test-redirect"

    # Verify browser was redirected to product page
    assert_current_path "/products/#{product.slug}", ignore_query: true

    # Verify size parameter is in URL
    assert_match /size=12%22/, current_url
  end
end
