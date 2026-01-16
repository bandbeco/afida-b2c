require "test_helper"

class VariantSeoTest < ActionDispatch::IntegrationTest
  setup do
    @variant = products(:single_wall_8oz_white)
    @variant2 = products(:single_wall_8oz_black)
  end

  test "variant pages have unique titles" do
    get product_path(@variant.slug)
    title1 = css_select("title").text

    get product_path(@variant2.slug)
    title2 = css_select("title").text

    assert_not_equal title1, title2, "Variant pages should have unique titles"
  end

  test "variant page title includes variant name" do
    get product_path(@variant.slug)
    title = css_select("title").text

    assert_includes title.downcase, @variant.name.downcase
  end

  test "variant page has meta description" do
    get product_path(@variant.slug)

    meta_desc = css_select("meta[name='description']").first
    assert meta_desc, "Variant page should have meta description"
    assert meta_desc["content"].present?, "Meta description should not be empty"
  end

  test "variant page has canonical URL" do
    get product_path(@variant.slug)

    canonical = css_select("link[rel='canonical']").first
    assert canonical, "Variant page should have canonical URL"
    assert_includes canonical["href"], @variant.slug
  end

  test "variant page has product structured data" do
    get product_path(@variant.slug)

    # Find JSON-LD script tags
    json_ld_scripts = css_select("script[type='application/ld+json']")
    assert json_ld_scripts.any?, "Should have JSON-LD structured data"

    # Parse and check for Product schema
    product_data = nil
    json_ld_scripts.each do |script|
      data = JSON.parse(script.content)
      if data["@type"] == "Product"
        product_data = data
        break
      end
    end

    assert product_data, "Should have Product structured data"
    # Uses generated_title (size + colour + name), not full_name (product_family + name)
    assert_equal @variant.generated_title, product_data["name"]
  end

  test "variant page has breadcrumb structured data" do
    get product_path(@variant.slug)

    json_ld_scripts = css_select("script[type='application/ld+json']")

    breadcrumb_data = nil
    json_ld_scripts.each do |script|
      data = JSON.parse(script.content)
      if data["@type"] == "BreadcrumbList"
        breadcrumb_data = data
        break
      end
    end

    assert breadcrumb_data, "Should have BreadcrumbList structured data"
    assert breadcrumb_data["itemListElement"].length >= 2, "Should have at least 2 breadcrumb items"
  end

  test "sitemap includes all active products" do
    get "/sitemap.xml"
    assert_response :success

    sitemap_content = response.body

    # Check that active products are included (sitemap uses /products/:slug format)
    active_products = Product.active
    active_products.limit(5).each do |product|
      # Sitemap includes products under /products/ path
      assert_includes sitemap_content, "/products/#{product.slug}",
        "Sitemap should include product: #{product.slug}"
    end
  end

  test "inactive variants excluded from sitemap" do
    inactive_variant = products(:two)
    inactive_variant.update!(active: false)

    get "/sitemap.xml"
    assert_response :success

    # Check the inactive variant slug is not in the sitemap
    # Note: we check for the specific URL pattern to avoid false positives
    assert_not_includes response.body, "/products/#{inactive_variant.slug}",
      "Sitemap should not include inactive variants"
  end
end
