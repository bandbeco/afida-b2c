class SitemapGeneratorService
  include Rails.application.routes.url_helpers

  def initialize
    # Set default URL options for URL generation
    default_url_options[:host] = ENV.fetch("APP_HOST", "localhost:3000")
    default_url_options[:protocol] = Rails.env.production? ? "https" : "http"
  end

  def generate
    builder = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
      xml.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
        # Home page
        add_url(xml, root_url, priority: "1.0", changefreq: "daily")

        # Static pages
        add_url(xml, shop_url, priority: "0.9", changefreq: "daily")
        add_url(xml, about_url, priority: "0.5", changefreq: "monthly")
        add_url(xml, contact_url, priority: "0.5", changefreq: "monthly")
        add_url(xml, faqs_url, priority: "0.6", changefreq: "weekly")
        add_url(xml, terms_conditions_url, priority: "0.3", changefreq: "yearly")
        add_url(xml, privacy_policy_url, priority: "0.3", changefreq: "yearly")

        # Categories
        Category.find_each do |category|
          add_url(xml, category_url(category),
                  priority: "0.8",
                  changefreq: "weekly",
                  lastmod: category.updated_at)
        end

        # Products
        Product.includes(:category).find_each do |product|
          add_url(xml, product_url(product),
                  priority: "0.7",
                  changefreq: "weekly",
                  lastmod: product.updated_at)
        end
      end
    end

    builder.to_xml
  end

  private

  def add_url(xml, location, priority:, changefreq:, lastmod: nil)
    xml.url do
      xml.loc location
      xml.lastmod lastmod.iso8601 if lastmod
      xml.changefreq changefreq
      xml.priority priority
    end
  end
end
