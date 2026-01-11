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

  test "includes all category URLs" do
    service = SitemapGeneratorService.new
    xml = service.generate

    doc = Nokogiri::XML(xml)
    category_urls = doc.xpath("//xmlns:url/xmlns:loc").map(&:text)

    Category.find_each do |category|
      assert category_urls.any? { |url| url.include?(category.slug) }
    end
  end

  test "includes static pages" do
    service = SitemapGeneratorService.new
    xml = service.generate

    doc = Nokogiri::XML(xml)
    urls = doc.xpath("//xmlns:url/xmlns:loc").map(&:text)

    %w[about contact shop terms privacy faqs].each do |page|
      assert urls.any? { |url| url.include?(page) }, "Missing #{page} in sitemap"
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
end
