require "test_helper"

class SitemapGeneratorServiceTest < ActiveSupport::TestCase
  test "generates valid XML sitemap" do
    service = SitemapGeneratorService.new
    xml = service.generate

    doc = Nokogiri::XML(xml)
    assert_equal "urlset", doc.root.name
    assert_includes doc.root.namespace.href, "sitemaps.org"
  end

  test "includes all active product URLs" do
    service = SitemapGeneratorService.new
    xml = service.generate

    doc = Nokogiri::XML(xml)
    product_urls = doc.xpath("//xmlns:url/xmlns:loc").map(&:text)

    Product.active.catalog_products.find_each do |product|
      assert product_urls.any? { |url| url.include?(product.slug) },
             "Expected sitemap to include product: #{product.slug}"
    end
  end

  test "includes all category URLs except branded-products category" do
    service = SitemapGeneratorService.new
    xml = service.generate

    doc = Nokogiri::XML(xml)
    all_urls = doc.xpath("//xmlns:url/xmlns:loc").map(&:text)

    # branded-products category is excluded because it redirects
    Category.where.not(slug: "branded-products").find_each do |category|
      assert all_urls.any? { |url| url.include?("/categories/#{category.slug}") },
             "Expected sitemap to include category: #{category.slug}"
    end

    # Verify /categories/branded-products is NOT in the sitemap (it redirects)
    refute all_urls.any? { |url| url.include?("/categories/branded-products") },
           "Expected sitemap NOT to include /categories/branded-products category (it redirects)"

    # But /branded-products index page SHOULD be in the sitemap
    assert all_urls.any? { |url| url.end_with?("/branded-products") },
           "Expected sitemap to include /branded-products index page"
  end

  test "includes static pages" do
    service = SitemapGeneratorService.new
    xml = service.generate

    doc = Nokogiri::XML(xml)
    urls = doc.xpath("//xmlns:url/xmlns:loc").map(&:text)

    %w[about contact shop terms privacy faqs branding samples delivery-returns accessibility-statement price-list].each do |page|
      assert urls.any? { |url| url.include?(page) }, "Missing #{page} in sitemap"
    end
  end

  test "excludes branded product templates from /products/ URLs" do
    service = SitemapGeneratorService.new
    xml = service.generate

    doc = Nokogiri::XML(xml)
    product_urls = doc.xpath("//xmlns:url/xmlns:loc").map(&:text)
                      .select { |url| url.include?("/products/") }

    # Branded templates (customizable_template) should NOT appear in /products/ path
    Product.branded.find_each do |branded_product|
      refute product_urls.any? { |url| url.include?("/products/#{branded_product.slug}") },
             "Branded product template #{branded_product.slug} should NOT be in /products/ URLs"
    end
  end

  test "includes branded product templates in /branded-products/ URLs" do
    service = SitemapGeneratorService.new
    xml = service.generate

    doc = Nokogiri::XML(xml)
    branded_urls = doc.xpath("//xmlns:url/xmlns:loc").map(&:text)
                      .select { |url| url.include?("/branded-products/") }

    # All branded templates should appear in /branded-products/ path
    Product.branded.find_each do |branded_product|
      assert branded_urls.any? { |url| url.include?("/branded-products/#{branded_product.slug}") },
             "Branded product template #{branded_product.slug} should be in /branded-products/ URLs"
    end
  end

  test "sets priority and changefreq correctly" do
    service = SitemapGeneratorService.new
    xml = service.generate

    doc = Nokogiri::XML(xml)

    # Check that priority elements exist and home page has highest priority
    priorities = doc.xpath("//xmlns:url/xmlns:priority").map(&:text)
    assert_includes priorities, "1.0", "Should have at least one URL with priority 1.0"
    assert_includes priorities, "0.8", "Should have category URLs with priority 0.8"
  end

  test "includes collections index and individual collection pages" do
    # Create a test collection if none exist
    collection = Collection.find_or_create_by!(slug: "test-collection") do |c|
      c.name = "Test Collection"
      c.sample_pack = false
    end

    service = SitemapGeneratorService.new
    xml = service.generate

    doc = Nokogiri::XML(xml)
    urls = doc.xpath("//xmlns:url/xmlns:loc").map(&:text)

    # Collections index page
    assert urls.any? { |url| url.end_with?("/collections") },
           "Expected sitemap to include /collections index page"

    # Individual collection pages (non-sample packs)
    Collection.where(sample_pack: false).find_each do |col|
      assert urls.any? { |url| url.include?("/collections/#{col.slug}") },
             "Expected sitemap to include collection: #{col.slug}"
    end
  end

  test "includes sample pack pages" do
    # Create a test sample pack if none exist
    sample_pack = Collection.find_or_create_by!(slug: "test-pack") do |c|
      c.name = "Test Sample Pack"
      c.sample_pack = true
    end

    service = SitemapGeneratorService.new
    xml = service.generate

    doc = Nokogiri::XML(xml)
    urls = doc.xpath("//xmlns:url/xmlns:loc").map(&:text)

    # Sample pack pages use /sample-packs/:slug route
    Collection.where(sample_pack: true).find_each do |pack|
      assert urls.any? { |url| url.include?("/sample-packs/#{pack.slug}") },
             "Expected sitemap to include sample pack: #{pack.slug}"
    end

    # Sample packs should NOT appear in /collections/ URLs
    Collection.where(sample_pack: true).find_each do |pack|
      refute urls.any? { |url| url.include?("/collections/#{pack.slug}") },
             "Sample pack #{pack.slug} should NOT be in /collections/ URLs"
    end
  end
end
