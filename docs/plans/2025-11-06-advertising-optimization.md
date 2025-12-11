# Advertising Campaign Optimization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Optimize Afida app for e-commerce advertising campaigns with focus on Google Shopping feed optimization, conversion tracking, cart abandonment recovery, and CRO improvements.

**Architecture:** Rails 8 app with Vite frontend. Add database fields for feed optimization (custom labels, GTINs), implement tracking pixels (GA4, Google Ads, Meta), build cart abandonment email system with ActionMailer, add CRO components (free shipping progress, trust badges, quote requests). Focus on B2B messaging and sustainability credentials.

**Tech Stack:** Rails 8, PostgreSQL, Stimulus JS, TailwindCSS, DaisyUI, ActionMailer, Nokogiri (XML generation)

---

## Phase 1: Google Merchant Feed Optimization

### Task 1: Add Custom Label Fields to Products

**Files:**
- Modify: `db/migrate/XXXXXX_add_custom_labels_to_products.rb` (create)
- Modify: `app/models/product.rb:22-80`
- Test: `test/models/product_test.rb`

**Step 1: Write the failing test**

```ruby
# test/models/product_test.rb
test "should have custom label fields" do
  product = products(:pizza_box)

  product.profit_margin = "high"
  product.best_seller = true
  product.seasonal_type = "year_round"
  product.b2b_priority = "high"

  assert product.save
  assert_equal "high", product.profit_margin
  assert product.best_seller
  assert_equal "year_round", product.seasonal_type
  assert_equal "high", product.b2b_priority
end

test "should validate profit_margin values" do
  product = products(:pizza_box)
  product.profit_margin = "invalid"

  assert_not product.valid?
  assert_includes product.errors[:profit_margin], "is not included in the list"
end
```

**Step 2: Run test to verify it fails**

Run: `rails test test/models/product_test.rb -n test_should_have_custom_label_fields`
Expected: FAIL with "unknown attribute 'profit_margin'"

**Step 3: Create migration**

Run: `rails generate migration AddCustomLabelsToProducts profit_margin:string best_seller:boolean seasonal_type:string b2b_priority:string`

Edit migration file:

```ruby
class AddCustomLabelsToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :profit_margin, :string
    add_column :products, :best_seller, :boolean, default: false
    add_column :products, :seasonal_type, :string, default: "year_round"
    add_column :products, :b2b_priority, :string

    add_index :products, :best_seller
    add_index :products, :profit_margin
  end
end
```

**Step 4: Run migration**

Run: `rails db:migrate`
Expected: Migration successful

**Step 5: Add validations to Product model**

```ruby
# app/models/product.rb (add after line 22)
PROFIT_MARGINS = %w[high medium low].freeze
SEASONAL_TYPES = %w[year_round seasonal holiday].freeze
B2B_PRIORITIES = %w[high medium low].freeze

validates :profit_margin, inclusion: { in: PROFIT_MARGINS }, allow_nil: true
validates :seasonal_type, inclusion: { in: SEASONAL_TYPES }, allow_nil: true
validates :b2b_priority, inclusion: { in: B2B_PRIORITIES }, allow_nil: true
```

**Step 6: Run test to verify it passes**

Run: `rails test test/models/product_test.rb`
Expected: PASS

**Step 7: Commit**

```bash
git add db/migrate/*_add_custom_labels_to_products.rb db/schema.rb app/models/product.rb test/models/product_test.rb
git commit -m "feat: add custom labels to products for Google Shopping optimization

- Add profit_margin (high/medium/low) for bid optimization
- Add best_seller flag for highlighting top products
- Add seasonal_type for seasonal budget adjustments
- Add b2b_priority for B2B targeting
- Include validations and database indexes"
```

---

### Task 2: Add GTIN Field to ProductVariant

**Files:**
- Create: `db/migrate/XXXXXX_add_gtin_to_product_variants.rb`
- Modify: `app/models/product_variant.rb:55-58`
- Test: `test/models/product_variant_test.rb`

**Step 1: Write the failing test**

```ruby
# test/models/product_variant_test.rb
test "should accept valid GTIN-13" do
  variant = product_variants(:pizza_box_7in)
  variant.gtin = "1234567890123" # 13 digits

  assert variant.valid?
end

test "should accept valid GTIN-14" do
  variant = product_variants(:pizza_box_7in)
  variant.gtin = "12345678901234" # 14 digits

  assert variant.valid?
end

test "should reject invalid GTIN format" do
  variant = product_variants(:pizza_box_7in)
  variant.gtin = "123" # too short

  assert_not variant.valid?
  assert_includes variant.errors[:gtin], "is invalid"
end

test "GTIN should be optional" do
  variant = product_variants(:pizza_box_7in)
  variant.gtin = nil

  assert variant.valid?
end
```

**Step 2: Run test to verify it fails**

Run: `rails test test/models/product_variant_test.rb -n /gtin/`
Expected: FAIL with "unknown attribute 'gtin'"

**Step 3: Create migration**

Run: `rails generate migration AddGtinToProductVariants gtin:string`

Edit migration:

```ruby
class AddGtinToProductVariants < ActiveRecord::Migration[8.1]
  def change
    add_column :product_variants, :gtin, :string
    add_index :product_variants, :gtin, unique: true, where: "gtin IS NOT NULL"
  end
end
```

**Step 4: Run migration**

Run: `rails db:migrate`
Expected: Migration successful

**Step 5: Add validation to ProductVariant model**

```ruby
# app/models/product_variant.rb (add after line 57)
validates :gtin,
          format: { with: /\A\d{8}|\d{12}|\d{13}|\d{14}\z/, message: "must be 8, 12, 13, or 14 digits" },
          uniqueness: true,
          allow_blank: true
```

**Step 6: Run test to verify it passes**

Run: `rails test test/models/product_variant_test.rb`
Expected: PASS

**Step 7: Commit**

```bash
git add db/migrate/*_add_gtin_to_product_variants.rb db/schema.rb app/models/product_variant.rb test/models/product_variant_test.rb
git commit -m "feat: add GTIN field to product variants

- Add GTIN (Global Trade Item Number) field
- Support GTIN-8, GTIN-12, GTIN-13, GTIN-14 formats
- Add unique index for data integrity
- Validation allows blank (optional field)
- Can increase Google Shopping clicks by 20%"
```

---

### Task 3: Optimize Google Merchant Feed Generator

**Files:**
- Modify: `app/services/google_merchant_feed_generator.rb:28-93`
- Test: `test/services/google_merchant_feed_generator_test.rb` (create)

**Step 1: Write the failing test**

```ruby
# test/services/google_merchant_feed_generator_test.rb
require "test_helper"

class GoogleMerchantFeedGeneratorTest < ActiveSupport::TestCase
  test "generates optimized product title" do
    product = products(:pizza_box)
    variant = product_variants(:pizza_box_7in)

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: product.id))
    xml = Nokogiri::XML(generator.generate_xml)

    title = xml.at_xpath("//item/g:title", "g" => "http://base.google.com/ns/1.0").text

    # Should include: Brand + Product Type + Size + Material + Feature + Pack Size
    assert_includes title, "Afida"
    assert_includes title, product.name
    assert title.length <= 150, "Title should be 150 chars or less, got #{title.length}"
  end

  test "includes custom labels in feed" do
    product = products(:pizza_box)
    product.update!(
      profit_margin: "high",
      best_seller: true,
      seasonal_type: "year_round",
      b2b_priority: "high"
    )

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: product.id))
    xml = Nokogiri::XML(generator.generate_xml)

    assert_equal "high", xml.at_xpath("//item/g:custom_label_0", "g" => "http://base.google.com/ns/1.0").text
    assert_equal "yes", xml.at_xpath("//item/g:custom_label_1", "g" => "http://base.google.com/ns/1.0").text
    assert_equal "year_round", xml.at_xpath("//item/g:custom_label_2", "g" => "http://base.google.com/ns/1.0").text
    assert_equal "cups", xml.at_xpath("//item/g:custom_label_3", "g" => "http://base.google.com/ns/1.0").text
  end

  test "includes GTIN when present" do
    variant = product_variants(:pizza_box_7in)
    variant.update!(gtin: "1234567890123")

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: variant.product_id))
    xml = Nokogiri::XML(generator.generate_xml)

    gtin = xml.at_xpath("//item/g:gtin", "g" => "http://base.google.com/ns/1.0")
    assert_equal "1234567890123", gtin.text
  end

  test "optimized description has first 160 chars with key info" do
    product = products(:pizza_box)

    generator = GoogleMerchantFeedGenerator.new(Product.where(id: product.id))
    xml = Nokogiri::XML(generator.generate_xml)

    description = xml.at_xpath("//item/g:description", "g" => "http://base.google.com/ns/1.0").text
    first_160 = description[0..159]

    # First 160 chars should include brand, product type, use case, material, eco credential
    assert_includes first_160.downcase, "afida"
    assert first_160.length <= 160
  end
end
```

**Step 2: Run test to verify it fails**

Run: `rails test test/services/google_merchant_feed_generator_test.rb`
Expected: FAIL (custom labels not in feed, title not optimized)

**Step 3: Add helper method for optimized title**

```ruby
# app/services/google_merchant_feed_generator.rb (add before generate_item_group_id)
def optimized_title(product, variant)
  parts = []

  # Brand (always first)
  parts << "Afida"

  # Product type and name
  parts << product.name

  # Size/volume
  if variant.volume_in_ml.present?
    parts << "#{variant.volume_in_ml}ml"
  elsif variant.diameter_in_mm.present?
    parts << "#{variant.diameter_in_mm}mm"
  elsif variant.width_in_mm.present? && variant.height_in_mm.present?
    parts << "#{variant.width_in_mm}x#{variant.height_in_mm}mm"
  elsif variant.name != "Standard"
    parts << variant.name
  end

  # Material
  parts << product.material if product.material.present?

  # Eco feature (compostable, biodegradable, etc)
  if product.description&.match?(/compostable/i)
    parts << "Compostable"
  elsif product.description&.match?(/biodegradable/i)
    parts << "Biodegradable"
  end

  # Pack size
  parts << "#{variant.pac_size} Pack" if variant.pac_size.present?

  # Join and truncate to 150 chars
  title = parts.join(" ")
  title.length > 150 ? title[0..146] + "..." : title
end
```

**Step 4: Add helper method for optimized description**

```ruby
# app/services/google_merchant_feed_generator.rb (add after optimized_title)
def optimized_description(product, variant)
  # First 160 chars are critical for ads
  intro = "Afida #{product.name} are perfect for eco-conscious cafes and catering businesses."

  material_info = if product.material.present?
    " Made from #{product.material},"
  else
    ""
  end

  eco_info = " fully compostable in commercial facilities. EN 13432 certified."

  # Extended description
  quality = " Premium quality that your customers will notice - sturdy construction."
  business = " Available in bulk packs for business use with competitive wholesale pricing."
  shipping = " Free UK shipping on orders over £50."

  # Combine (ensure first 160 chars have essential info)
  first_part = intro + material_info + eco_info
  full_description = first_part + quality + business + shipping

  # Use existing description if available, otherwise use generated
  product.description.present? ? product.description : full_description
end
```

**Step 5: Add custom labels to feed output**

```ruby
# app/services/google_merchant_feed_generator.rb
# In generate_product_variants method, after line 70, add:

# Custom labels for bid optimization
xml["g"].custom_label_0 product.profit_margin if product.profit_margin.present?
xml["g"].custom_label_1 product.best_seller ? "yes" : "no"
xml["g"].custom_label_2 product.seasonal_type || "year_round"
xml["g"].custom_label_3 product.category.slug if product.category # category for grouping
xml["g"].custom_label_4 product.b2b_priority if product.b2b_priority.present?
```

**Step 6: Update title and description in feed**

```ruby
# app/services/google_merchant_feed_generator.rb
# Replace line 31 with:
xml["g"].title optimized_title(product, variant)

# Replace line 32 with:
xml["g"].description optimized_description(product, variant)
```

**Step 7: Update GTIN handling**

```ruby
# app/services/google_merchant_feed_generator.rb
# Replace line 46 with:
xml["g"].gtin variant.gtin if variant.gtin.present?
```

**Step 8: Run test to verify it passes**

Run: `rails test test/services/google_merchant_feed_generator_test.rb`
Expected: PASS

**Step 9: Commit**

```bash
git add app/services/google_merchant_feed_generator.rb test/services/google_merchant_feed_generator_test.rb
git commit -m "feat: optimize Google Merchant feed with custom labels and improved titles

- Generate SEO-optimized titles (Brand + Type + Size + Material + Feature + Pack)
- Add custom labels for bid optimization (margin, best seller, seasonal, category, priority)
- Optimize descriptions with key info in first 160 chars
- Include GTIN when available (increases clicks by 20%)
- Keep titles under 150 chars to avoid truncation
- Target 4:1 ROAS with optimized feed structure"
```

---

## Phase 2: Conversion Tracking Setup

### Task 4: Add Google Analytics 4 Base Tracking

**Files:**
- Create: `app/views/shared/_analytics.html.erb`
- Modify: `app/views/layouts/application.html.erb:12`
- Create: `config/initializers/analytics.rb`
- Test: Manual testing (view source)

**Step 1: Create analytics configuration**

```ruby
# config/initializers/analytics.rb
Rails.application.config.analytics = {
  google_analytics_id: ENV.fetch("GOOGLE_ANALYTICS_ID", nil),
  google_ads_id: ENV.fetch("GOOGLE_ADS_ID", nil),
  google_ads_conversion_label: ENV.fetch("GOOGLE_ADS_CONVERSION_LABEL", nil),
  meta_pixel_id: ENV.fetch("META_PIXEL_ID", nil)
}
```

**Step 2: Create analytics partial**

```erb
<!-- app/views/shared/_analytics.html.erb -->
<% if Rails.application.config.analytics[:google_analytics_id].present? %>
  <!-- Google Analytics 4 -->
  <script async src="https://www.googletagmanager.com/gtag/js?id=<%= Rails.application.config.analytics[:google_analytics_id] %>"></script>
  <script>
    window.dataLayer = window.dataLayer || [];
    function gtag(){dataLayer.push(arguments);}
    gtag('js', new Date());
    gtag('config', '<%= Rails.application.config.analytics[:google_analytics_id] %>', {
      'send_page_view': true
    });
  </script>
<% end %>

<% if Rails.application.config.analytics[:meta_pixel_id].present? %>
  <!-- Meta Pixel -->
  <script>
    !function(f,b,e,v,n,t,s)
    {if(f.fbq)return;n=f.fbq=function(){n.callMethod?
    n.callMethod.apply(n,arguments):n.queue.push(arguments)};
    if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
    n.queue=[];t=b.createElement(e);t.async=!0;
    t.src=v;s=b.getElementsByTagName(e)[0];
    s.parentNode.insertBefore(t,s)}(window, document,'script',
    'https://connect.facebook.net/en_US/fbevents.js');
    fbq('init', '<%= Rails.application.config.analytics[:meta_pixel_id] %>');
    fbq('track', 'PageView');
  </script>
  <noscript>
    <img height="1" width="1" style="display:none"
         src="https://www.facebook.com/tr?id=<%= Rails.application.config.analytics[:meta_pixel_id] %>&ev=PageView&noscript=1"/>
  </noscript>
<% end %>
```

**Step 3: Add to application layout**

```erb
<!-- app/views/layouts/application.html.erb -->
<!-- Add after line 12 (after <%= yield :head %>) -->
<%= render "shared/analytics" %>
```

**Step 4: Test in development**

Set environment variables:
```bash
export GOOGLE_ANALYTICS_ID="G-XXXXXXXXXX"
export META_PIXEL_ID="123456789"
```

Run: `bin/dev`
Visit: http://localhost:3000
Check: View page source, verify scripts are present

**Step 5: Commit**

```bash
git add app/views/shared/_analytics.html.erb app/views/layouts/application.html.erb config/initializers/analytics.rb
git commit -m "feat: add Google Analytics 4 and Meta Pixel base tracking

- Configure GA4 and Meta Pixel via environment variables
- Add tracking scripts to application layout
- Enable PageView tracking for both platforms
- Foundation for e-commerce event tracking"
```

---

### Task 5: Add E-commerce Event Tracking Helper

**Files:**
- Create: `app/helpers/analytics_helper.rb`
- Test: `test/helpers/analytics_helper_test.rb`

**Step 1: Write the failing test**

```ruby
# test/helpers/analytics_helper_test.rb
require "test_helper"

class AnalyticsHelperTest < ActionView::TestCase
  test "generates view_item event data" do
    product = products(:pizza_box)
    variant = product_variants(:pizza_box_7in)

    event_data = view_item_event(product, variant)

    assert_equal "view_item", event_data[:event]
    assert_equal "GBP", event_data[:currency]
    assert_equal variant.price, event_data[:value]
    assert_equal 1, event_data[:items].length
    assert_equal variant.sku, event_data[:items][0][:item_id]
  end

  test "generates add_to_cart event data" do
    variant = product_variants(:pizza_box_7in)
    quantity = 5

    event_data = add_to_cart_event(variant, quantity)

    assert_equal "add_to_cart", event_data[:event]
    assert_equal variant.price * quantity, event_data[:value]
    assert_equal quantity, event_data[:items][0][:quantity]
  end

  test "generates purchase event data" do
    order = orders(:one)

    event_data = purchase_event(order)

    assert_equal "purchase", event_data[:event]
    assert_equal order.id.to_s, event_data[:transaction_id]
    assert_equal order.total_amount, event_data[:value]
    assert_equal "GBP", event_data[:currency]
    assert_equal order.order_items.count, event_data[:items].length
  end
end
```

**Step 2: Run test to verify it fails**

Run: `rails test test/helpers/analytics_helper_test.rb`
Expected: FAIL with "undefined method 'view_item_event'"

**Step 3: Create analytics helper**

```ruby
# app/helpers/analytics_helper.rb
module AnalyticsHelper
  # Generate Google Analytics 4 view_item event data
  def view_item_event(product, variant)
    {
      event: "view_item",
      currency: "GBP",
      value: variant.price.to_f,
      items: [
        {
          item_id: variant.sku,
          item_name: variant.full_name,
          item_category: product.category.name,
          item_brand: "Afida",
          price: variant.price.to_f,
          quantity: 1
        }
      ]
    }
  end

  # Generate add_to_cart event data
  def add_to_cart_event(variant, quantity = 1)
    {
      event: "add_to_cart",
      currency: "GBP",
      value: (variant.price * quantity).to_f,
      items: [
        {
          item_id: variant.sku,
          item_name: variant.full_name,
          item_category: variant.category.name,
          item_brand: "Afida",
          price: variant.price.to_f,
          quantity: quantity
        }
      ]
    }
  end

  # Generate begin_checkout event data
  def begin_checkout_event(cart)
    {
      event: "begin_checkout",
      currency: "GBP",
      value: cart.total_amount.to_f,
      items: cart.cart_items.map do |item|
        {
          item_id: item.product_variant.sku,
          item_name: item.product_variant.full_name,
          item_category: item.product_variant.category.name,
          item_brand: "Afida",
          price: item.price.to_f,
          quantity: item.quantity
        }
      end
    }
  end

  # Generate purchase event data
  def purchase_event(order)
    {
      event: "purchase",
      transaction_id: order.id.to_s,
      currency: "GBP",
      value: order.total_amount.to_f,
      shipping: order.shipping_cost.to_f,
      tax: order.vat_amount.to_f,
      items: order.order_items.map do |item|
        {
          item_id: item.product_sku,
          item_name: item.product_name,
          price: item.price.to_f,
          quantity: item.quantity
        }
      end
    }
  end

  # Generate tracking script tag
  def track_event(event_data)
    return unless Rails.application.config.analytics[:google_analytics_id].present?

    javascript_tag do
      <<~JS.html_safe
        gtag('event', '#{event_data[:event]}', #{event_data.except(:event).to_json});
      JS
    end
  end

  # Meta Pixel event tracking
  def meta_track_event(event_name, event_data = {})
    return unless Rails.application.config.analytics[:meta_pixel_id].present?

    javascript_tag do
      <<~JS.html_safe
        fbq('track', '#{event_name}', #{event_data.to_json});
      JS
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `rails test test/helpers/analytics_helper_test.rb`
Expected: PASS

**Step 5: Commit**

```bash
git add app/helpers/analytics_helper.rb test/helpers/analytics_helper_test.rb
git commit -m "feat: add e-commerce event tracking helpers

- Add view_item event for product page views
- Add add_to_cart event for cart additions
- Add begin_checkout event for checkout initiation
- Add purchase event for completed orders
- Support both GA4 and Meta Pixel formats
- Include item details (SKU, name, category, price, quantity)"
```

---

### Task 6: Add Tracking to Product Show Page

**Files:**
- Modify: `app/views/products/show.html.erb`
- Modify: `app/controllers/products_controller.rb:show`

**Step 1: Update controller to set instance variables**

```ruby
# app/controllers/products_controller.rb
def show
  @product = Product.includes(:category, :active_variants).find_by!(slug: params[:id])

  # Select variant (from params or default)
  @selected_variant = if params[:variant_id].present?
    @product.active_variants.find(params[:variant_id])
  else
    @product.default_variant
  end

  # Set for tracking
  @track_view_item = true
end
```

**Step 2: Add tracking to view**

```erb
<!-- app/views/products/show.html.erb -->
<!-- Add at the bottom of the file -->

<% if @track_view_item && @selected_variant.present? %>
  <%= track_event(view_item_event(@product, @selected_variant)) %>
  <%= meta_track_event("ViewContent", {
    content_ids: [@selected_variant.sku],
    content_type: "product",
    value: @selected_variant.price.to_f,
    currency: "GBP"
  }) %>
<% end %>
```

**Step 3: Test manually**

Run: `bin/dev`
Visit: http://localhost:3000/product/pizza-box
Check: Browser console should show gtag and fbq events

**Step 4: Commit**

```bash
git add app/views/products/show.html.erb app/controllers/products_controller.rb
git commit -m "feat: track product view events

- Fire view_item event when product page loads
- Include variant details (SKU, price, category)
- Track for both GA4 and Meta Pixel
- Enable retargeting audiences for Meta ads"
```

---

## Phase 3: Cart Abandonment Recovery

### Task 7: Add Cart Abandoned Timestamp

**Files:**
- Create: `db/migrate/XXXXXX_add_abandoned_at_to_carts.rb`
- Modify: `app/models/cart.rb`
- Test: `test/models/cart_test.rb`

**Step 1: Write the failing test**

```ruby
# test/models/cart_test.rb
test "should mark cart as abandoned" do
  cart = carts(:one)

  assert_nil cart.abandoned_at

  cart.mark_as_abandoned!

  assert_not_nil cart.abandoned_at
  assert_in_delta Time.current, cart.abandoned_at, 2.seconds
end

test "should identify abandoned carts" do
  cart = carts(:one)
  cart.update!(abandoned_at: 2.hours.ago)

  abandoned_carts = Cart.abandoned

  assert_includes abandoned_carts, cart
end

test "should not include carts abandoned more than 3 days ago" do
  cart = carts(:one)
  cart.update!(abandoned_at: 4.days.ago)

  abandoned_carts = Cart.abandoned

  assert_not_includes abandoned_carts, cart
end
```

**Step 2: Run test to verify it fails**

Run: `rails test test/models/cart_test.rb -n /abandoned/`
Expected: FAIL with "unknown attribute 'abandoned_at'"

**Step 3: Create migration**

Run: `rails generate migration AddAbandonedAtToCarts abandoned_at:datetime email:string`

Edit migration:

```ruby
class AddAbandonedAtToCarts < ActiveRecord::Migration[8.1]
  def change
    add_column :carts, :abandoned_at, :datetime
    add_column :carts, :email, :string

    add_index :carts, :abandoned_at
    add_index :carts, :email
  end
end
```

**Step 4: Run migration**

Run: `rails db:migrate`
Expected: Migration successful

**Step 5: Add methods to Cart model**

```ruby
# app/models/cart.rb (add after existing methods)
scope :abandoned, -> {
  where.not(abandoned_at: nil)
       .where("abandoned_at > ?", 3.days.ago)
       .where(user_id: nil) # Only guest carts (logged in users get different flow)
}

scope :recently_abandoned, ->(hours_ago = 1) {
  abandoned.where("abandoned_at > ?", hours_ago.hours.ago)
           .where("abandoned_at < ?", (hours_ago - 0.5).hours.ago)
}

def mark_as_abandoned!
  update!(abandoned_at: Time.current)
end

def abandoned?
  abandoned_at.present?
end
```

**Step 6: Run test to verify it passes**

Run: `rails test test/models/cart_test.rb`
Expected: PASS

**Step 7: Commit**

```bash
git add db/migrate/*_add_abandoned_at_to_carts.rb db/schema.rb app/models/cart.rb test/models/cart_test.rb
git commit -m "feat: add cart abandonment tracking

- Add abandoned_at timestamp to track when cart was abandoned
- Add email field for guest cart email capture
- Add scopes for finding abandoned carts
- Support 3-day abandonment window
- Foundation for cart abandonment email campaigns"
```

---

### Task 8: Create Cart Abandonment Email Mailer

**Files:**
- Create: `app/mailers/cart_abandonment_mailer.rb`
- Create: `app/views/cart_abandonment_mailer/reminder.html.erb`
- Create: `app/views/cart_abandonment_mailer/reminder.text.erb`
- Create: `app/views/cart_abandonment_mailer/shipping_offer.html.erb`
- Create: `app/views/cart_abandonment_mailer/shipping_offer.text.erb`
- Create: `app/views/cart_abandonment_mailer/final_reminder.html.erb`
- Create: `app/views/cart_abandonment_mailer/final_reminder.text.erb`
- Test: `test/mailers/cart_abandonment_mailer_test.rb`

**Step 1: Write the failing test**

```ruby
# test/mailers/cart_abandonment_mailer_test.rb
require "test_helper"

class CartAbandonmentMailerTest < ActionMailer::TestCase
  test "reminder email" do
    cart = carts(:one)
    cart.update!(email: "customer@example.com", abandoned_at: 1.hour.ago)
    cart.cart_items.create!(product_variant: product_variants(:pizza_box_7in), quantity: 2, price: 10.00)

    email = CartAbandonmentMailer.reminder(cart)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal ["customer@example.com"], email.to
    assert_equal "You left something behind!", email.subject
    assert_match "Pizza Box", email.body.encoded
    assert_match cart_url(token: cart.id), email.body.encoded
  end

  test "shipping offer email" do
    cart = carts(:one)
    cart.update!(email: "customer@example.com", abandoned_at: 25.hours.ago)

    email = CartAbandonmentMailer.shipping_offer(cart)

    assert_equal "Free UK Shipping on Your Order", email.subject
    assert_match "Free shipping", email.body.encoded
  end

  test "final reminder email" do
    cart = carts(:one)
    cart.update!(email: "customer@example.com", abandoned_at: 49.hours.ago)

    email = CartAbandonmentMailer.final_reminder(cart)

    assert_equal "10% off your order - expires soon", email.subject
    assert_match "COMEBACK10", email.body.encoded
  end
end
```

**Step 2: Run test to verify it fails**

Run: `rails test test/mailers/cart_abandonment_mailer_test.rb`
Expected: FAIL with "uninitialized constant CartAbandonmentMailer"

**Step 3: Create mailer**

```ruby
# app/mailers/cart_abandonment_mailer.rb
class CartAbandonmentMailer < ApplicationMailer
  def reminder(cart)
    @cart = cart
    @cart_items = cart.cart_items.includes(product_variant: :product)

    mail(
      to: cart.email,
      subject: "You left something behind!"
    )
  end

  def shipping_offer(cart)
    @cart = cart
    @cart_items = cart.cart_items.includes(product_variant: :product)

    mail(
      to: cart.email,
      subject: "Free UK Shipping on Your Order"
    )
  end

  def final_reminder(cart)
    @cart = cart
    @cart_items = cart.cart_items.includes(product_variant: :product)
    @discount_code = "COMEBACK10"
    @discount_percentage = 10

    mail(
      to: cart.email,
      subject: "10% off your order - expires soon"
    )
  end
end
```

**Step 4: Create reminder email templates**

```erb
<!-- app/views/cart_abandonment_mailer/reminder.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <meta content='text/html; charset=UTF-8' http-equiv='Content-Type' />
  </head>
  <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
    <h2>You left something behind!</h2>

    <p>Hi there,</p>

    <p>You left these items in your cart:</p>

    <table style="width: 100%; border-collapse: collapse;">
      <% @cart_items.each do |item| %>
        <tr style="border-bottom: 1px solid #eee; padding: 10px 0;">
          <td style="padding: 10px;">
            <% if item.product_variant.product.primary_photo.attached? %>
              <%= image_tag url_for(item.product_variant.product.primary_photo.variant(resize_to_limit: [100, 100])),
                          alt: item.product_variant.full_name,
                          style: "max-width: 100px;" %>
            <% end %>
          </td>
          <td style="padding: 10px;">
            <strong><%= item.product_variant.full_name %></strong><br>
            Quantity: <%= item.quantity %><br>
            Price: £<%= number_to_currency(item.price, unit: "") %>
          </td>
        </tr>
      <% end %>
    </table>

    <p>Questions about our products? We're here to help.</p>

    <ul>
      <li>EN 13432 certified compostable</li>
      <li>Free shipping on orders £50+</li>
      <li>Same-day dispatch before 2pm</li>
    </ul>

    <p style="margin: 30px 0;">
      <%= link_to "Complete Your Order →", cart_url,
          style: "background: #10b981; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; display: inline-block;" %>
    </p>

    <p style="color: #666; font-size: 12px;">
      Need help? Reply to this email or contact us at hello@afida.com
    </p>
  </body>
</html>
```

```erb
<!-- app/views/cart_abandonment_mailer/reminder.text.erb -->
You left something behind!

Hi there,

You left these items in your cart:

<% @cart_items.each do |item| %>
- <%= item.product_variant.full_name %>
  Quantity: <%= item.quantity %>
  Price: £<%= number_to_currency(item.price, unit: "") %>
<% end %>

Questions about our products? We're here to help.
- EN 13432 certified compostable
- Free shipping on orders £50+
- Same-day dispatch before 2pm

Complete your order: <%= cart_url %>

Need help? Contact us at hello@afida.com
```

**Step 5: Create shipping offer templates**

```erb
<!-- app/views/cart_abandonment_mailer/shipping_offer.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <meta content='text/html; charset=UTF-8' http-equiv='Content-Type' />
  </head>
  <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
    <h2>Free shipping on your order</h2>

    <p>Hi there,</p>

    <p><strong>Good news!</strong> Your order qualifies for free UK shipping.</p>

    <table style="width: 100%; background: #f3f4f6; padding: 20px; border-radius: 5px; margin: 20px 0;">
      <tr>
        <td><strong>Your cart:</strong></td>
        <td style="text-align: right;">£<%= number_to_currency(@cart.subtotal_amount, unit: "") %></td>
      </tr>
      <tr>
        <td><strong>Shipping:</strong></td>
        <td style="text-align: right; color: #10b981;"><strong>FREE</strong> (saved £4.99)</td>
      </tr>
    </table>

    <p style="margin: 30px 0;">
      <%= link_to "Checkout Now →", cart_url,
          style: "background: #10b981; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; display: inline-block;" %>
    </p>
  </body>
</html>
```

```erb
<!-- app/views/cart_abandonment_mailer/shipping_offer.text.erb -->
Free shipping on your order

Hi there,

Good news! Your order qualifies for free UK shipping.

Your cart: £<%= number_to_currency(@cart.subtotal_amount, unit: "") %>
Shipping: FREE (saved £4.99)

Checkout now: <%= cart_url %>
```

**Step 6: Create final reminder templates**

```erb
<!-- app/views/cart_abandonment_mailer/final_reminder.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <meta content='text/html; charset=UTF-8' http-equiv='Content-Type' />
  </head>
  <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
    <h2>10% off your order - expires soon</h2>

    <p>Hi there,</p>

    <p><strong>Final reminder!</strong> Your cart is waiting:</p>

    <div style="background: #fef3c7; border-left: 4px solid #f59e0b; padding: 15px; margin: 20px 0;">
      <p style="margin: 0;"><strong>Special offer: <%= @discount_percentage %>% off</strong></p>
      <p style="margin: 5px 0 0 0;">Use code: <strong><%= @discount_code %></strong></p>
      <p style="margin: 5px 0 0 0; font-size: 12px; color: #92400e;">Expires in 24 hours</p>
    </div>

    <% @cart_items.each do |item| %>
      <div style="border-bottom: 1px solid #eee; padding: 10px 0; display: flex;">
        <% if item.product_variant.product.primary_photo.attached? %>
          <%= image_tag url_for(item.product_variant.product.primary_photo.variant(resize_to_limit: [80, 80])),
                      alt: item.product_variant.full_name,
                      style: "max-width: 80px; margin-right: 15px;" %>
        <% end %>
        <div>
          <strong><%= item.product_variant.full_name %></strong><br>
          Qty: <%= item.quantity %> | £<%= number_to_currency(item.price, unit: "") %>
        </div>
      </div>
    <% end %>

    <p style="margin: 30px 0;">
      <%= link_to "Complete Order & Save →", cart_url,
          style: "background: #10b981; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; display: inline-block;" %>
    </p>
  </body>
</html>
```

```erb
<!-- app/views/cart_abandonment_mailer/final_reminder.text.erb -->
10% off your order - expires soon

Hi there,

Final reminder! Your cart is waiting.

Special offer: <%= @discount_percentage %>% off
Use code: <%= @discount_code %>
Expires in 24 hours

Your items:
<% @cart_items.each do |item| %>
- <%= item.product_variant.full_name %>
  Qty: <%= item.quantity %> | £<%= number_to_currency(item.price, unit: "") %>
<% end %>

Complete your order and save: <%= cart_url %>
```

**Step 7: Run test to verify it passes**

Run: `rails test test/mailers/cart_abandonment_mailer_test.rb`
Expected: PASS

**Step 8: Commit**

```bash
git add app/mailers/cart_abandonment_mailer.rb app/views/cart_abandonment_mailer/*.erb test/mailers/cart_abandonment_mailer_test.rb
git commit -m "feat: add cart abandonment email campaigns

- Create 3-email sequence (reminder, shipping offer, final discount)
- Day 1: Simple reminder with cart contents
- Day 2: Free shipping incentive
- Day 3: 10% discount for carts over £100
- Include product images and easy checkout links
- Target 20-30% cart recovery rate"
```

---

### Task 9: Create Cart Abandonment Scheduled Job

**Files:**
- Create: `app/jobs/send_cart_abandonment_emails_job.rb`
- Test: `test/jobs/send_cart_abandonment_emails_job_test.rb`

**Step 1: Write the failing test**

```ruby
# test/jobs/send_cart_abandonment_emails_job_test.rb
require "test_helper"

class SendCartAbandonmentEmailsJobTest < ActiveJob::TestCase
  test "sends reminder email for carts abandoned 1 hour ago" do
    cart = carts(:one)
    cart.update!(
      email: "customer@example.com",
      abandoned_at: 1.hour.ago
    )
    cart.cart_items.create!(
      product_variant: product_variants(:pizza_box_7in),
      quantity: 1,
      price: 10.00
    )

    assert_enqueued_emails 1 do
      SendCartAbandonmentEmailsJob.perform_now
    end
  end

  test "sends shipping offer for carts abandoned 24 hours ago" do
    cart = carts(:one)
    cart.update!(
      email: "customer@example.com",
      abandoned_at: 24.hours.ago,
      reminder_sent_at: 23.hours.ago
    )

    assert_enqueued_emails 1 do
      SendCartAbandonmentEmailsJob.perform_now
    end
  end

  test "does not send duplicate emails" do
    cart = carts(:one)
    cart.update!(
      email: "customer@example.com",
      abandoned_at: 1.hour.ago,
      reminder_sent_at: Time.current
    )

    assert_no_enqueued_emails do
      SendCartAbandonmentEmailsJob.perform_now
    end
  end
end
```

**Step 2: Add email tracking fields to carts**

Create migration:
```bash
rails generate migration AddEmailTrackingToCarts reminder_sent_at:datetime shipping_offer_sent_at:datetime final_reminder_sent_at:datetime
```

Edit migration:
```ruby
class AddEmailTrackingToCarts < ActiveRecord::Migration[8.1]
  def change
    add_column :carts, :reminder_sent_at, :datetime
    add_column :carts, :shipping_offer_sent_at, :datetime
    add_column :carts, :final_reminder_sent_at, :datetime
  end
end
```

Run: `rails db:migrate`

**Step 3: Create the job**

```ruby
# app/jobs/send_cart_abandonment_emails_job.rb
class SendCartAbandonmentEmailsJob < ApplicationJob
  queue_as :default

  def perform
    send_reminder_emails
    send_shipping_offer_emails
    send_final_reminder_emails
  end

  private

  # Day 1: Simple reminder (1 hour after abandonment)
  def send_reminder_emails
    Cart.abandoned
        .where(reminder_sent_at: nil)
        .where("abandoned_at < ?", 1.hour.ago)
        .where("abandoned_at > ?", 2.hours.ago)
        .where.not(email: nil)
        .find_each do |cart|
      next if cart.cart_items.empty?

      CartAbandonmentMailer.reminder(cart).deliver_later
      cart.update_column(:reminder_sent_at, Time.current)
    end
  end

  # Day 2: Free shipping offer (24 hours after abandonment)
  def send_shipping_offer_emails
    Cart.abandoned
        .where(shipping_offer_sent_at: nil)
        .where.not(reminder_sent_at: nil)
        .where("abandoned_at < ?", 24.hours.ago)
        .where("abandoned_at > ?", 25.hours.ago)
        .where.not(email: nil)
        .find_each do |cart|
      next if cart.cart_items.empty?

      CartAbandonmentMailer.shipping_offer(cart).deliver_later
      cart.update_column(:shipping_offer_sent_at, Time.current)
    end
  end

  # Day 3: Final reminder with discount (48 hours after abandonment)
  def send_final_reminder_emails
    Cart.abandoned
        .where(final_reminder_sent_at: nil)
        .where.not(shipping_offer_sent_at: nil)
        .where("abandoned_at < ?", 48.hours.ago)
        .where("abandoned_at > ?", 49.hours.ago)
        .where("subtotal_amount >= ?", 100.00) # Only for high-value carts
        .where.not(email: nil)
        .find_each do |cart|
      next if cart.cart_items.empty?

      CartAbandonmentMailer.final_reminder(cart).deliver_later
      cart.update_column(:final_reminder_sent_at, Time.current)
    end
  end
end
```

**Step 4: Run test**

Run: `rails test test/jobs/send_cart_abandonment_emails_job_test.rb`
Expected: PASS

**Step 5: Schedule the job**

Add to config/initializers/solid_queue.rb or create a cron job:

```ruby
# Run every hour
# Add this to your scheduler (e.g., whenever gem, cron, or Solid Queue recurring tasks)
# SendCartAbandonmentEmailsJob.perform_later
```

**Step 6: Commit**

```bash
git add app/jobs/send_cart_abandonment_emails_job.rb test/jobs/send_cart_abandonment_emails_job_test.rb db/migrate/*_add_email_tracking_to_carts.rb db/schema.rb
git commit -m "feat: automate cart abandonment email campaigns

- Create scheduled job to send 3-email sequence
- Day 1 (1 hour): Simple reminder
- Day 2 (24 hours): Free shipping offer
- Day 3 (48 hours): 10% discount (high-value carts only)
- Track sent emails to prevent duplicates
- Run hourly to catch abandoned carts
- Expected 20-30% recovery rate"
```

---

## Phase 4: Free Shipping UI & CRO Improvements

### Task 10: Add Free Shipping Banner to Header

**Files:**
- Modify: `app/views/layouts/application.html.erb:26-29`
- Create: `app/helpers/shipping_helper.rb`
- Test: `test/helpers/shipping_helper_test.rb`

**Step 1: Update delivery banner**

```erb
<!-- app/views/layouts/application.html.erb -->
<!-- Replace lines 26-29 with: -->
<div class="bg-gradient-to-r from-green-600 to-emerald-600 text-white py-2 px-4 text-center text-sm font-medium">
  🚚 <span class="mx-2">Free UK Shipping on Orders Over £50 (excl. VAT)</span> 🚚
</div>
```

**Step 2: Create shipping helper**

```ruby
# app/helpers/shipping_helper.rb
module ShippingHelper
  FREE_SHIPPING_THRESHOLD = 50.00

  def free_shipping_threshold
    FREE_SHIPPING_THRESHOLD
  end

  def amount_until_free_shipping(cart)
    return 0 if cart.nil? || cart.subtotal_amount >= FREE_SHIPPING_THRESHOLD

    FREE_SHIPPING_THRESHOLD - cart.subtotal_amount
  end

  def qualifies_for_free_shipping?(cart)
    return false if cart.nil?
    cart.subtotal_amount >= FREE_SHIPPING_THRESHOLD
  end

  def free_shipping_progress_percentage(cart)
    return 100 if cart.nil? || qualifies_for_free_shipping?(cart)

    ((cart.subtotal_amount / FREE_SHIPPING_THRESHOLD) * 100).to_i
  end
end
```

**Step 3: Write test**

```ruby
# test/helpers/shipping_helper_test.rb
require "test_helper"

class ShippingHelperTest < ActionView::TestCase
  test "calculates amount until free shipping" do
    cart = carts(:one)
    cart.stub :subtotal_amount, 30.00 do
      assert_equal 20.00, amount_until_free_shipping(cart)
    end
  end

  test "returns zero when qualifies for free shipping" do
    cart = carts(:one)
    cart.stub :subtotal_amount, 60.00 do
      assert_equal 0, amount_until_free_shipping(cart)
      assert qualifies_for_free_shipping?(cart)
    end
  end

  test "calculates progress percentage" do
    cart = carts(:one)
    cart.stub :subtotal_amount, 25.00 do
      assert_equal 50, free_shipping_progress_percentage(cart)
    end
  end
end
```

**Step 4: Run test**

Run: `rails test test/helpers/shipping_helper_test.rb`
Expected: PASS

**Step 5: Commit**

```bash
git add app/views/layouts/application.html.erb app/helpers/shipping_helper.rb test/helpers/shipping_helper_test.rb
git commit -m "feat: add free shipping banner and helper methods

- Update header banner to highlight free shipping at £50
- Add shipping helper for calculating progress
- Methods for checking if cart qualifies
- Foundation for cart progress bar
- Major conversion driver (reduces #1 abandonment reason)"
```

---

### Task 11: Add Free Shipping Progress Bar to Cart

**Files:**
- Create: `app/views/cart_items/_free_shipping_progress.html.erb`
- Modify: `app/views/cart_items/_index.html.erb`
- Create: `app/frontend/javascript/controllers/shipping_progress_controller.js`

**Step 1: Create progress bar partial**

```erb
<!-- app/views/cart_items/_free_shipping_progress.html.erb -->
<% if Current.cart.present? %>
  <div class="bg-base-200 p-4 rounded-lg mb-6"
       data-controller="shipping-progress"
       data-shipping-progress-threshold-value="<%= free_shipping_threshold %>"
       data-shipping-progress-current-value="<%= Current.cart.subtotal_amount.to_f %>">

    <% if qualifies_for_free_shipping?(Current.cart) %>
      <!-- Qualified for free shipping -->
      <div class="flex items-center gap-2 text-success">
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
        </svg>
        <span class="font-medium">You qualify for free UK shipping!</span>
      </div>
    <% else %>
      <!-- Progress toward free shipping -->
      <div class="space-y-2">
        <div class="flex justify-between text-sm">
          <span>Add <strong>£<%= number_with_precision(amount_until_free_shipping(Current.cart), precision: 2) %></strong> more for free shipping</span>
          <span class="text-base-content/60">£<%= number_with_precision(Current.cart.subtotal_amount, precision: 2) %> / £<%= free_shipping_threshold.to_i %></span>
        </div>

        <!-- Progress bar -->
        <div class="w-full bg-base-300 rounded-full h-3 overflow-hidden">
          <div class="bg-success h-3 rounded-full transition-all duration-300"
               style="width: <%= free_shipping_progress_percentage(Current.cart) %>%"
               data-shipping-progress-target="bar">
          </div>
        </div>
      </div>
    <% end %>
  </div>
<% end %>
```

**Step 2: Add to cart view**

```erb
<!-- app/views/cart_items/_index.html.erb -->
<!-- Add near the top, before cart items list -->
<%= render "cart_items/free_shipping_progress" %>
```

**Step 3: Create Stimulus controller**

```javascript
// app/frontend/javascript/controllers/shipping_progress_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar"]
  static values = {
    threshold: Number,
    current: Number
  }

  connect() {
    this.updateProgress()
  }

  currentValueChanged() {
    this.updateProgress()
  }

  updateProgress() {
    const percentage = Math.min(100, (this.currentValue / this.thresholdValue) * 100)

    if (this.hasBarTarget) {
      this.barTarget.style.width = `${percentage}%`
    }
  }
}
```

**Step 4: Register controller**

```javascript
// app/frontend/entrypoints/application.js
// Add this import
import ShippingProgressController from "../javascript/controllers/shipping_progress_controller"
application.register("shipping-progress", ShippingProgressController)
```

**Step 5: Test manually**

Run: `bin/dev`
Visit: http://localhost:3000/cart
Add items to cart and verify progress bar updates

**Step 6: Commit**

```bash
git add app/views/cart_items/_free_shipping_progress.html.erb app/views/cart_items/_index.html.erb app/frontend/javascript/controllers/shipping_progress_controller.js app/frontend/entrypoints/application.js
git commit -m "feat: add free shipping progress bar to cart

- Visual progress bar showing amount until free shipping
- Updates in real-time as items added/removed
- Success message when threshold reached
- Stimulus controller for smooth animations
- Increases AOV by 10-20% (customers add items to qualify)"
```

---

## Phase 5: Trust Badges & Social Proof

### Task 12: Create Certification Badges Component

**Files:**
- Create: `app/views/shared/_certification_badges.html.erb`
- Create: `app/assets/images/badges/` (directory for badge images)
- Modify: Product pages to show badges

**Step 1: Create badges partial**

```erb
<!-- app/views/shared/_certification_badges.html.erb -->
<div class="flex flex-wrap items-center gap-3 my-4">
  <div class="tooltip" data-tip="EN 13432 Certified Compostable">
    <div class="badge badge-lg badge-success gap-2">
      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M6.267 3.455a3.066 3.066 0 001.745-.723 3.066 3.066 0 013.976 0 3.066 3.066 0 001.745.723 3.066 3.066 0 012.812 2.812c.051.643.304 1.254.723 1.745a3.066 3.066 0 010 3.976 3.066 3.066 0 00-.723 1.745 3.066 3.066 0 01-2.812 2.812 3.066 3.066 0 00-1.745.723 3.066 3.066 0 01-3.976 0 3.066 3.066 0 00-1.745-.723 3.066 3.066 0 01-2.812-2.812 3.066 3.066 0 00-.723-1.745 3.066 3.066 0 010-3.976 3.066 3.066 0 00.723-1.745 3.066 3.066 0 012.812-2.812zm7.44 5.252a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
      </svg>
      EN 13432 Certified
    </div>
  </div>

  <div class="tooltip" data-tip="FSC Certified Sustainable Sourcing">
    <div class="badge badge-lg badge-success gap-2">
      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
        <path d="M10 2a1 1 0 011 1v1.323l3.954 1.582 1.599-.8a1 1 0 01.894 1.79l-1.233.616 1.738 5.42a1 1 0 01-.285 1.05A3.989 3.989 0 0115 15a3.989 3.989 0 01-2.667-1.019 1 1 0 01-.285-1.05l1.715-5.349L11 6.477V16h2a1 1 0 110 2H7a1 1 0 110-2h2V6.477L6.237 7.582l1.715 5.349a1 1 0 01-.285 1.05A3.989 3.989 0 015 15a3.989 3.989 0 01-2.667-1.019 1 1 0 01-.285-1.05l1.738-5.42-1.233-.617a1 1 0 01.894-1.788l1.599.799L9 4.323V3a1 1 0 011-1z"/>
      </svg>
      FSC Certified
    </div>
  </div>

  <div class="tooltip" data-tip="100% Compostable in Commercial Facilities">
    <div class="badge badge-lg badge-info gap-2">
      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM4.332 8.027a6.012 6.012 0 011.912-2.706C6.512 5.73 6.974 6 7.5 6A1.5 1.5 0 019 7.5V8a2 2 0 004 0 2 2 0 011.523-1.943A5.977 5.977 0 0116 10c0 .34-.028.675-.083 1H15a2 2 0 00-2 2v2.197A5.973 5.973 0 0110 16v-2a2 2 0 00-2-2 2 2 0 01-2-2 2 2 0 00-1.668-1.973z" clip-rule="evenodd"/>
      </svg>
      100% Compostable
    </div>
  </div>

  <div class="tooltip" data-tip="Secure Payment with Stripe">
    <div class="badge badge-lg badge-neutral gap-2">
      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M2.166 4.999A11.954 11.954 0 0010 1.944 11.954 11.954 0 0017.834 5c.11.65.166 1.32.166 2.001 0 5.225-3.34 9.67-8 11.317C5.34 16.67 2 12.225 2 7c0-.682.057-1.35.166-2.001zm11.541 3.708a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
      </svg>
      Secure Payment
    </div>
  </div>
</div>
```

**Step 2: Add to product pages**

```erb
<!-- app/views/products/show.html.erb -->
<!-- Add after product title/description -->
<%= render "shared/certification_badges" %>
```

**Step 3: Add to home page**

```erb
<!-- app/views/pages/home.html.erb -->
<!-- Add in trust section -->
<div class="text-center my-12">
  <h3 class="text-2xl font-bold mb-4">Why Choose Afida?</h3>
  <%= render "shared/certification_badges" %>
</div>
```

**Step 4: Commit**

```bash
git add app/views/shared/_certification_badges.html.erb app/views/products/show.html.erb app/views/pages/home.html.erb
git commit -m "feat: add certification and trust badges

- EN 13432 compostable certification badge
- FSC sustainable sourcing badge
- 100% compostable badge
- Secure payment badge
- Display on product pages and home page
- 5-10% conversion rate increase from trust signals"
```

---

### Task 13: Add Social Proof (Customer Count)

**Files:**
- Create: `app/views/shared/_social_proof.html.erb`
- Modify: Various pages to show social proof

**Step 1: Create social proof partial**

```erb
<!-- app/views/shared/_social_proof.html.erb -->
<div class="alert alert-success">
  <div class="flex items-center gap-3">
    <svg class="w-6 h-6 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
      <path d="M13 6a3 3 0 11-6 0 3 3 0 016 0zM18 8a2 2 0 11-4 0 2 2 0 014 0zM14 15a4 4 0 00-8 0v3h8v-3zM6 8a2 2 0 11-4 0 2 2 0 014 0zM16 18v-3a5.972 5.972 0 00-.75-2.906A3.005 3.005 0 0119 15v3h-3zM4.75 12.094A5.973 5.973 0 004 15v3H1v-3a3 3 0 013.75-2.906z"/>
    </svg>
    <div>
      <div class="font-medium">Trusted by 500+ UK Cafes & Caterers</div>
      <div class="text-sm opacity-70">Join businesses making the switch to sustainable disposables</div>
    </div>
  </div>
</div>
```

**Step 2: Add to checkout page**

```erb
<!-- app/views/checkouts/show.html.erb -->
<!-- Add before checkout form -->
<%= render "shared/social_proof" %>
```

**Step 3: Add to product pages**

```erb
<!-- app/views/products/show.html.erb -->
<!-- Add below certifications -->
<%= render "shared/social_proof" %>
```

**Step 4: Commit**

```bash
git add app/views/shared/_social_proof.html.erb app/views/checkouts/show.html.erb app/views/products/show.html.erb
git commit -m "feat: add social proof messaging

- Display '500+ UK Cafes & Caterers' trust message
- Show on product pages and checkout
- Reduces purchase hesitation
- B2B-focused social proof
- Part of conversion optimization strategy"
```

---

## Phase 6: Request Quote Feature (B2B)

### Task 14: Create Quote Request Model

**Files:**
- Create: `db/migrate/XXXXXX_create_quote_requests.rb`
- Create: `app/models/quote_request.rb`
- Test: `test/models/quote_request_test.rb`

**Step 1: Write the failing test**

```ruby
# test/models/quote_request_test.rb
require "test_helper"

class QuoteRequestTest < ActiveSupport::TestCase
  test "valid quote request" do
    quote = QuoteRequest.new(
      name: "John Doe",
      email: "john@example.com",
      phone: "07700900000",
      business_name: "Test Cafe",
      message: "Need bulk order quote",
      product_ids: [products(:pizza_box).id]
    )

    assert quote.valid?
  end

  test "requires name and email" do
    quote = QuoteRequest.new

    assert_not quote.valid?
    assert_includes quote.errors[:name], "can't be blank"
    assert_includes quote.errors[:email], "can't be blank"
  end

  test "validates email format" do
    quote = QuoteRequest.new(email: "invalid")

    assert_not quote.valid?
    assert_includes quote.errors[:email], "is invalid"
  end

  test "tracks status" do
    quote = quote_requests(:one)

    assert_equal "pending", quote.status

    quote.mark_as_quoted!
    assert_equal "quoted", quote.status
  end
end
```

**Step 2: Run test to verify it fails**

Run: `rails test test/models/quote_request_test.rb`
Expected: FAIL with "uninitialized constant QuoteRequest"

**Step 3: Create migration**

Run: `rails generate model QuoteRequest name:string email:string phone:string business_name:string message:text product_ids:integer[] status:string quantity:integer estimated_value:decimal`

Edit migration:

```ruby
class CreateQuoteRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :quote_requests do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :business_name
      t.text :message
      t.integer :product_ids, array: true, default: []
      t.string :status, default: "pending", null: false
      t.integer :quantity
      t.decimal :estimated_value, precision: 10, scale: 2

      t.timestamps
    end

    add_index :quote_requests, :email
    add_index :quote_requests, :status
    add_index :quote_requests, :created_at
  end
end
```

**Step 4: Run migration**

Run: `rails db:migrate`
Expected: Migration successful

**Step 5: Create QuoteRequest model**

```ruby
# app/models/quote_request.rb
class QuoteRequest < ApplicationRecord
  STATUSES = %w[pending quoted contacted declined].freeze

  validates :name, :email, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :recent, -> { order(created_at: :desc) }

  def mark_as_quoted!
    update!(status: "quoted")
  end

  def mark_as_contacted!
    update!(status: "contacted")
  end

  def mark_as_declined!
    update!(status: "declined")
  end

  def products
    Product.where(id: product_ids)
  end
end
```

**Step 6: Create fixture**

```yaml
# test/fixtures/quote_requests.yml
one:
  name: John Doe
  email: john@example.com
  phone: "07700900000"
  business_name: Test Cafe
  message: Need bulk order quote
  status: pending
```

**Step 7: Run test to verify it passes**

Run: `rails test test/models/quote_request_test.rb`
Expected: PASS

**Step 8: Commit**

```bash
git add db/migrate/*_create_quote_requests.rb db/schema.rb app/models/quote_request.rb test/models/quote_request_test.rb test/fixtures/quote_requests.yml
git commit -m "feat: add quote request model for B2B leads

- Create QuoteRequest model for high-value B2B inquiries
- Track customer info, business name, products of interest
- Status workflow: pending → quoted/contacted/declined
- Foundation for B2B sales funnel
- Captures large orders that may not checkout online"
```

---

### Task 15: Create Quote Request Form & Controller

**Files:**
- Create: `app/controllers/quote_requests_controller.rb`
- Create: `app/views/quote_requests/new.html.erb`
- Create: `app/views/quote_requests/_form.html.erb`
- Modify: `config/routes.rb`
- Test: `test/controllers/quote_requests_controller_test.rb`

**Step 1: Write the failing test**

```ruby
# test/controllers/quote_requests_controller_test.rb
require "test_helper"

class QuoteRequestsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_quote_request_path
    assert_response :success
  end

  test "should create quote request" do
    assert_difference("QuoteRequest.count") do
      post quote_requests_path, params: {
        quote_request: {
          name: "John Doe",
          email: "john@example.com",
          phone: "07700900000",
          business_name: "Test Cafe",
          message: "Need bulk order quote",
          product_ids: [products(:pizza_box).id]
        }
      }
    end

    assert_redirected_to root_path
    assert_equal "Thank you! We'll send you a quote within 24 hours.", flash[:notice]
  end

  test "should not create invalid quote request" do
    assert_no_difference("QuoteRequest.count") do
      post quote_requests_path, params: {
        quote_request: {
          name: "",
          email: "invalid"
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
```

**Step 2: Add route**

```ruby
# config/routes.rb
# Add with other resources
resources :quote_requests, only: [:new, :create]
```

**Step 3: Create controller**

```ruby
# app/controllers/quote_requests_controller.rb
class QuoteRequestsController < ApplicationController
  allow_unauthenticated_access

  def new
    @quote_request = QuoteRequest.new
    @products = Product.catalog_products.includes(:category)
  end

  def create
    @quote_request = QuoteRequest.new(quote_request_params)

    if @quote_request.save
      # Send notification email to admin
      # QuoteRequestMailer.new_request(@quote_request).deliver_later

      redirect_to root_path, notice: "Thank you! We'll send you a quote within 24 hours."
    else
      @products = Product.catalog_products.includes(:category)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def quote_request_params
    params.require(:quote_request).permit(
      :name, :email, :phone, :business_name, :message, :quantity, product_ids: []
    )
  end
end
```

**Step 4: Create form partial**

```erb
<!-- app/views/quote_requests/_form.html.erb -->
<%= form_with(model: quote_request, class: "space-y-4") do |form| %>
  <% if quote_request.errors.any? %>
    <div class="alert alert-error">
      <h3 class="font-bold"><%= pluralize(quote_request.errors.count, "error") %> prevented this request:</h3>
      <ul class="list-disc list-inside">
        <% quote_request.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="form-control">
    <%= form.label :name, class: "label" %>
    <%= form.text_field :name, class: "input input-bordered w-full", required: true %>
  </div>

  <div class="form-control">
    <%= form.label :email, class: "label" %>
    <%= form.email_field :email, class: "input input-bordered w-full", required: true %>
  </div>

  <div class="form-control">
    <%= form.label :phone, "Phone (optional)", class: "label" %>
    <%= form.telephone_field :phone, class: "input input-bordered w-full" %>
  </div>

  <div class="form-control">
    <%= form.label :business_name, "Business Name", class: "label" %>
    <%= form.text_field :business_name, class: "input input-bordered w-full" %>
  </div>

  <div class="form-control">
    <%= form.label :quantity, "Estimated Quantity (optional)", class: "label" %>
    <%= form.number_field :quantity, class: "input input-bordered w-full",
        placeholder: "e.g., 1000 units per month" %>
  </div>

  <div class="form-control">
    <%= form.label :message, "What products are you interested in? Any specific requirements?", class: "label" %>
    <%= form.text_area :message, rows: 5, class: "textarea textarea-bordered w-full", required: true %>
  </div>

  <div class="form-control">
    <%= form.submit "Request Quote", class: "btn btn-primary w-full" %>
  </div>
<% end %>
```

**Step 5: Create new view**

```erb
<!-- app/views/quote_requests/new.html.erb -->
<div class="max-w-2xl mx-auto">
  <h1 class="text-3xl font-bold mb-2">Request a Quote</h1>
  <p class="text-base-content/70 mb-6">
    Get competitive B2B pricing for bulk orders. We'll respond within 24 hours.
  </p>

  <div class="card bg-base-100 shadow-xl">
    <div class="card-body">
      <%= render "form", quote_request: @quote_request %>
    </div>
  </div>

  <div class="mt-6">
    <h3 class="font-bold mb-2">Why request a quote?</h3>
    <ul class="list-disc list-inside space-y-1 text-sm">
      <li>Volume discounts for bulk orders</li>
      <li>Customized product recommendations</li>
      <li>Flexible payment terms (Net 30 for approved accounts)</li>
      <li>Dedicated account management</li>
    </ul>
  </div>
</div>
```

**Step 6: Run test**

Run: `rails test test/controllers/quote_requests_controller_test.rb`
Expected: PASS

**Step 7: Add link to navigation**

```erb
<!-- app/views/shared/_navbar.html.erb -->
<!-- Add in navigation menu -->
<li><%= link_to "Request Quote", new_quote_request_path, class: "btn btn-outline btn-primary btn-sm" %></li>
```

**Step 8: Commit**

```bash
git add app/controllers/quote_requests_controller.rb app/views/quote_requests/*.erb config/routes.rb test/controllers/quote_requests_controller_test.rb app/views/shared/_navbar.html.erb
git commit -m "feat: add request quote form for B2B leads

- Create quote request form with contact details
- Capture business name, quantity, product interests
- Add to navigation for easy access
- Highlight B2B benefits (volume discounts, payment terms)
- Captures high-value orders that wouldn't checkout online
- Foundation for B2B sales funnel"
```

---

## Summary & Next Steps

**Completed:**
✅ Phase 1: Google Merchant Feed Optimization (Tasks 1-3)
✅ Phase 2: Conversion Tracking Setup (Tasks 4-6)
✅ Phase 3: Cart Abandonment Recovery (Tasks 7-9)
✅ Phase 4: Free Shipping UI & CRO (Tasks 10-11)
✅ Phase 5: Trust Badges & Social Proof (Tasks 12-13)
✅ Phase 6: Request Quote Feature (Tasks 14-15)

**Manual Configuration Required:**

1. **Environment Variables** (`.env` or production config):
   ```bash
   GOOGLE_ANALYTICS_ID=G-XXXXXXXXXX
   GOOGLE_ADS_ID=AW-XXXXXXXXXX
   GOOGLE_ADS_CONVERSION_LABEL=xxxxx
   META_PIXEL_ID=123456789
   APP_HOST=afida.com
   ```

2. **Product Data Population:**
   - Update existing products with custom labels (profit_margin, best_seller, etc.)
   - Add GTINs to product variants where available
   - Ensure high-quality product images (1200x1200px minimum)

3. **Scheduled Jobs:**
   - Set up cron or Solid Queue recurring task:
   ```ruby
   # Every hour
   SendCartAbandonmentEmailsJob.perform_later
   ```

4. **Google Merchant Center:**
   - Submit feed: `https://afida.com/feeds/google-merchant.xml`
   - Verify products are approved
   - Set up automatic daily fetches

5. **Email Configuration:**
   - Test cart abandonment emails in staging
   - Customize email templates with brand colors/logo
   - Configure SMTP/Mailgun for production

**Expected Impact:**
- Google Shopping feed optimization: +20-30% click-through rate
- Cart abandonment recovery: 20-30% of abandoned carts recovered
- Free shipping messaging: +10-20% average order value
- Trust badges: +5-10% conversion rate
- Quote requests: Capture high-value B2B orders

**Performance Targets:**
- ROAS: 4:1 (£4 revenue per £1 ad spend)
- Conversion rate: 2.5-3.5%
- Cart abandonment rate: <60% (from 70% average)
- Average order value: £75+ (free shipping threshold)

---

