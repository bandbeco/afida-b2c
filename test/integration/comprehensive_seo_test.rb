require "test_helper"

class ComprehensiveSeoTest < ActionDispatch::IntegrationTest
  test "all public pages have canonical URLs" do
    [ root_path, shop_path, about_path, contact_path ].each do |page|
      get page
      # Check for canonical in the response body
      assert_includes response.body, 'rel="canonical"', "Missing canonical on #{page}"
    end
  end

  test "sitemap includes all important pages" do
    get sitemap_path(format: :xml)
    assert_response :success
    # Check for actual paths in sitemap, not full URLs since host may vary
    assert_includes response.body, "/shop"
    assert_includes response.body, "<loc>"
  end

  test "robots txt includes sitemap" do
    get "/robots.txt"
    assert_includes response.body, "/sitemap.xml"
  end

  test "product pages have structured data" do
    product = products(:single_wall_cups)
    get product_path(product)
    assert_includes response.body, '"@type":"Product"'
    assert_includes response.body, '"@type":"BreadcrumbList"'
  end

  test "category pages have structured data" do
    # Use hot_cups_extras which has multiple products (won't redirect)
    category = categories(:hot_cups_extras)
    get category_path(category)
    assert_includes response.body, '"@type":"CollectionPage"'
    assert_includes response.body, '"@type":"BreadcrumbList"'
  end

  test "home page has comprehensive meta tags" do
    get root_path
    assert_select 'meta[property="og:type"]'
    assert_select 'meta[name="twitter:card"]'
    assert_select 'link[rel="canonical"]'
  end
end
