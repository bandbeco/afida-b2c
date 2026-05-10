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

  test "redirects /cookies-policy to privacy-policy cookies section" do
    get "/cookies-policy"
    assert_redirected_to "/privacy-policy#cookies"
    assert_equal 301, response.status
  end

  # Legacy Wix homepage / catch-all aliases
  test "redirects legacy index.php to root" do
    get "/index.php"
    assert_redirected_to "/"
    assert_equal 301, response.status
  end

  test "redirects legacy /home to root" do
    get "/home"
    assert_redirected_to "/"
    assert_equal 301, response.status
  end

  test "redirects legacy /blank-3 to root" do
    get "/blank-3"
    assert_redirected_to "/"
    assert_equal 301, response.status
  end

  # Legacy Wix collection
  test "redirects legacy /collections/paper-straws to straws category" do
    get "/collections/paper-straws"
    assert_redirected_to "/categories/cups-and-drinks/straws"
    assert_equal 301, response.status
  end

  # Legacy Wix /product-page/* redirects
  test "redirects legacy 12oz double-wall ripple cup to current ripple cup" do
    get "/product-page/12oz-340ml-double-wall-ripple-paper-hot-cup"
    assert_redirected_to "/products/ripple-wall-coffee-cups-12oz-340ml-kraft-paper"
    assert_equal 301, response.status
  end

  test "redirects legacy 8oz black double-wall ripple cup to current 8oz black ripple cup" do
    get "/product-page/8oz-227ml-double-wall-ripple-paper-hot-cup-black"
    assert_redirected_to "/products/ripple-wall-coffee-cups-8oz-227ml-black-paper"
    assert_equal 301, response.status
  end

  test "redirects legacy 6mm bamboo fibre straws (black) to bamboo pulp straws" do
    get "/product-page/6mm-x-200mm-bamboo-fibre-straws-black"
    assert_redirected_to "/products/straws-6-x-200mm-bamboo-pulp"
    assert_equal 301, response.status
  end

  test "redirects legacy 6mm bamboo fibre straws (natural) to bamboo pulp straws" do
    get "/product-page/6mm-x-200mm-bamboo-fibre-straws-natural"
    assert_redirected_to "/products/straws-6-x-200mm-bamboo-pulp"
    assert_equal 301, response.status
  end

  test "redirects legacy 4-fold white 2ply dinner napkins to current product" do
    get "/product-page/4-fold-white-2ply-dinner-napkins-40cm-x-40cm"
    assert_redirected_to "/products/4-fold-2-ply-dinner-napkins-40-x-40cm-white-paper"
    assert_equal 301, response.status
  end

  test "redirects legacy no-3 kraft deli box to takeaway box no-3 kraft" do
    get "/product-page/no-3-kraft-deli-box-70oz"
    assert_redirected_to "/products/takeaway-boxes-no-3-1900ml-69oz-kraft"
    assert_equal 301, response.status
  end

  # Catch-all for unmapped /product-page/* paths (sends to shop)
  test "unmapped /product-page paths fall back to /shop" do
    get "/product-page/some-deleted-old-product"
    assert_redirected_to "/shop"
    assert_equal 301, response.status
  end

  # Query string preservation on legacy product redirect
  test "preserves query parameters on legacy product-page redirect" do
    get "/product-page/12oz-340ml-double-wall-ripple-paper-hot-cup?utm_source=google"
    assert_redirected_to "/products/ripple-wall-coffee-cups-12oz-340ml-kraft-paper?utm_source=google"
  end
end
