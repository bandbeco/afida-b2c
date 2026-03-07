require "test_helper"

class LegacyRedirectsTest < ActionDispatch::IntegrationTest
  # Legacy /category/* redirects — chained through to final new URLs
  test "redirects legacy cold-cups-lids to cups-and-drinks" do
    get "/category/cold-cups-lids"
    assert_redirected_to "/categories/cups-and-drinks"
    assert_equal 301, response.status
  end

  test "redirects legacy hot-cups to cups-and-drinks" do
    get "/category/hot-cups"
    assert_redirected_to "/categories/cups-and-drinks"
    assert_equal 301, response.status
  end

  test "redirects legacy hot-cup-extras to cups-and-drinks" do
    get "/category/hot-cup-extras"
    assert_redirected_to "/categories/cups-and-drinks"
    assert_equal 301, response.status
  end

  test "redirects legacy napkins to tableware/napkins" do
    get "/category/napkins"
    assert_redirected_to "/categories/tableware/napkins"
    assert_equal 301, response.status
  end

  test "redirects legacy pizza-boxes to hot-food/pizza-boxes" do
    get "/category/pizza-boxes"
    assert_redirected_to "/categories/hot-food/pizza-boxes"
    assert_equal 301, response.status
  end

  test "redirects legacy straws to cups-and-drinks/straws" do
    get "/category/straws"
    assert_redirected_to "/categories/cups-and-drinks/straws"
    assert_equal 301, response.status
  end

  test "redirects legacy takeaway-containers to hot-food" do
    get "/category/takeaway-containers"
    assert_redirected_to "/categories/hot-food"
    assert_equal 301, response.status
  end

  test "redirects legacy takeaway-extras to supplies-and-essentials" do
    get "/category/takeaway-extras"
    assert_redirected_to "/categories/supplies-and-essentials"
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
  test "preserves query parameters on legacy redirect" do
    get "/category/hot-cups?utm_source=google&utm_campaign=test"
    assert_redirected_to "/categories/cups-and-drinks?utm_source=google&utm_campaign=test"
  end

  # New pages
  test "accessibility statement page loads" do
    get "/accessibility-statement"
    assert_response :success
    assert_select "h1", "Accessibility Statement"
  end
end
