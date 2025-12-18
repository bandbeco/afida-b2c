require "test_helper"

class LegacyRedirectsTest < ActionDispatch::IntegrationTest
  # Category redirects
  test "redirects legacy cold-cups-lids to cups-and-lids" do
    get "/category/cold-cups-lids"
    assert_redirected_to "/categories/cups-and-lids"
    assert_equal 301, response.status
  end

  test "redirects legacy hot-cups to cups-and-lids" do
    get "/category/hot-cups"
    assert_redirected_to "/categories/cups-and-lids"
    assert_equal 301, response.status
  end

  test "redirects legacy hot-cup-extras to cups-and-lids" do
    get "/category/hot-cup-extras"
    assert_redirected_to "/categories/cups-and-lids"
    assert_equal 301, response.status
  end

  test "redirects legacy napkins to napkins" do
    get "/category/napkins"
    assert_redirected_to "/categories/napkins"
    assert_equal 301, response.status
  end

  # Single-product categories redirect directly to product (avoids redirect chain)
  test "redirects legacy pizza-boxes to product" do
    get "/category/pizza-boxes"
    assert_redirected_to "/products/pizza-boxes"
    assert_equal 301, response.status
  end

  test "redirects legacy straws to product" do
    get "/category/straws"
    assert_redirected_to "/products/straws"
    assert_equal 301, response.status
  end

  test "redirects legacy takeaway-containers to takeaway-containers" do
    get "/category/takeaway-containers"
    assert_redirected_to "/categories/takeaway-containers"
    assert_equal 301, response.status
  end

  test "redirects legacy takeaway-extras to takeaway-extras" do
    get "/category/takeaway-extras"
    assert_redirected_to "/categories/takeaway-extras"
    assert_equal 301, response.status
  end

  test "redirects legacy all-products to shop" do
    get "/category/all-products"
    assert_redirected_to "/shop"
    assert_equal 301, response.status
  end

  # Page redirects
  test "redirects branded-packaging to branding" do
    get "/branded-packaging"
    assert_redirected_to "/branding"
    assert_equal 301, response.status
  end

  # Query parameter preservation
  test "preserves query parameters on redirect" do
    get "/category/hot-cups?utm_source=google&utm_campaign=test"
    assert_redirected_to "/categories/cups-and-lids?utm_source=google&utm_campaign=test"
  end

  # New pages
  test "accessibility statement page loads" do
    get "/accessibility-statement"
    assert_response :success
    assert_select "h1", "Accessibility Statement"
  end
end
