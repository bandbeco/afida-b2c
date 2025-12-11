# Comprehensive SEO Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement comprehensive programmatic SEO across the entire Rails e-commerce application including structured data, sitemaps, canonical URLs, and meta tags for all pages.

**Architecture:** Implement SEO in phases starting with high-impact changes (structured data, sitemap, canonical URLs) then medium-priority (meta tags for all pages, robots.txt), and finally low-priority enhancements. Use Rails helpers for DRY meta tag generation, service objects for sitemap generation, and view concerns for structured data.

**Tech Stack:** Rails 8.1, Nokogiri (XML generation), ActiveSupport::Concern (view helpers), Stimulus (if needed for dynamic updates)

---

## Phase 1: Foundation - Structured Data & Canonical URLs

### Task 1: Create SEO Helper Module

**Files:**
- Create: `app/helpers/seo_helper.rb`
- Test: `test/helpers/seo_helper_test.rb`

**Step 1: Write the failing test**

```ruby
# test/helpers/seo_helper_test.rb
require "test_helper"

class SeoHelperTest < ActionView::TestCase
  test "generates product JSON-LD structured data" do
    product = products(:kraft_pizza_box)
    variant = product.active_variants.first

    json = product_structured_data(product, variant)
    data = JSON.parse(json)

    assert_equal "https://schema.org/", data["@context"]
    assert_equal "Product", data["@type"]
    assert_equal product.name, data["name"]
    assert_equal "Afida", data["brand"]["name"]
    assert_includes json, "offers"
  end

  test "generates organization JSON-LD structured data" do
    json = organization_structured_data
    data = JSON.parse(json)

    assert_equal "Organization", data["@type"]
    assert_equal "Afida", data["name"]
    assert_includes json, "contactPoint"
  end

  test "generates breadcrumb JSON-LD structured data" do
    items = [
      { name: "Home", url: root_url },
      { name: "Category", url: category_url("cups") }
    ]

    json = breadcrumb_structured_data(items)
    data = JSON.parse(json)

    assert_equal "BreadcrumbList", data["@type"]
    assert_equal 2, data["itemListElement"].length
  end
end
```

**Step 2: Run test to verify it fails**

Run: `rails test test/helpers/seo_helper_test.rb`
Expected: FAIL with "undefined method `product_structured_data`"

**Step 3: Write minimal implementation**

```ruby
# app/helpers/seo_helper.rb
module SeoHelper
  def product_structured_data(product, variant)
    data = {
      "@context": "https://schema.org/",
      "@type": "Product",
      "name": product.name,
      "description": product.description,
      "brand": {
        "@type": "Brand",
        "name": "Afida"
      },
      "offers": {
        "@type": "Offer",
        "price": variant.price.to_s,
        "priceCurrency": "GBP",
        "availability": variant.in_stock? ? "https://schema.org/InStock" : "https://schema.org/OutOfStock",
        "url": product_url(product, variant_id: variant.id)
      }
    }

    # Add image if available
    if product.product_photo.attached?
      data[:image] = url_for(product.product_photo)
    end

    # Add SKU/GTIN
    data[:sku] = variant.sku if variant.sku.present?
    data[:gtin] = variant.gtin if variant.respond_to?(:gtin) && variant.gtin.present?

    data.to_json
  end

  def organization_structured_data
    {
      "@context": "https://schema.org",
      "@type": "Organization",
      "name": "Afida",
      "url": root_url,
      "logo": vite_asset_url("images/logo.svg"),
      "contactPoint": {
        "@type": "ContactPoint",
        "contactType": "Customer Service",
        "email": "hello@afida.com"
      },
      "sameAs": [
        # Add social media URLs when available
      ]
    }.to_json
  end

  def breadcrumb_structured_data(items)
    {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      "itemListElement": items.map.with_index do |item, index|
        {
          "@type": "ListItem",
          "position": index + 1,
          "name": item[:name],
          "item": item[:url]
        }
      end
    }.to_json
  end

  def canonical_url(url = nil)
    tag.link rel: "canonical", href: url || request.original_url
  end
end
```

**Step 4: Run test to verify it passes**

Run: `rails test test/helpers/seo_helper_test.rb`
Expected: PASS (all 3 tests)

**Step 5: Commit**

```bash
git add app/helpers/seo_helper.rb test/helpers/seo_helper_test.rb
git commit -m "feat: add SEO helper for structured data and canonical URLs"
```

---

### Task 2: Add Canonical URLs to Application Layout

**Files:**
- Modify: `app/views/layouts/application.html.erb:12`

**Step 1: Add canonical URL helper to layout**

```erb
<!-- app/views/layouts/application.html.erb -->
<!-- Add after line 12 (after <%= yield :head %>) -->
<%= canonical_url %>
```

**Step 2: Write system test to verify canonical URL**

```ruby
# test/system/seo_test.rb
require "application_system_test_case"

class SeoTest < ApplicationSystemTestCase
  test "product pages have canonical URLs" do
    product = products(:kraft_pizza_box)
    visit product_path(product)

    canonical = page.find('link[rel="canonical"]', visible: false)
    assert_includes canonical[:href], product_path(product)
  end

  test "category pages have canonical URLs" do
    category = categories(:pizza_boxes)
    visit category_path(category)

    canonical = page.find('link[rel="canonical"]', visible: false)
    assert_includes canonical[:href], category_path(category)
  end
end
```

**Step 3: Run system test**

Run: `rails test:system test/system/seo_test.rb`
Expected: PASS

**Step 4: Commit**

```bash
git add app/views/layouts/application.html.erb test/system/seo_test.rb
git commit -m "feat: add canonical URLs to all pages"
```

---

### Task 3: Add Structured Data to Product Pages

**Files:**
- Modify: `app/views/products/_standard_product.html.erb:46`

**Step 1: Add structured data script tag to product page**

```erb
<!-- app/views/products/_standard_product.html.erb -->
<!-- Add after line 46 (after closing of content_for :head) -->
<script type="application/ld+json">
  <%= raw product_structured_data(@product, @selected_variant) %>
</script>

<script type="application/ld+json">
  <%= raw breadcrumb_structured_data([
    { name: "Home", url: root_url },
    { name: @product.category.name, url: category_url(@product.category) },
    { name: @product.name, url: product_url(@product) }
  ]) %>
</script>
```

**Step 2: Write system test to verify structured data**

```ruby
# test/system/product_structured_data_test.rb
require "application_system_test_case"

class ProductStructuredDataTest < ApplicationSystemTestCase
  test "product page includes product structured data" do
    product = products(:kraft_pizza_box)
    visit product_path(product)

    script_tags = page.all('script[type="application/ld+json"]', visible: false)
    assert script_tags.any? { |tag| tag.text.include?('"@type":"Product"') }
    assert script_tags.any? { |tag| tag.text.include?(product.name) }
  end

  test "product page includes breadcrumb structured data" do
    product = products(:kraft_pizza_box)
    visit product_path(product)

    script_tags = page.all('script[type="application/ld+json"]', visible: false)
    breadcrumb_tag = script_tags.find { |tag| tag.text.include?('"@type":"BreadcrumbList"') }

    assert_not_nil breadcrumb_tag
    assert_includes breadcrumb_tag.text, "Home"
    assert_includes breadcrumb_tag.text, product.category.name
  end
end
```

**Step 3: Run system test**

Run: `rails test:system test/system/product_structured_data_test.rb`
Expected: PASS

**Step 4: Commit**

```bash
git add app/views/products/_standard_product.html.erb test/system/product_structured_data_test.rb
git commit -m "feat: add structured data to product pages"
```

---

### Task 4: Add Structured Data to Branded Product Pages

**Files:**
- Modify: `app/views/products/_branded_configurator.html.erb:7`

**Step 1: Add structured data to branded products**

```erb
<!-- app/views/products/_branded_configurator.html.erb -->
<!-- Add after line 7 (after meta_description content_for) -->

<% content_for :head do %>
  <script type="application/ld+json">
    <%= raw({
      "@context": "https://schema.org/",
      "@type": "Product",
      "name": @product.name,
      "description": @product.description,
      "brand": {
        "@type": "Brand",
        "name": "Afida"
      },
      "image": @product.product_photo.attached? ? url_for(@product.product_photo) : nil,
      "offers": {
        "@type": "AggregateOffer",
        "priceCurrency": "GBP",
        "availability": "https://schema.org/InStock",
        "url": product_url(@product)
      }
    }.compact.to_json) %>
  </script>

  <script type="application/ld+json">
    <%= raw breadcrumb_structured_data([
      { name: "Home", url: root_url },
      { name: @product.category.name, url: category_url(@product.category) },
      { name: @product.name, url: product_url(@product) }
    ]) %>
  </script>
<% end %>
```

**Step 2: Commit**

```bash
git add app/views/products/_branded_configurator.html.erb
git commit -m "feat: add structured data to branded product pages"
```

---

### Task 5: Add Organization Structured Data to Footer

**Files:**
- Modify: `app/views/shared/_footer.html.erb` or `app/views/layouts/application.html.erb`

**Step 1: Check if footer partial exists**

Run: `ls app/views/shared/_footer.html.erb`

**Step 2: Add organization schema**

If footer exists:
```erb
<!-- app/views/shared/_footer.html.erb -->
<!-- Add before closing footer tag -->
<script type="application/ld+json">
  <%= raw organization_structured_data %>
</script>
```

If no footer, add to application layout:
```erb
<!-- app/views/layouts/application.html.erb -->
<!-- Add before closing </body> tag -->
<script type="application/ld+json">
  <%= raw organization_structured_data %>
</script>
```

**Step 3: Commit**

```bash
git add app/views/shared/_footer.html.erb
# OR
git add app/views/layouts/application.html.erb
git commit -m "feat: add organization structured data"
```

---

## Phase 2: XML Sitemap Generation

### Task 6: Create Sitemap Service

**Files:**
- Create: `app/services/sitemap_generator_service.rb`
- Test: `test/services/sitemap_generator_service_test.rb`

**Step 1: Write the failing test**

```ruby
# test/services/sitemap_generator_service_test.rb
require "test_helper"

class SitemapGeneratorServiceTest < ActiveSupport::TestCase
  test "generates valid XML sitemap" do
    service = SitemapGeneratorService.new
    xml = service.generate

    doc = Nokogiri::XML(xml)
    assert_equal "urlset", doc.root.name
    assert_includes doc.root.namespace.href, "sitemaps.org"
  end

  test "includes all product URLs" do
    service = SitemapGeneratorService.new
    xml = service.generate

    doc = Nokogiri::XML(xml)
    product_urls = doc.xpath("//xmlns:url/xmlns:loc").map(&:text)

    Product.find_each do |product|
      assert product_urls.any? { |url| url.include?(product.slug) }
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

    %w[about contact shop terms privacy].each do |page|
      assert urls.any? { |url| url.include?(page) }, "Missing #{page} in sitemap"
    end
  end

  test "sets priority and changefreq correctly" do
    service = SitemapGeneratorService.new
    xml = service.generate

    doc = Nokogiri::XML(xml)

    # Home page should have highest priority
    home_url = doc.xpath("//xmlns:url[contains(xmlns:loc, '#{Rails.application.routes.url_helpers.root_url}')]/xmlns:priority").first
    assert_equal "1.0", home_url.text if home_url
  end
end
```

**Step 2: Run test to verify it fails**

Run: `rails test test/services/sitemap_generator_service_test.rb`
Expected: FAIL with "uninitialized constant SitemapGeneratorService"

**Step 3: Write minimal implementation**

```ruby
# app/services/sitemap_generator_service.rb
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
        add_url(xml, terms_url, priority: "0.3", changefreq: "yearly")
        add_url(xml, privacy_url, priority: "0.3", changefreq: "yearly")

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
```

**Step 4: Run test to verify it passes**

Run: `rails test test/services/sitemap_generator_service_test.rb`
Expected: PASS (all tests)

**Step 5: Commit**

```bash
git add app/services/sitemap_generator_service.rb test/services/sitemap_generator_service_test.rb
git commit -m "feat: add sitemap generator service"
```

---

### Task 7: Create Sitemap Controller and Route

**Files:**
- Create: `app/controllers/sitemaps_controller.rb`
- Modify: `config/routes.rb`
- Test: `test/controllers/sitemaps_controller_test.rb`

**Step 1: Write the failing test**

```ruby
# test/controllers/sitemaps_controller_test.rb
require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "should get sitemap xml" do
    get sitemap_url(format: :xml)
    assert_response :success
    assert_equal "application/xml; charset=utf-8", response.content_type
  end

  test "sitemap includes products" do
    get sitemap_url(format: :xml)

    product = products(:kraft_pizza_box)
    assert_includes response.body, product.slug
  end

  test "sitemap is valid XML" do
    get sitemap_url(format: :xml)

    doc = Nokogiri::XML(response.body)
    errors = doc.errors
    assert_empty errors, "Sitemap XML has errors: #{errors.map(&:message).join(', ')}"
  end
end
```

**Step 2: Run test to verify it fails**

Run: `rails test test/controllers/sitemaps_controller_test.rb`
Expected: FAIL with "No route matches"

**Step 3: Add route**

```ruby
# config/routes.rb
# Add after the google_merchant_feed route (around line 62)
get "sitemap.xml", to: "sitemaps#show", defaults: { format: :xml }, as: :sitemap
```

**Step 4: Create controller**

```ruby
# app/controllers/sitemaps_controller.rb
class SitemapsController < ApplicationController
  allow_unauthenticated_access

  def show
    @sitemap_xml = SitemapGeneratorService.new.generate

    respond_to do |format|
      format.xml { render xml: @sitemap_xml }
    end
  end
end
```

**Step 5: Run test to verify it passes**

Run: `rails test test/controllers/sitemaps_controller_test.rb`
Expected: PASS

**Step 6: Commit**

```bash
git add app/controllers/sitemaps_controller.rb config/routes.rb test/controllers/sitemaps_controller_test.rb
git commit -m "feat: add sitemap controller and route"
```

---

### Task 8: Update Robots.txt with Sitemap Reference

**Files:**
- Create: `app/controllers/robots_controller.rb`
- Modify: `config/routes.rb`
- Delete: `public/robots.txt`

**Step 1: Create dynamic robots controller**

```ruby
# app/controllers/robots_controller.rb
class RobotsController < ApplicationController
  allow_unauthenticated_access

  def show
    respond_to do |format|
      format.text do
        render plain: robots_txt_content, content_type: "text/plain"
      end
    end
  end

  private

  def robots_txt_content
    base_url = "#{request.protocol}#{request.host_with_port}"

    <<~ROBOTS
      User-agent: *
      Allow: /

      # Disallow admin and checkout areas
      Disallow: /admin/
      Disallow: /cart
      Disallow: /checkout

      # Sitemap
      Sitemap: #{base_url}/sitemap.xml
    ROBOTS
  end
end
```

**Step 2: Add route**

```ruby
# config/routes.rb
# Add after sitemap route
get "robots.txt", to: "robots#show", defaults: { format: :text }
```

**Step 3: Test the dynamic robots.txt**

```ruby
# test/controllers/robots_controller_test.rb
require "test_helper"

class RobotsControllerTest < ActionDispatch::IntegrationTest
  test "should get robots txt" do
    get robots_url(format: :txt)
    assert_response :success
    assert_equal "text/plain; charset=utf-8", response.content_type
  end

  test "robots txt includes sitemap" do
    get robots_url(format: :txt)
    assert_includes response.body, "Sitemap:"
    assert_includes response.body, "/sitemap.xml"
  end

  test "robots txt disallows admin" do
    get robots_url(format: :txt)
    assert_includes response.body, "Disallow: /admin/"
  end
end
```

**Step 4: Run test**

Run: `rails test test/controllers/robots_controller_test.rb`
Expected: PASS

**Step 5: Remove old static robots.txt**

Run: `rm public/robots.txt`

**Step 6: Commit**

```bash
git rm public/robots.txt
git add app/controllers/robots_controller.rb config/routes.rb test/controllers/robots_controller_test.rb
git commit -m "feat: convert robots.txt to dynamic route with sitemap reference"
```

---

## Phase 3: Meta Tags for All Pages

### Task 9: Add Meta Tags to Home Page

**Files:**
- Modify: `app/views/pages/home.html.erb`

**Step 1: Add meta tags to home page view**

```erb
<!-- app/views/pages/home.html.erb -->
<!-- Add at the very top of the file -->
<% content_for :title, "Premium Eco-Friendly Catering Supplies | Afida" %>

<% content_for :meta_description, "Discover sustainable catering supplies for your business. Premium quality eco-friendly packaging including pizza boxes, ice cream cups, napkins, and takeaway containers. Fast UK delivery." %>

<% content_for :head do %>
  <!-- Open Graph -->
  <meta property="og:type" content="website">
  <meta property="og:title" content="Premium Eco-Friendly Catering Supplies | Afida">
  <meta property="og:description" content="Discover sustainable catering supplies for your business. Premium quality eco-friendly packaging with fast UK delivery.">
  <meta property="og:url" content="<%= root_url %>">
  <meta property="og:site_name" content="Afida">

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="Premium Eco-Friendly Catering Supplies | Afida">
  <meta name="twitter:description" content="Discover sustainable catering supplies for your business. Premium quality eco-friendly packaging with fast UK delivery.">
<% end %>

<!-- Rest of existing home page content -->
```

**Step 2: Test home page meta tags**

```ruby
# test/system/home_page_seo_test.rb
require "application_system_test_case"

class HomePageSeoTest < ApplicationSystemTestCase
  test "home page has title tag" do
    visit root_path
    assert_title "Premium Eco-Friendly Catering Supplies | Afida"
  end

  test "home page has meta description" do
    visit root_path

    meta_desc = page.find('meta[name="description"]', visible: false)
    assert_includes meta_desc[:content], "sustainable catering supplies"
  end

  test "home page has Open Graph tags" do
    visit root_path

    og_title = page.find('meta[property="og:title"]', visible: false)
    assert_equal "Premium Eco-Friendly Catering Supplies | Afida", og_title[:content]

    og_type = page.find('meta[property="og:type"]', visible: false)
    assert_equal "website", og_type[:content]
  end
end
```

**Step 3: Run test**

Run: `rails test:system test/system/home_page_seo_test.rb`
Expected: PASS

**Step 4: Commit**

```bash
git add app/views/pages/home.html.erb test/system/home_page_seo_test.rb
git commit -m "feat: add comprehensive meta tags to home page"
```

---

### Task 10-17: Add Meta Tags to Remaining Static Pages

**Note:** For brevity, these tasks follow the same pattern. Add meta tags to:
- Task 10: Shop page
- Task 11: About page
- Task 12: Contact page
- Task 13: Terms page
- Task 14: Privacy page
- Task 15: Cookies policy page
- Task 16: Branding page
- Task 17: Samples page

Each follows this pattern:
1. Add `content_for :title` and `:meta_description` at top of file
2. Add `content_for :head` with OG/Twitter tags for important pages
3. Commit individually

---

### Task 18: Enhance Category Page SEO

**Files:**
- Modify: `app/views/categories/show.html.erb`

**Step 1: Add social media meta tags and structured data**

```erb
<!-- app/views/categories/show.html.erb -->
<!-- Add after line 11 (after meta_description) -->

<% content_for :head do %>
  <meta property="og:type" content="website">
  <meta property="og:title" content="<%= @category.meta_title %> | Afida">
  <meta property="og:description" content="<%= @category.meta_description %>">
  <meta property="og:url" content="<%= category_url(@category) %>">
  <meta property="og:site_name" content="Afida">
  <% if @category.image.attached? %>
    <meta property="og:image" content="<%= url_for(@category.image) %>">
  <% end %>

  <meta name="twitter:card" content="summary">
  <meta name="twitter:title" content="<%= @category.meta_title %>">
  <meta name="twitter:description" content="<%= @category.meta_description %>">

  <script type="application/ld+json">
    <%= raw({
      "@context": "https://schema.org",
      "@type": "CollectionPage",
      "name": @category.name,
      "description": @category.description,
      "url": category_url(@category),
      "breadcrumb": {
        "@type": "BreadcrumbList",
        "itemListElement": [
          {
            "@type": "ListItem",
            "position": 1,
            "name": "Home",
            "item": root_url
          },
          {
            "@type": "ListItem",
            "position": 2,
            "name": @category.name,
            "item": category_url(@category)
          }
        ]
      }
    }.to_json) %>
  </script>
<% end %>
```

**Step 2: Commit**

```bash
git add app/views/categories/show.html.erb
git commit -m "feat: add social meta tags and structured data to category pages"
```

---

## Phase 4: Use Database Meta Fields

### Task 19: Update Product Views to Use Database Fields

**Files:**
- Modify: `app/views/products/_standard_product.html.erb`
- Modify: `app/views/products/_branded_configurator.html.erb`

**Step 1: Update to use database fields with fallback**

```erb
<!-- app/views/products/_standard_product.html.erb -->
<!-- Replace title content_for -->
<% content_for :title do %>
<%= @product.meta_title.presence || "#{@product.name} | #{@product.category.name} | Afida" %>
<% end %>

<% content_for :meta_description do %>
<%= @product.meta_description.presence || @product.description %>
<% end %>
```

**Step 2: Test fallback behavior**

```ruby
# test/integration/product_meta_tags_test.rb
require "test_helper"

class ProductMetaTagsTest < ActionDispatch::IntegrationTest
  test "uses custom meta_title when present" do
    product = products(:kraft_pizza_box)
    product.update(meta_title: "Custom SEO Title")

    get product_path(product)
    assert_select "title", "Custom SEO Title"
  end

  test "falls back to generated title when meta_title is blank" do
    product = products(:kraft_pizza_box)
    product.update(meta_title: nil)

    get product_path(product)
    assert_select "title", "#{product.name} | #{product.category.name} | Afida"
  end
end
```

**Step 3: Run test and commit**

Run: `rails test test/integration/product_meta_tags_test.rb`

```bash
git add app/views/products/_standard_product.html.erb app/views/products/_branded_configurator.html.erb test/integration/product_meta_tags_test.rb
git commit -m "feat: use database meta fields for products with fallback"
```

---

## Phase 5: Admin Interface (Optional)

### Task 20-21: Add SEO Fields to Admin Forms

Add `meta_title` and `meta_description` fields to product and category admin forms, ensure controllers permit these parameters.

---

## Phase 6: Testing & Validation

### Task 22: Comprehensive Integration Tests

**Files:**
- Create: `test/integration/comprehensive_seo_test.rb`

```ruby
# test/integration/comprehensive_seo_test.rb
require "test_helper"

class ComprehensiveSeoTest < ActionDispatch::IntegrationTest
  test "all public pages have canonical URLs" do
    [root_path, shop_path, about_path, contact_path].each do |page|
      get page
      assert_select 'link[rel="canonical"]', "Missing canonical on #{page}"
    end
  end

  test "sitemap includes all important pages" do
    get sitemap_path(format: :xml)
    assert_response :success
    assert_match root_url, response.body
    assert_match shop_url, response.body
  end

  test "robots txt includes sitemap" do
    get "/robots.txt"
    assert_includes response.body, "/sitemap.xml"
  end
end
```

---

### Task 23: SEO Validation Rake Task

**Files:**
- Create: `lib/tasks/seo.rake`

```ruby
# lib/tasks/seo.rake
namespace :seo do
  desc "Validate SEO implementation"
  task validate: :environment do
    puts "🔍 Running SEO Validation..."

    warnings = []
    warnings << "⚠️  #{Product.where(meta_description: [nil, '']).count} products missing custom meta_description"
    warnings << "⚠️  #{Category.where(meta_description: [nil, '']).count} categories missing meta_description"

    puts warnings.any? ? warnings.join("\n") : "✅ All SEO checks passed!"
  end
end
```

---

## Phase 7: Documentation

### Task 24: Update CLAUDE.md

Add comprehensive SEO documentation section to CLAUDE.md explaining all implementations, helpers, and how to use them.

---

## Summary

**Total Tasks:** 24
**Estimated Time:** 8-12 hours
**Priority:** High impact first (structured data, sitemap), then completeness

**Next Steps After Completion:**
1. Run `rails seo:validate` to check coverage
2. Test with Google Rich Results Test
3. Submit sitemap to Google Search Console
4. Monitor search performance

---

**Plan saved:** 2025-11-06
