# Variant-Level Sample Request Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow visitors to select up to 5 specific product variants as free samples, checkout via Stripe with £7.50 flat shipping (or free when combined with paid products).

**Architecture:** Category-based samples page with Turbo Frame expansion, immediate add-to-cart for samples as £0 items, variant-level `sample_eligible` flag, shipping logic branch in checkout.

**Tech Stack:** Rails 8, Hotwire (Turbo Frames + Stimulus), TailwindCSS 4 + DaisyUI, PostgreSQL, Stripe Checkout

**Design Document:** `docs/plans/2025-12-01-variant-samples-design.md`

---

## Phase 1: Database & Model Foundation

### Task 1: Create Migration for ProductVariant Sample Fields

**Files:**
- Create: `db/migrate/TIMESTAMP_add_sample_fields_to_product_variants.rb`

**Step 1: Generate migration**

Run:
```bash
rails generate migration AddSampleFieldsToProductVariants sample_eligible:boolean sample_sku:string
```

**Step 2: Edit migration to set defaults and add index**

```ruby
class AddSampleFieldsToProductVariants < ActiveRecord::Migration[8.0]
  def change
    add_column :product_variants, :sample_eligible, :boolean, default: false, null: false
    add_column :product_variants, :sample_sku, :string

    add_index :product_variants, :sample_eligible
  end
end
```

**Step 3: Run migration**

Run: `rails db:migrate`
Expected: Migration runs successfully

**Step 4: Commit**

```bash
git add db/migrate/*_add_sample_fields_to_product_variants.rb db/schema.rb
git commit -m "Add sample_eligible and sample_sku fields to product_variants"
```

---

### Task 2: Add ProductVariant Sample Methods

**Files:**
- Modify: `app/models/product_variant.rb`
- Test: `test/models/product_variant_test.rb`

**Step 1: Write failing tests**

Add to `test/models/product_variant_test.rb`:

```ruby
class ProductVariantTest < ActiveSupport::TestCase
  # ... existing tests ...

  test "sample_eligible defaults to false" do
    variant = ProductVariant.new
    assert_equal false, variant.sample_eligible
  end

  test "sample_eligible scope returns only eligible variants" do
    eligible = product_variants(:one)
    eligible.update!(sample_eligible: true)

    ineligible = product_variants(:two)
    ineligible.update!(sample_eligible: false)

    results = ProductVariant.sample_eligible
    assert_includes results, eligible
    assert_not_includes results, ineligible
  end

  test "generates sample_sku from sku if blank" do
    variant = product_variants(:one)
    variant.update!(sample_eligible: true, sample_sku: nil)

    assert_equal "SAMPLE-#{variant.sku}", variant.effective_sample_sku
  end

  test "uses provided sample_sku when present" do
    variant = product_variants(:one)
    variant.update!(sample_eligible: true, sample_sku: "CUSTOM-SAMPLE-SKU")

    assert_equal "CUSTOM-SAMPLE-SKU", variant.effective_sample_sku
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `rails test test/models/product_variant_test.rb`
Expected: 4 failures (new tests)

**Step 3: Add scope and methods to ProductVariant**

Add to `app/models/product_variant.rb`:

```ruby
class ProductVariant < ApplicationRecord
  # ... existing code ...

  scope :sample_eligible, -> { where(sample_eligible: true) }

  def effective_sample_sku
    sample_sku.presence || "SAMPLE-#{sku}"
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `rails test test/models/product_variant_test.rb`
Expected: All tests pass

**Step 5: Commit**

```bash
git add app/models/product_variant.rb test/models/product_variant_test.rb
git commit -m "Add sample_eligible scope and effective_sample_sku to ProductVariant"
```

---

### Task 3: Add Cart Sample Methods

**Files:**
- Modify: `app/models/cart.rb`
- Test: `test/models/cart_test.rb`

**Step 1: Write failing tests**

Add to `test/models/cart_test.rb`:

```ruby
class CartTest < ActiveSupport::TestCase
  setup do
    @cart = carts(:one)
    @cart.cart_items.destroy_all
  end

  test "sample_items returns only sample cart items" do
    # Create sample-eligible variant
    sample_variant = product_variants(:one)
    sample_variant.update!(sample_eligible: true, price: 0)

    # Create non-sample variant
    regular_variant = product_variants(:two)
    regular_variant.update!(sample_eligible: false)

    # Add both to cart
    sample_item = @cart.cart_items.create!(product_variant: sample_variant, quantity: 1, price: 0)
    regular_item = @cart.cart_items.create!(product_variant: regular_variant, quantity: 1, price: 10)

    assert_includes @cart.sample_items, sample_item
    assert_not_includes @cart.sample_items, regular_item
  end

  test "sample_count returns number of sample items" do
    sample_variant = product_variants(:one)
    sample_variant.update!(sample_eligible: true, price: 0)

    @cart.cart_items.create!(product_variant: sample_variant, quantity: 1, price: 0)

    assert_equal 1, @cart.sample_count
  end

  test "only_samples? returns true when cart has only samples" do
    sample_variant = product_variants(:one)
    sample_variant.update!(sample_eligible: true, price: 0)

    @cart.cart_items.create!(product_variant: sample_variant, quantity: 1, price: 0)

    assert @cart.only_samples?
  end

  test "only_samples? returns false when cart has paid items" do
    sample_variant = product_variants(:one)
    sample_variant.update!(sample_eligible: true, price: 0)

    regular_variant = product_variants(:two)
    regular_variant.update!(sample_eligible: false, price: 10)

    @cart.cart_items.create!(product_variant: sample_variant, quantity: 1, price: 0)
    @cart.cart_items.create!(product_variant: regular_variant, quantity: 1, price: 10)

    assert_not @cart.only_samples?
  end

  test "at_sample_limit? returns true when 5 samples in cart" do
    5.times do |i|
      variant = ProductVariant.create!(
        product: products(:one),
        sku: "SAMPLE-TEST-#{i}",
        price: 0,
        sample_eligible: true,
        active: true
      )
      @cart.cart_items.create!(product_variant: variant, quantity: 1, price: 0)
    end

    assert @cart.at_sample_limit?
  end

  test "at_sample_limit? returns false when under 5 samples" do
    sample_variant = product_variants(:one)
    sample_variant.update!(sample_eligible: true, price: 0)

    @cart.cart_items.create!(product_variant: sample_variant, quantity: 1, price: 0)

    assert_not @cart.at_sample_limit?
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `rails test test/models/cart_test.rb`
Expected: 6 failures (new tests)

**Step 3: Add sample methods to Cart model**

Add to `app/models/cart.rb`:

```ruby
class Cart < ApplicationRecord
  # ... existing code ...

  SAMPLE_LIMIT = 5

  def sample_items
    cart_items.joins(:product_variant)
              .where(product_variants: { sample_eligible: true })
  end

  def sample_count
    sample_items.count
  end

  def only_samples?
    cart_items.any? && cart_items.where("price > 0").none?
  end

  def at_sample_limit?
    sample_count >= SAMPLE_LIMIT
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `rails test test/models/cart_test.rb`
Expected: All tests pass

**Step 5: Commit**

```bash
git add app/models/cart.rb test/models/cart_test.rb
git commit -m "Add sample_items, sample_count, only_samples?, at_sample_limit? to Cart"
```

---

### Task 4: Add Order Sample Methods

**Files:**
- Modify: `app/models/order.rb`
- Test: `test/models/order_test.rb`

**Step 1: Write failing tests**

Add to `test/models/order_test.rb`:

```ruby
class OrderTest < ActiveSupport::TestCase
  test "contains_samples? returns true when order has sample items" do
    order = orders(:one)
    variant = product_variants(:one)
    variant.update!(sample_eligible: true)

    order.order_items.create!(
      product_variant: variant,
      quantity: 1,
      price: 0,
      pac_size: 1
    )

    assert order.contains_samples?
  end

  test "contains_samples? returns false when no sample items" do
    order = orders(:one)
    order.order_items.destroy_all

    variant = product_variants(:one)
    variant.update!(sample_eligible: false)

    order.order_items.create!(
      product_variant: variant,
      quantity: 1,
      price: 10,
      pac_size: 1
    )

    assert_not order.contains_samples?
  end

  test "sample_request? returns true for samples-only orders" do
    order = orders(:one)
    order.order_items.destroy_all

    variant = product_variants(:one)
    variant.update!(sample_eligible: true)

    order.order_items.create!(
      product_variant: variant,
      quantity: 1,
      price: 0,
      pac_size: 1
    )

    assert order.sample_request?
  end

  test "sample_request? returns false for mixed orders" do
    order = orders(:one)
    order.order_items.destroy_all

    sample_variant = product_variants(:one)
    sample_variant.update!(sample_eligible: true)

    regular_variant = product_variants(:two)
    regular_variant.update!(sample_eligible: false)

    order.order_items.create!(product_variant: sample_variant, quantity: 1, price: 0, pac_size: 1)
    order.order_items.create!(product_variant: regular_variant, quantity: 1, price: 10, pac_size: 1)

    assert_not order.sample_request?
  end

  test "with_samples scope returns orders containing samples" do
    order_with_samples = orders(:one)
    order_with_samples.order_items.destroy_all

    sample_variant = product_variants(:one)
    sample_variant.update!(sample_eligible: true)
    order_with_samples.order_items.create!(product_variant: sample_variant, quantity: 1, price: 0, pac_size: 1)

    results = Order.with_samples
    assert_includes results, order_with_samples
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `rails test test/models/order_test.rb`
Expected: Failures for new tests

**Step 3: Add sample methods to Order model**

Add to `app/models/order.rb`:

```ruby
class Order < ApplicationRecord
  # ... existing code ...

  scope :with_samples, -> {
    joins(order_items: :product_variant)
      .where(product_variants: { sample_eligible: true })
      .distinct
  }

  def contains_samples?
    order_items.joins(:product_variant)
               .exists?(product_variants: { sample_eligible: true })
  end

  def sample_request?
    contains_samples? && order_items.where("price > 0").none?
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `rails test test/models/order_test.rb`
Expected: All tests pass

**Step 5: Commit**

```bash
git add app/models/order.rb test/models/order_test.rb
git commit -m "Add contains_samples?, sample_request?, with_samples scope to Order"
```

---

## Phase 2: Samples Controller & Routes

### Task 5: Create SamplesController with Index Action

**Files:**
- Create: `app/controllers/samples_controller.rb`
- Modify: `config/routes.rb`
- Test: `test/controllers/samples_controller_test.rb`

**Step 1: Write failing controller test**

Create `test/controllers/samples_controller_test.rb`:

```ruby
require "test_helper"

class SamplesControllerTest < ActionDispatch::IntegrationTest
  test "index renders samples page" do
    get samples_path
    assert_response :success
    assert_select "h1", /sample/i
  end

  test "index groups sample-eligible variants by category" do
    # Create sample-eligible variant
    variant = product_variants(:one)
    variant.update!(sample_eligible: true)

    get samples_path
    assert_response :success
  end

  test "category returns variants for specific category via turbo frame" do
    category = categories(:one)
    variant = product_variants(:one)
    variant.product.update!(category: category)
    variant.update!(sample_eligible: true)

    get category_samples_path(category.slug),
        headers: { "Turbo-Frame" => "category_#{category.id}" }

    assert_response :success
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `rails test test/controllers/samples_controller_test.rb`
Expected: Failures (route/controller not found)

**Step 3: Add routes**

Add to `config/routes.rb` (inside the main block):

```ruby
resources :samples, only: [:index] do
  collection do
    get ":category_slug", action: :category, as: :category
  end
end
```

**Step 4: Create SamplesController**

Create `app/controllers/samples_controller.rb`:

```ruby
class SamplesController < ApplicationController
  allow_unauthenticated_access

  def index
    @categories = Category.joins(products: :variants)
                          .where(product_variants: { sample_eligible: true, active: true })
                          .distinct
                          .order(:position)
  end

  def category
    @category = Category.find_by!(slug: params[:category_slug])
    @variants = ProductVariant.sample_eligible
                              .joins(:product)
                              .where(products: { category_id: @category.id, active: true })
                              .where(active: true)
                              .includes(product: { product_photo_attachment: :blob })

    render partial: "samples/category_variants", locals: { category: @category, variants: @variants }
  end
end
```

**Step 5: Create placeholder view**

Create `app/views/samples/index.html.erb`:

```erb
<div class="container mx-auto px-4 py-8">
  <h1 class="text-3xl font-bold">Request Free Samples</h1>
  <p>Select up to 5 samples - just pay shipping</p>
</div>
```

Create `app/views/samples/_category_variants.html.erb`:

```erb
<div class="grid grid-cols-2 md:grid-cols-4 gap-4 p-4">
  <% variants.each do |variant| %>
    <div class="card bg-base-100 shadow">
      <div class="card-body p-4">
        <h3 class="card-title text-sm"><%= variant.product.name %></h3>
        <p class="text-xs text-gray-500"><%= variant.name %></p>
      </div>
    </div>
  <% end %>
</div>
```

**Step 6: Run tests to verify they pass**

Run: `rails test test/controllers/samples_controller_test.rb`
Expected: All tests pass

**Step 7: Commit**

```bash
git add app/controllers/samples_controller.rb config/routes.rb \
        test/controllers/samples_controller_test.rb \
        app/views/samples/
git commit -m "Add SamplesController with index and category actions"
```

---

## Phase 3: Samples Page UI

### Task 6: Build Samples Index Page with Category Cards

**Files:**
- Modify: `app/views/samples/index.html.erb`
- Create: `app/views/samples/_category_card.html.erb`

**Step 1: Update samples index page**

Replace `app/views/samples/index.html.erb`:

```erb
<% content_for :title, "Free Samples | Afida" %>
<% content_for :meta_description, "Request free samples of our eco-friendly catering supplies. Choose up to 5 product samples - just pay £7.50 shipping." %>

<div class="container mx-auto px-4 py-8">
  <!-- Hero Section -->
  <div class="text-center mb-12">
    <h1 class="text-4xl font-bold mb-4">Try Before You Buy</h1>
    <p class="text-xl text-gray-600 mb-2">
      Select up to <strong>5 free samples</strong> of our eco-friendly products
    </p>
    <p class="text-gray-500">
      Just pay £7.50 shipping — or <strong>free</strong> with any order
    </p>
  </div>

  <!-- Sample Counter (sticky) -->
  <div id="sample_counter"
       class="sticky top-16 z-40 bg-base-100 border-b py-3 mb-8 hidden"
       data-controller="sample-counter"
       data-sample-counter-limit-value="<%= Cart::SAMPLE_LIMIT %>">
    <div class="container mx-auto px-4 flex justify-between items-center">
      <span class="font-medium">
        <span data-sample-counter-target="count">0</span> of <%= Cart::SAMPLE_LIMIT %> samples selected
      </span>
      <%= link_to "View Cart", cart_path, class: "btn btn-primary btn-sm" %>
    </div>
  </div>

  <!-- Category Cards Grid -->
  <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6 mb-8">
    <% @categories.each do |category| %>
      <%= render "samples/category_card", category: category %>
    <% end %>
  </div>

  <% if @categories.empty? %>
    <div class="text-center py-12 text-gray-500">
      <p>No samples available at the moment. Check back soon!</p>
    </div>
  <% end %>
</div>
```

**Step 2: Create category card partial**

Create `app/views/samples/_category_card.html.erb`:

```erb
<div class="card bg-base-100 shadow-lg hover:shadow-xl transition-shadow"
     data-controller="category-expand"
     data-category-expand-url-value="<%= category_samples_path(category.slug) %>">

  <figure class="px-4 pt-4">
    <% if category.image.attached? %>
      <%= image_tag category.image, class: "rounded-xl h-32 w-full object-cover", alt: category.name %>
    <% else %>
      <div class="rounded-xl h-32 w-full bg-gray-200 flex items-center justify-center">
        <span class="text-gray-400">No image</span>
      </div>
    <% end %>
  </figure>

  <div class="card-body p-4">
    <h2 class="card-title justify-center">
      <%= category.name %>
      <svg data-category-expand-target="chevron"
           class="w-5 h-5 transition-transform"
           fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
      </svg>
    </h2>

    <button class="btn btn-ghost btn-sm"
            data-action="click->category-expand#toggle">
      View Samples
    </button>
  </div>

  <!-- Expanded variants (Turbo Frame) -->
  <%= turbo_frame_tag "category_#{category.id}",
                      class: "col-span-full",
                      data: { category_expand_target: "frame" } do %>
  <% end %>
</div>
```

**Step 3: Commit**

```bash
git add app/views/samples/
git commit -m "Build samples index page with category cards"
```

---

### Task 7: Create Category Expand Stimulus Controller

**Files:**
- Create: `app/frontend/javascript/controllers/category_expand_controller.js`

**Step 1: Create the controller**

Create `app/frontend/javascript/controllers/category_expand_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame", "chevron"]
  static values = { url: String, expanded: Boolean }

  connect() {
    this.expandedValue = false
  }

  toggle() {
    if (this.expandedValue) {
      this.collapse()
    } else {
      this.expand()
    }
  }

  expand() {
    // Load content via Turbo Frame
    this.frameTarget.src = this.urlValue
    this.expandedValue = true
    this.chevronTarget.classList.add("rotate-180")
    this.frameTarget.classList.remove("hidden")
  }

  collapse() {
    this.expandedValue = false
    this.chevronTarget.classList.remove("rotate-180")
    this.frameTarget.classList.add("hidden")
  }
}
```

**Step 2: Register controller (if not auto-loaded)**

Check `app/frontend/javascript/controllers/index.js` uses eagerLoadControllersFrom or add:

```javascript
import CategoryExpandController from "./category_expand_controller"
application.register("category-expand", CategoryExpandController)
```

**Step 3: Commit**

```bash
git add app/frontend/javascript/controllers/category_expand_controller.js
git commit -m "Add category-expand Stimulus controller for samples page"
```

---

### Task 8: Build Category Variants Grid with Add-to-Cart

**Files:**
- Modify: `app/views/samples/_category_variants.html.erb`
- Create: `app/views/samples/_variant_card.html.erb`

**Step 1: Update category variants partial**

Replace `app/views/samples/_category_variants.html.erb`:

```erb
<%= turbo_frame_tag "category_#{category.id}" do %>
  <div class="bg-base-200 rounded-lg p-4 mt-2">
    <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
      <% variants.each do |variant| %>
        <%= render "samples/variant_card", variant: variant %>
      <% end %>
    </div>

    <% if variants.empty? %>
      <p class="text-center text-gray-500 py-4">No samples available in this category.</p>
    <% end %>
  </div>
<% end %>
```

**Step 2: Create variant card partial**

Create `app/views/samples/_variant_card.html.erb`:

```erb
<%
  in_cart = Current.cart&.cart_items&.joins(:product_variant)
                   &.exists?(product_variants: { id: variant.id, sample_eligible: true })
  at_limit = Current.cart&.at_sample_limit? && !in_cart
%>

<%= turbo_frame_tag dom_id(variant, :sample) do %>
  <div class="card bg-base-100 shadow hover:shadow-md transition-shadow">
    <figure class="px-3 pt-3">
      <% if variant.product.product_photo.attached? %>
        <%= image_tag variant.product.product_photo,
                      class: "rounded-lg h-24 w-full object-cover",
                      alt: variant.product.name %>
      <% else %>
        <div class="rounded-lg h-24 w-full bg-gray-100 flex items-center justify-center">
          <span class="text-gray-400 text-xs">No image</span>
        </div>
      <% end %>
    </figure>

    <div class="card-body p-3">
      <h3 class="font-medium text-sm line-clamp-2"><%= variant.product.name %></h3>
      <p class="text-xs text-gray-500"><%= variant.name %></p>

      <div class="card-actions mt-2">
        <% if in_cart %>
          <%= button_to cart_cart_item_path(Current.cart.cart_items.find_by(product_variant: variant)),
                        method: :delete,
                        class: "btn btn-success btn-sm w-full",
                        data: { turbo_frame: dom_id(variant, :sample) } do %>
            <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
            Added
          <% end %>
        <% elsif at_limit %>
          <button class="btn btn-disabled btn-sm w-full" disabled>
            Limit Reached
          </button>
        <% else %>
          <%= button_to cart_cart_items_path,
                        class: "btn btn-outline btn-primary btn-sm w-full",
                        data: { turbo_frame: dom_id(variant, :sample) },
                        params: {
                          product_variant_id: variant.id,
                          sample: true
                        } do %>
            Add Sample
          <% end %>
        <% end %>
      </div>
    </div>
  </div>
<% end %>
```

**Step 3: Commit**

```bash
git add app/views/samples/
git commit -m "Build variant cards with add/remove sample buttons"
```

---

## Phase 4: Cart Items Controller for Samples

### Task 9: Handle Sample Additions in CartItemsController

**Files:**
- Modify: `app/controllers/cart_items_controller.rb`
- Test: `test/controllers/cart_items_controller_test.rb`

**Step 1: Write failing tests**

Add to `test/controllers/cart_items_controller_test.rb`:

```ruby
class CartItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @sample_variant = product_variants(:one)
    @sample_variant.update!(sample_eligible: true, price: 0)
  end

  test "can add sample to cart" do
    post cart_cart_items_path, params: {
      product_variant_id: @sample_variant.id,
      sample: true
    }

    assert_response :redirect
    assert Current.cart.cart_items.exists?(product_variant: @sample_variant)
  end

  test "sample is added with zero price" do
    post cart_cart_items_path, params: {
      product_variant_id: @sample_variant.id,
      sample: true
    }

    cart_item = Current.cart.cart_items.find_by(product_variant: @sample_variant)
    assert_equal 0, cart_item.price
  end

  test "cannot add more than 5 samples" do
    # Add 5 samples
    5.times do |i|
      variant = ProductVariant.create!(
        product: products(:one),
        sku: "SAMPLE-LIMIT-#{i}",
        price: 0,
        sample_eligible: true,
        active: true
      )
      post cart_cart_items_path, params: { product_variant_id: variant.id, sample: true }
    end

    # Try to add 6th
    sixth_variant = ProductVariant.create!(
      product: products(:one),
      sku: "SAMPLE-LIMIT-6",
      price: 0,
      sample_eligible: true,
      active: true
    )

    post cart_cart_items_path, params: { product_variant_id: sixth_variant.id, sample: true }

    assert_not Current.cart.cart_items.exists?(product_variant: sixth_variant)
  end

  test "cannot add same sample twice" do
    post cart_cart_items_path, params: { product_variant_id: @sample_variant.id, sample: true }
    post cart_cart_items_path, params: { product_variant_id: @sample_variant.id, sample: true }

    assert_equal 1, Current.cart.cart_items.where(product_variant: @sample_variant).count
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `rails test test/controllers/cart_items_controller_test.rb`
Expected: Failures for sample-specific tests

**Step 3: Update CartItemsController**

Add sample handling to `app/controllers/cart_items_controller.rb`:

In the `create` action, add a branch for samples:

```ruby
def create
  @cart = Current.cart

  if params[:sample].present?
    create_sample_cart_item
  elsif params[:configuration].present?
    create_configured_cart_item
  else
    create_standard_cart_item
  end
end

private

def create_sample_cart_item
  product_variant = ProductVariant.find(params[:product_variant_id])

  unless product_variant.sample_eligible?
    return redirect_to samples_path, alert: "This product is not available as a sample."
  end

  if @cart.at_sample_limit?
    return redirect_to samples_path, notice: "You've reached the maximum of #{Cart::SAMPLE_LIMIT} samples."
  end

  # Check if already in cart
  if @cart.cart_items.exists?(product_variant: product_variant)
    return redirect_to samples_path, notice: "This sample is already in your cart."
  end

  @cart_item = @cart.cart_items.build(
    product_variant: product_variant,
    quantity: 1,
    price: 0
  )

  if @cart_item.save
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(dom_id(product_variant, :sample),
                               partial: "samples/variant_card",
                               locals: { variant: product_variant }),
          turbo_stream.replace("cart_counter", partial: "shared/cart_counter"),
          turbo_stream.replace("sample_counter", partial: "samples/sample_counter")
        ]
      end
      format.html { redirect_to samples_path, notice: "Sample added to cart." }
    end
  else
    redirect_to samples_path, alert: "Could not add sample."
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `rails test test/controllers/cart_items_controller_test.rb`
Expected: All tests pass

**Step 5: Commit**

```bash
git add app/controllers/cart_items_controller.rb test/controllers/cart_items_controller_test.rb
git commit -m "Add sample handling to CartItemsController with limit enforcement"
```

---

### Task 10: Create Sample Counter Partial and Controller

**Files:**
- Create: `app/views/samples/_sample_counter.html.erb`
- Create: `app/frontend/javascript/controllers/sample_counter_controller.js`

**Step 1: Create sample counter partial**

Create `app/views/samples/_sample_counter.html.erb`:

```erb
<% sample_count = Current.cart&.sample_count || 0 %>

<div id="sample_counter"
     class="sticky top-16 z-40 bg-base-100 border-b py-3 mb-8 <%= 'hidden' if sample_count == 0 %>"
     data-controller="sample-counter"
     data-sample-counter-count-value="<%= sample_count %>"
     data-sample-counter-limit-value="<%= Cart::SAMPLE_LIMIT %>">
  <div class="container mx-auto px-4 flex justify-between items-center">
    <span class="font-medium">
      <span data-sample-counter-target="count"><%= sample_count %></span>
      of <%= Cart::SAMPLE_LIMIT %> samples selected
    </span>
    <%= link_to "View Cart", cart_path, class: "btn btn-primary btn-sm" %>
  </div>
</div>
```

**Step 2: Create sample counter Stimulus controller**

Create `app/frontend/javascript/controllers/sample_counter_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count"]
  static values = { count: Number, limit: Number }

  connect() {
    this.updateVisibility()
  }

  countValueChanged() {
    this.updateVisibility()
  }

  updateVisibility() {
    if (this.countValue > 0) {
      this.element.classList.remove("hidden")
    } else {
      this.element.classList.add("hidden")
    }
  }
}
```

**Step 3: Commit**

```bash
git add app/views/samples/_sample_counter.html.erb \
        app/frontend/javascript/controllers/sample_counter_controller.js
git commit -m "Add sample counter partial and Stimulus controller"
```

---

## Phase 5: Cart Display Updates

### Task 11: Display Samples as "Free" in Cart

**Files:**
- Modify: `app/views/cart_items/_cart_item.html.erb`
- Test: `test/system/sample_cart_display_test.rb`

**Step 1: Write failing system test**

Create `test/system/sample_cart_display_test.rb`:

```ruby
require "application_system_test_case"

class SampleCartDisplayTest < ApplicationSystemTestCase
  setup do
    @sample_variant = product_variants(:one)
    @sample_variant.update!(sample_eligible: true, price: 0)
  end

  test "samples display as Free in cart" do
    visit samples_path

    # Would need sample-eligible products set up
    # For now, add directly via controller test or factory

    visit cart_path
    assert_text "Free"
    assert_text "(Sample)"
  end
end
```

**Step 2: Update cart item partial**

Modify `app/views/cart_items/_cart_item.html.erb` to handle samples:

Find the price display section and update:

```erb
<% if cart_item.price == 0 && cart_item.product_variant.sample_eligible? %>
  <span class="text-success font-semibold">Free</span>
<% else %>
  <%= format_price_display(cart_item) %>
<% end %>
```

Find the product name display and update:

```erb
<%= cart_item.product_variant.product.name %>
<% if cart_item.product_variant.sample_eligible? && cart_item.price == 0 %>
  <span class="text-sm text-gray-500">(Sample)</span>
<% end %>
```

Remove quantity controls for samples:

```erb
<% unless cart_item.product_variant.sample_eligible? && cart_item.price == 0 %>
  <!-- Quantity controls here -->
<% end %>
```

**Step 3: Commit**

```bash
git add app/views/cart_items/_cart_item.html.erb test/system/sample_cart_display_test.rb
git commit -m "Display samples as Free with (Sample) label in cart"
```

---

## Phase 6: Checkout Shipping Logic

### Task 12: Implement Flat Shipping for Samples-Only Orders

**Files:**
- Modify: `app/controllers/checkouts_controller.rb`
- Test: `test/controllers/checkouts_controller_test.rb`

**Step 1: Write failing tests**

Add to `test/controllers/checkouts_controller_test.rb`:

```ruby
class CheckoutsControllerTest < ActionDispatch::IntegrationTest
  test "samples-only cart gets flat £7.50 shipping" do
    sample_variant = product_variants(:one)
    sample_variant.update!(sample_eligible: true, price: 0)

    # Add sample to cart
    post cart_cart_items_path, params: { product_variant_id: sample_variant.id, sample: true }

    # Mock Stripe and check shipping amount
    # This will depend on your Stripe integration structure
  end

  test "mixed cart uses normal shipping calculation" do
    # Add sample
    sample_variant = product_variants(:one)
    sample_variant.update!(sample_eligible: true, price: 0)
    post cart_cart_items_path, params: { product_variant_id: sample_variant.id, sample: true }

    # Add regular product
    regular_variant = product_variants(:two)
    post cart_cart_items_path, params: { cart_item: { variant_sku: regular_variant.sku, quantity: 1 } }

    # Verify normal shipping applies
  end
end
```

**Step 2: Update CheckoutsController**

Add constant and modify shipping logic in `app/controllers/checkouts_controller.rb`:

```ruby
class CheckoutsController < ApplicationController
  SAMPLE_ONLY_SHIPPING_AMOUNT = 750  # £7.50 in pence

  def create
    # ... existing setup ...

    shipping_options = if Current.cart.only_samples?
      [sample_only_shipping_option]
    else
      standard_shipping_options
    end

    # ... rest of Stripe session creation using shipping_options ...
  end

  private

  def sample_only_shipping_option
    {
      shipping_rate_data: {
        type: "fixed_amount",
        fixed_amount: {
          amount: SAMPLE_ONLY_SHIPPING_AMOUNT,
          currency: "gbp"
        },
        display_name: "Sample Delivery",
        delivery_estimate: {
          minimum: { unit: "business_day", value: 3 },
          maximum: { unit: "business_day", value: 5 }
        }
      }
    }
  end

  def standard_shipping_options
    # ... existing shipping options ...
  end
end
```

**Step 3: Commit**

```bash
git add app/controllers/checkouts_controller.rb test/controllers/checkouts_controller_test.rb
git commit -m "Add £7.50 flat shipping for samples-only orders"
```

---

## Phase 7: Admin UI

### Task 13: Add Sample Eligibility to Variant Admin Form

**Files:**
- Modify: `app/views/admin/product_variants/_form.html.erb`

**Step 1: Add sample fields to variant form**

Add to `app/views/admin/product_variants/_form.html.erb`:

```erb
<div class="divider">Sample Settings</div>

<div class="form-control">
  <label class="label cursor-pointer justify-start gap-4">
    <%= form.check_box :sample_eligible, class: "checkbox checkbox-primary" %>
    <span class="label-text">Available as free sample</span>
  </label>
</div>

<div class="form-control">
  <%= form.label :sample_sku, "Sample SKU", class: "label" %>
  <%= form.text_field :sample_sku,
                      class: "input input-bordered",
                      placeholder: "Auto-generates as SAMPLE-{SKU} if blank" %>
  <label class="label">
    <span class="label-text-alt">Used in orders to identify sample items</span>
  </label>
</div>
```

**Step 2: Permit params in controller**

Update `app/controllers/admin/product_variants_controller.rb`:

```ruby
def product_variant_params
  params.require(:product_variant).permit(
    # ... existing params ...
    :sample_eligible,
    :sample_sku
  )
end
```

**Step 3: Commit**

```bash
git add app/views/admin/product_variants/_form.html.erb \
        app/controllers/admin/product_variants_controller.rb
git commit -m "Add sample eligibility fields to variant admin form"
```

---

### Task 14: Add Sample Badges to Admin Order Views

**Files:**
- Modify: `app/views/admin/orders/index.html.erb`
- Modify: `app/views/admin/orders/show.html.erb`

**Step 1: Update order index with sample badges**

In `app/views/admin/orders/index.html.erb`, add badge column:

```erb
<td>
  <% if order.sample_request? %>
    <span class="badge badge-info gap-1">
      <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
        <path d="M10 2a8 8 0 100 16 8 8 0 000-16zm0 14a6 6 0 110-12 6 6 0 010 12z"/>
      </svg>
      Samples Only
    </span>
  <% elsif order.contains_samples? %>
    <span class="badge badge-warning gap-1">
      <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
        <path d="M10 2a8 8 0 100 16 8 8 0 000-16zm0 14a6 6 0 110-12 6 6 0 010 12z"/>
      </svg>
      Contains Samples
    </span>
  <% end %>
</td>
```

**Step 2: Update order show with sample indicators**

In `app/views/admin/orders/show.html.erb`:

```erb
<% if @order.sample_request? %>
  <div class="alert alert-info mb-4">
    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
      <path d="M10 2a8 8 0 100 16 8 8 0 000-16z"/>
    </svg>
    <span>This is a <strong>Sample Request</strong> order</span>
  </div>
<% elsif @order.contains_samples? %>
  <div class="alert alert-warning mb-4">
    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
      <path d="M10 2a8 8 0 100 16 8 8 0 000-16z"/>
    </svg>
    <span>This order <strong>contains samples</strong></span>
  </div>
<% end %>
```

In order items table, mark sample items:

```erb
<% @order.order_items.each do |item| %>
  <tr>
    <td>
      <%= item.product_variant.product.name %>
      <% if item.product_variant.sample_eligible? && item.price == 0 %>
        <span class="badge badge-sm badge-info ml-2">Sample</span>
        <br>
        <span class="text-xs text-gray-500">
          SKU: <%= item.product_variant.effective_sample_sku %>
        </span>
      <% end %>
    </td>
    <!-- ... rest of columns ... -->
  </tr>
<% end %>
```

**Step 3: Commit**

```bash
git add app/views/admin/orders/
git commit -m "Add sample badges and indicators to admin order views"
```

---

### Task 15: Add Sample Filter to Admin Orders Index

**Files:**
- Modify: `app/controllers/admin/orders_controller.rb`
- Modify: `app/views/admin/orders/index.html.erb`

**Step 1: Add filter logic to controller**

Update `app/controllers/admin/orders_controller.rb`:

```ruby
def index
  @orders = Order.order(created_at: :desc)

  case params[:filter]
  when "samples_only"
    @orders = @orders.with_samples.select { |o| o.sample_request? }
  when "contains_samples"
    @orders = @orders.with_samples
  when "standard"
    @orders = @orders.where.not(id: Order.with_samples.select(:id))
  end

  @pagy, @orders = pagy(@orders)
end
```

**Step 2: Add filter UI**

Add to `app/views/admin/orders/index.html.erb`:

```erb
<div class="flex gap-2 mb-4">
  <%= link_to "All", admin_orders_path,
              class: "btn btn-sm #{params[:filter].blank? ? 'btn-primary' : 'btn-ghost'}" %>
  <%= link_to "Contains Samples", admin_orders_path(filter: "contains_samples"),
              class: "btn btn-sm #{params[:filter] == 'contains_samples' ? 'btn-primary' : 'btn-ghost'}" %>
  <%= link_to "Samples Only", admin_orders_path(filter: "samples_only"),
              class: "btn btn-sm #{params[:filter] == 'samples_only' ? 'btn-primary' : 'btn-ghost'}" %>
  <%= link_to "Standard", admin_orders_path(filter: "standard"),
              class: "btn btn-sm #{params[:filter] == 'standard' ? 'btn-primary' : 'btn-ghost'}" %>
</div>
```

**Step 3: Commit**

```bash
git add app/controllers/admin/orders_controller.rb app/views/admin/orders/index.html.erb
git commit -m "Add sample order filters to admin orders index"
```

---

## Phase 8: System Tests

### Task 16: Write End-to-End Sample Request Tests

**Files:**
- Create: `test/system/sample_request_flow_test.rb`

**Step 1: Create comprehensive system test**

Create `test/system/sample_request_flow_test.rb`:

```ruby
require "application_system_test_case"

class SampleRequestFlowTest < ApplicationSystemTestCase
  setup do
    @category = categories(:one)

    # Create sample-eligible variants
    @sample_variant1 = product_variants(:one)
    @sample_variant1.update!(sample_eligible: true, price: 0)
    @sample_variant1.product.update!(category: @category, active: true)

    @sample_variant2 = product_variants(:two)
    @sample_variant2.update!(sample_eligible: true, price: 0)
    @sample_variant2.product.update!(category: @category, active: true)
  end

  test "visitor can browse and add samples to cart" do
    visit samples_path

    assert_text "Try Before You Buy"
    assert_text @category.name

    # Expand category
    click_button "View Samples"

    # Add first sample
    within("##{dom_id(@sample_variant1, :sample)}") do
      click_button "Add Sample"
    end

    assert_text "1 of 5 samples selected"

    # Verify in cart
    visit cart_path
    assert_text @sample_variant1.product.name
    assert_text "Free"
    assert_text "(Sample)"
  end

  test "visitor cannot add more than 5 samples" do
    # Create 5 sample variants and add them
    5.times do |i|
      variant = ProductVariant.create!(
        product: products(:one),
        sku: "LIMIT-TEST-#{i}",
        price: 0,
        sample_eligible: true,
        active: true
      )

      visit samples_path
      # Add sample via direct post for speed
      page.driver.post cart_cart_items_path,
                       params: { product_variant_id: variant.id, sample: true }
    end

    visit samples_path
    assert_text "5 of 5 samples selected"

    # Try to add another - should see limit message
    click_button "View Samples"
    assert_text "Limit Reached"
  end

  test "samples-only checkout shows £7.50 shipping" do
    visit samples_path
    click_button "View Samples"

    within("##{dom_id(@sample_variant1, :sample)}") do
      click_button "Add Sample"
    end

    visit cart_path

    assert_text "£7.50"  # Shipping amount
  end

  test "mixed cart shows normal shipping" do
    # Add sample
    visit samples_path
    click_button "View Samples"
    within("##{dom_id(@sample_variant1, :sample)}") do
      click_button "Add Sample"
    end

    # Add regular product
    regular_variant = product_variants(:two)
    regular_variant.update!(sample_eligible: false, price: 10)

    visit product_path(regular_variant.product)
    click_button "Add to cart"

    visit cart_path

    # Should have both items
    assert_text "Free"  # Sample
    assert_text regular_variant.price.to_s  # Regular product
  end
end
```

**Step 2: Run system tests**

Run: `rails test:system`
Expected: All tests pass

**Step 3: Commit**

```bash
git add test/system/sample_request_flow_test.rb
git commit -m "Add end-to-end system tests for sample request flow"
```

---

## Phase 9: Final Polish

### Task 17: Update Samples Route in Navigation (if applicable)

**Files:**
- Check: `app/views/layouts/_navbar.html.erb` or similar

**Step 1: Add samples link to navigation**

If there's a navigation partial, add:

```erb
<%= link_to "Free Samples", samples_path, class: "..." %>
```

**Step 2: Commit**

```bash
git add app/views/layouts/
git commit -m "Add Free Samples link to navigation"
```

---

### Task 18: Run Full Test Suite and Fix Issues

**Step 1: Run all tests**

Run: `rails test && rails test:system`

**Step 2: Fix any failures**

Address any test failures that arise.

**Step 3: Run linter**

Run: `rubocop -A`

**Step 4: Final commit**

```bash
git add -A
git commit -m "Fix test failures and linting issues"
```

---

### Task 19: Push Branch and Create PR

**Step 1: Push to origin**

Run: `git push origin 011-variant-samples`

**Step 2: Create pull request**

```bash
gh pr create --title "Implement variant-level sample request system" --body "$(cat <<'EOF'
## Summary
- Visitors can select up to 5 specific product variants as free samples
- Category-based navigation with inline expansion on /samples page
- Samples added to cart as £0 line items
- Mixed cart support (samples + paid products)
- Shipping: £7.50 flat for samples-only, free with paid orders
- Admin UI: sample eligibility on variants, order badges and filters

## Test Plan
- [ ] Visit /samples and browse categories
- [ ] Add samples to cart (verify limit of 5)
- [ ] Checkout with samples only (verify £7.50 shipping)
- [ ] Checkout with mixed cart (verify samples ship free)
- [ ] Admin: mark variants as sample-eligible
- [ ] Admin: view orders with sample badges/filters

Closes #XXX

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Summary

**Total Tasks:** 19
**Estimated Complexity:** Medium-High
**Key Dependencies:** Existing cart/checkout infrastructure, Stripe integration

**Phases:**
1. Database & Model Foundation (Tasks 1-4)
2. Samples Controller & Routes (Task 5)
3. Samples Page UI (Tasks 6-8)
4. Cart Items Controller (Tasks 9-10)
5. Cart Display Updates (Task 11)
6. Checkout Shipping Logic (Task 12)
7. Admin UI (Tasks 13-15)
8. System Tests (Task 16)
9. Final Polish (Tasks 17-19)
