# Quickstart: Shop Page Filters and Search

**Feature**: Shop Page - Product Listing with Filters and Search
**Branch**: `003-shop-page-filters-search`
**Date**: 2025-01-14

## Overview

This quickstart guide walks through implementing the shop page product listing with filters, search, and sorting. Follow the TDD approach: write tests first (red), implement code (green), then refactor (refactor).

---

## Prerequisites

**Required**:
- Rails 8.x application running
- PostgreSQL 14+ database
- Existing Product, Category, ProductVariant models
- Vite + TailwindCSS + DaisyUI frontend setup
- Hotwire (Turbo + Stimulus) installed

**Verify Setup**:
```bash
rails -v                 # Should be 8.x
bundle list | grep pagy  # Install if missing: bundle add pagy
```

---

## Phase 1: Add Pagy Gem (5 minutes)

### 1.1 Install Pagy Gem

```bash
bundle add pagy
```

### 1.2 Configure Pagy

Create initializer:

```ruby
# config/initializers/pagy.rb
require 'pagy/extras/overflow'

Pagy::DEFAULT[:items] = 24  # Products per page
Pagy::DEFAULT[:overflow] = :last_page  # Show last page if page number too high
```

### 1.3 Include Pagy in Controllers and Helpers

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pagy::Backend  # Add this line
end
```

```ruby
# app/helpers/application_helper.rb
module ApplicationHelper
  include Pagy::Frontend  # Add this line
end
```

**Verify**: Rails server should start without errors

---

## Phase 2: Write Model Tests (TDD Red Phase) (15 minutes)

### 2.1 Test Product.search Scope

```ruby
# test/models/product_test.rb

class ProductTest < ActiveSupport::TestCase
  # ... existing tests ...

  test "search returns products matching name" do
    pizza_box = products(:pizza_box)  # Assumes fixture exists
    cup = products(:cup)

    results = Product.search("pizza")

    assert_includes results, pizza_box
    refute_includes results, cup
  end

  test "search returns products matching SKU" do
    product = products(:pizza_box)
    product.update(sku: "PIZB-001")

    results = Product.search("PIZB")

    assert_includes results, product
  end

  test "search is case-insensitive" do
    product = products(:pizza_box)

    results = Product.search("PIZZA")

    assert_includes results, product
  end

  test "search returns all products when query is blank" do
    all_count = Product.count

    assert_equal all_count, Product.search("").count
    assert_equal all_count, Product.search(nil).count
  end
end
```

**Run Tests** (should FAIL - red phase):
```bash
rails test test/models/product_test.rb
```

### 2.2 Test Product.in_category Scope

```ruby
# test/models/product_test.rb

test "in_category filters by category ID" do
  pizza_box = products(:pizza_box)  # category_id = 1
  cup = products(:cup)              # category_id = 2

  results = Product.in_category(1)

  assert_includes results, pizza_box
  refute_includes results, cup
end

test "in_category returns all products when category_id is blank" do
  all_count = Product.count

  assert_equal all_count, Product.in_category("").count
  assert_equal all_count, Product.in_category(nil).count
end
```

**Run Tests** (should FAIL):
```bash
rails test test/models/product_test.rb
```

### 2.3 Test Product.sorted Scope

```ruby
# test/models/product_test.rb

test "sorted by relevance uses default order" do
  products = Product.sorted("relevance").to_a

  # Should match default scope (position ASC, name ASC)
  assert_equal Product.all.to_a, products
end

test "sorted by name_asc orders alphabetically" do
  products = Product.sorted("name_asc").pluck(:name)

  assert_equal products.sort, products
end

test "sorted by price_asc orders by minimum variant price" do
  cheap = products(:cheap_product)   # min price £1.00
  expensive = products(:expensive_product)  # min price £10.00

  results = Product.sorted("price_asc").to_a

  assert results.index(cheap) < results.index(expensive)
end
```

**Run Tests** (should FAIL):
```bash
rails test test/models/product_test.rb
```

---

## Phase 3: Implement Model Scopes (TDD Green Phase) (20 minutes)

### 3.1 Implement Product.search Scope

```ruby
# app/models/product.rb

scope :search, ->(query) {
  return all if query.blank?

  sanitized_query = sanitize_sql_like(query)
  where("name ILIKE ? OR sku ILIKE ? OR colour ILIKE ?",
        "%#{sanitized_query}%",
        "%#{sanitized_query}%",
        "%#{sanitized_query}%")
}
```

**Run Tests** (should PASS):
```bash
rails test test/models/product_test.rb -n /search/
```

### 3.2 Implement Product.in_category Scope

```ruby
# app/models/product.rb

scope :in_category, ->(category_id) {
  return all if category_id.blank?

  where(category_id: category_id)
}
```

**Run Tests** (should PASS):
```bash
rails test test/models/product_test.rb -n /in_category/
```

### 3.3 Implement Product.sorted Scope

```ruby
# app/models/product.rb

scope :sorted, ->(sort_param) {
  case sort_param
  when "price_asc"
    # Join with variants to get minimum price
    joins(:active_variants)
      .select("products.*, MIN(product_variants.price) as min_price")
      .group("products.id")
      .order("min_price ASC, products.name ASC")
  when "price_desc"
    joins(:active_variants)
      .select("products.*, MAX(product_variants.price) as max_price")
      .group("products.id")
      .order("max_price DESC, products.name ASC")
  when "name_asc"
    order(name: :asc)
  else  # "relevance" or nil
    # Use default scope (position ASC, name ASC)
    order(position: :asc, name: :asc)
  end
}
```

**Run Tests** (should PASS):
```bash
rails test test/models/product_test.rb -n /sorted/
```

**Run All Model Tests**:
```bash
rails test test/models/product_test.rb
```

---

## Phase 4: Add Database Indexes (5 minutes)

### 4.1 Generate Migration

```bash
rails generate migration AddSearchAndFilterIndexesToProducts
```

### 4.2 Write Migration

```ruby
# db/migrate/[timestamp]_add_search_and_filter_indexes_to_products.rb

class AddSearchAndFilterIndexesToProducts < ActiveRecord::Migration[8.1]
  def change
    # Category filtering
    add_index :products, :category_id unless index_exists?(:products, :category_id)

    # Search by name and SKU
    add_index :products, :name
    add_index :products, :sku

    # Composite index for active products in category
    add_index :products, [:active, :category_id]
  end
end
```

### 4.3 Run Migration

```bash
rails db:migrate
```

**Verify**:
```bash
rails db:migrate:status
# Should show migration as 'up'
```

---

## Phase 5: Write Controller Tests (TDD Red Phase) (15 minutes)

### 5.1 Test Shop Page Action

```ruby
# test/controllers/pages_controller_test.rb

class PagesControllerTest < ActionDispatch::IntegrationTest
  # ... existing tests ...

  test "shop page displays all products by default" do
    get shop_path

    assert_response :success
    assert_select "h1", text: /Shop/
    # Check that products are displayed
    Product.limit(5).each do |product|
      assert_select "a[href=?]", product_path(product.slug)
    end
  end

  test "shop page filters by category" do
    category = categories(:pizza_boxes)
    pizza_box = products(:pizza_box)

    get shop_path(category_id: category.id)

    assert_response :success
    assert_select "a[href=?]", product_path(pizza_box.slug)
  end

  test "shop page searches products" do
    pizza_box = products(:pizza_box)

    get shop_path(q: "pizza")

    assert_response :success
    assert_select "a[href=?]", product_path(pizza_box.slug)
  end

  test "shop page sorts products by price" do
    get shop_path(sort: "price_asc")

    assert_response :success
    # Verify products are present (specific order checking in system tests)
  end

  test "shop page paginates products" do
    get shop_path(page: 2)

    assert_response :success
    # Pagy should handle pagination
  end

  test "shop page combines filters" do
    category = categories(:cups)

    get shop_path(category_id: category.id, q: "8oz", sort: "price_asc")

    assert_response :success
  end
end
```

**Run Tests** (should FAIL):
```bash
rails test test/controllers/pages_controller_test.rb
```

---

## Phase 6: Update Controller (TDD Green Phase) (15 minutes)

### 6.1 Update PagesController#shop

```ruby
# app/controllers/pages_controller.rb

def shop
  @categories = Category.all.order(:position)

  @products = Product
    .includes(:category,
              :active_variants,
              product_photo_attachment: :blob,
              lifestyle_photo_attachment: :blob)
    .in_category(params[:category_id])
    .search(params[:q])
    .sorted(params[:sort])

  @pagy, @products = pagy(@products, items: 24)
end
```

**Run Tests** (should PASS):
```bash
rails test test/controllers/pages_controller_test.rb
```

---

## Phase 7: Create Stimulus Controller for Search (10 minutes)

### 7.1 Create Search Controller

```javascript
// app/frontend/javascript/controllers/search_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  debounce(event) {
    clearTimeout(this.timeout)

    this.timeout = setTimeout(() => {
      // Trigger form submission (Turbo will handle it)
      this.element.requestSubmit()
    }, this.delayValue)
  }

  disconnect() {
    // Clean up timeout on controller disconnect
    clearTimeout(this.timeout)
  }
}
```

### 7.2 Register Controller

```javascript
// app/frontend/entrypoints/application.js

import SearchController from '../javascript/controllers/search_controller'

// ... existing code ...

application.register('search', SearchController)
```

---

## Phase 8: Update View (30 minutes)

### 8.1 Update Shop Page View

```erb
<!-- app/views/pages/shop.html.erb -->

<% content_for :title, "Shop Eco-Friendly Catering Supplies | Afida" %>
<% content_for :meta_description, "Browse our complete range of eco-friendly catering supplies. Filter by category, search products, and find exactly what you need." %>

<div class="container mx-auto px-4 py-8">
  <h1 class="text-3xl font-bold mb-8">Shop All Products</h1>

  <div class="flex flex-col md:flex-row gap-8">
    <!-- Filter Sidebar (Static - outside Turbo Frame) -->
    <aside class="w-full md:w-64 flex-shrink-0">
      <%= form_with url: shop_path, method: :get, data: { turbo_frame: "products", turbo_action: "replace" }, class: "space-y-6" do |f| %>

        <!-- Category Filter -->
        <fieldset class="border-t pt-4">
          <legend class="font-semibold text-lg mb-3">Category</legend>

          <label class="flex items-center gap-2 mb-2 cursor-pointer">
            <%= radio_button_tag :category_id, "", params[:category_id].blank?, class: "radio radio-primary", data: { action: "change->form#submit" } %>
            <span>All Products</span>
          </label>

          <% @categories.each do |category| %>
            <label class="flex items-center gap-2 mb-2 cursor-pointer">
              <%= radio_button_tag :category_id, category.id, params[:category_id].to_i == category.id, class: "radio radio-primary", data: { action: "change->form#submit" } %>
              <span><%= category.name %> (<%= category.products_count %>)</span>
            </label>
          <% end %>
        </fieldset>

        <!-- Search Input -->
        <div>
          <label for="search" class="font-semibold text-lg mb-3 block">Search</label>
          <%= text_field_tag :q, params[:q], placeholder: "Search products...", class: "input input-bordered w-full", data: { controller: "search", action: "input->search#debounce" } %>
        </div>

        <!-- Sort Dropdown -->
        <div>
          <label for="sort" class="font-semibold text-lg mb-3 block">Sort By</label>
          <%= select_tag :sort, options_for_select([
            ["Relevance", "relevance"],
            ["Price: Low to High", "price_asc"],
            ["Price: High to Low", "price_desc"],
            ["Name: A-Z", "name_asc"]
          ], params[:sort]), class: "select select-bordered w-full", data: { action: "change->form#submit" } %>
        </div>

        <!-- Clear Filters -->
        <% if params[:category_id].present? || params[:q].present? || params[:sort].present? %>
          <%= link_to "Clear Filters", shop_path, class: "btn btn-outline w-full" %>
        <% end %>
      <% end %>
    </aside>

    <!-- Product Grid (Dynamic - inside Turbo Frame) -->
    <%= turbo_frame_tag "products", data: { turbo_action: "replace" } do %>
      <div class="flex-1">
        <% if @products.any? %>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
            <% @products.each do |product| %>
              <%= render 'products/card', product: product %>
            <% end %>
          </div>

          <!-- Pagination -->
          <div class="flex justify-center">
            <%== pagy_nav(@pagy) if @pagy.pages > 1 %>
          </div>
        <% else %>
          <div class="text-center py-12">
            <p class="text-xl text-gray-600 mb-4">No products found matching your search.</p>
            <%= link_to "Clear Filters", shop_path, class: "btn btn-primary" %>
          </div>
        <% end %>
      </div>
    <% end %>
  </div>
</div>
```

### 8.2 Create Product Card Partial (if not exists)

```erb
<!-- app/views/products/_card.html.erb -->

<div class="card bg-base-100 shadow-sm hover:shadow-md transition">
  <%= link_to product_path(product.slug) do %>
    <figure class="aspect-square">
      <% if product.primary_photo.attached? %>
        <%= image_tag product.primary_photo, alt: product.name, class: "w-full h-full object-cover" %>
      <% else %>
        <div class="w-full h-full bg-gradient-to-br from-primary/20 to-secondary/20 flex items-center justify-center">
          <span class="text-4xl font-bold text-primary/30"><%= product.name[0] %></span>
        </div>
      <% end %>
    </figure>

    <div class="card-body p-4">
      <h3 class="card-title text-lg"><%= product.name %></h3>
      <p class="text-sm text-gray-600"><%= product.category.name %></p>

      <% price_range = product.price_range %>
      <% if price_range.is_a?(Array) %>
        <p class="text-lg font-semibold">From <%= number_to_currency(price_range[0], unit: "£") %> - <%= number_to_currency(price_range[1], unit: "£") %></p>
      <% elsif price_range %>
        <p class="text-lg font-semibold"><%= number_to_currency(price_range, unit: "£") %></p>
      <% end %>
    </div>
  <% end %>
</div>
```

---

## Phase 9: Write System Tests (15 minutes)

### 9.1 Create Shop Page System Test

```ruby
# test/system/shop_page_test.rb

require "application_system_test_case"

class ShopPageTest < ApplicationSystemTestCase
  test "browsing all products" do
    visit shop_path

    assert_selector "h1", text: "Shop All Products"
    assert_selector ".product-card", minimum: 1
  end

  test "filtering by category" do
    visit shop_path

    # Click category filter
    choose "Pizza Boxes"

    # Should update product grid without full page reload
    assert_selector ".product-card", minimum: 1

    # URL should reflect filter
    assert_current_path(/category_id=/)
  end

  test "searching products" do
    visit shop_path

    # Enter search query
    fill_in "Search", with: "pizza"

    # Wait for debounced search (300ms + request time)
    sleep 0.5

    # Should show matching products
    assert_selector ".product-card", minimum: 1
    assert_current_path(/q=pizza/)
  end

  test "combining filters and search" do
    visit shop_path

    # Apply category filter
    choose "Cups"

    # Enter search
    fill_in "Search", with: "8oz"
    sleep 0.5

    # Should show products matching both
    assert_selector ".product-card", minimum: 0  # May be 0 if no matches

    # URL should include both params
    assert_current_path(/category_id=/)
    assert_current_path(/q=8oz/)
  end

  test "sorting products" do
    visit shop_path

    # Select sort option
    select "Price: Low to High", from: "Sort By"

    # Should reorder products
    assert_selector ".product-card", minimum: 1
    assert_current_path(/sort=price_asc/)
  end

  test "pagination" do
    # Only test if there are 25+ products
    skip unless Product.count > 24

    visit shop_path

    # Should show pagination
    assert_selector "nav.pagination"

    # Click page 2
    click_link "2"

    # Should show page 2 products
    assert_current_path(/page=2/)
  end

  test "clearing filters" do
    visit shop_path(category_id: 1, q: "test")

    # Should show clear button
    click_link "Clear Filters"

    # Should return to unfiltered view
    assert_current_path shop_path
  end
end
```

**Run System Tests**:
```bash
rails test:system test/system/shop_page_test.rb
```

---

## Phase 10: Verify Performance (10 minutes)

### 10.1 Check for N+1 Queries

```bash
# Start Rails server with Bullet gem (should already be configured)
bin/dev

# Visit http://localhost:3000/shop
# Check browser console or Rails logs for N+1 warnings
```

**Expected Queries** (should be ~5):
1. Load categories
2. Load products
3. Eager load product categories
4. Eager load product variants
5. Eager load product photos

### 10.2 Benchmark Page Load

```ruby
# In Rails console
require 'benchmark'

Benchmark.measure do
  ApplicationController.new.tap do |controller|
    controller.request = ActionDispatch::TestRequest.create
    controller.shop
  end
end
```

**Target**: < 500ms for database queries

---

## Phase 11: Final Checks (5 minutes)

### 11.1 Run All Tests

```bash
rails test                  # All tests should pass
rails test:system           # System tests should pass
rubocop                     # Code quality check
brakeman                    # Security scan
```

### 11.2 Manual Testing Checklist

- [ ] Visit /shop page - all products displayed
- [ ] Click category filter - products filtered
- [ ] Enter search query - products filtered after debounce
- [ ] Select sort option - products reordered
- [ ] Combine filters - products match all criteria
- [ ] Clear filters - returns to all products
- [ ] Test pagination (if 25+ products)
- [ ] Test mobile responsive design
- [ ] Verify URL updates with filters
- [ ] Test browser back/forward buttons
- [ ] Verify no JavaScript errors in console
- [ ] Check page load performance (<2 seconds)

---

## Troubleshooting

### Issue: Search not debouncing

**Solution**: Verify Stimulus controller is registered and connected
```javascript
// In browser console
document.querySelector('[data-controller="search"]')
// Should return the input element
```

### Issue: N+1 queries detected

**Solution**: Verify eager loading in controller
```ruby
.includes(:category, :active_variants, product_photo_attachment: :blob)
```

### Issue: Turbo Frame not updating

**Solution**: Check Turbo Frame ID matches in form and response
```erb
<%= form_with data: { turbo_frame: "products" } %>
<%= turbo_frame_tag "products" %>
```

### Issue: Pagination not working

**Solution**: Verify Pagy is included and configured
```ruby
# In ApplicationController
include Pagy::Backend

# In ApplicationHelper
include Pagy::Frontend
```

---

## Next Steps

After completing this implementation:

1. **Add filtering by other attributes** (e.g., price range, featured products)
2. **Implement infinite scroll** as alternative to pagination
3. **Add product count badge** to category filters
4. **Optimize images** with lazy loading for better performance
5. **Add analytics** to track popular searches and filters
6. **Consider full-text search** if catalog grows beyond 1000 products

---

## Summary

**Time Estimate**: ~2 hours (following TDD strictly)

**Files Modified**:
- `app/models/product.rb` - Add scopes
- `app/controllers/pages_controller.rb` - Update shop action
- `app/views/pages/shop.html.erb` - Add filters and product grid
- `app/frontend/javascript/controllers/search_controller.js` - New file

**Files Created**:
- `db/migrate/[timestamp]_add_search_and_filter_indexes_to_products.rb`
- `test/system/shop_page_test.rb`

**Test Coverage**:
- Model scopes (search, filter, sort)
- Controller actions (params handling)
- System tests (full user flows)

**Performance**:
- Max 5 database queries (with eager loading)
- Database indexes for fast filtering
- Pagination limits query size

Implementation complete! Ready to run `/speckit.tasks` to generate task breakdown.
