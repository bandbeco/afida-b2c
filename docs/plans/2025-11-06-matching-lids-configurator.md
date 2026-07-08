---
type: Plan
description: Implementation plan for a relational compatible-lids join table and a configurator step offering matching lid selection for branded cups.
status: shipped
timestamp: 2025-11-07
---

# Matching Lids Configurator Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add optional matching lid selection (step 4) to the branded product configurator with card-based UI, allowing customers to easily add compatible lids to their cup orders.

**Architecture:** Many-to-many relationship between cup products and compatible lid products via join table with default/priority fields. Admin manages compatibility on product edit page. Step 4 shows visual cards for 2-3 compatible lids with pre-selection, auto-matched quantities, and out-of-stock handling.

**Tech Stack:** Rails 8, PostgreSQL, Hotwire Stimulus, TailwindCSS 4, DaisyUI

---

## Task 1: Database Schema - Compatible Lids Join Table

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_create_product_compatible_lids.rb`
- Modify: `db/schema.rb` (auto-updated by migration)

**Step 1: Generate migration**

```bash
rails generate migration CreateProductCompatibleLids
```

Expected: Migration file created in `db/migrate/`

**Step 2: Write migration code**

Edit the generated migration file:

```ruby
class CreateProductCompatibleLids < ActiveRecord::Migration[8.0]
  def change
    create_table :product_compatible_lids do |t|
      t.references :product, null: false, foreign_key: true
      t.references :compatible_lid, null: false, foreign_key: { to_table: :products }
      t.boolean :default, default: false, null: false
      t.integer :sort_order, default: 0, null: false

      t.timestamps
    end

    add_index :product_compatible_lids, [:product_id, :compatible_lid_id],
              unique: true,
              name: 'index_product_compatible_lids_on_product_and_lid'
    add_index :product_compatible_lids, [:product_id, :sort_order]
  end
end
```

**Step 3: Run migration**

```bash
rails db:migrate
```

Expected: Migration runs successfully, schema.rb updated

**Step 4: Verify schema**

```bash
rails db:migrate:status
```

Expected: New migration shows as "up"

**Step 5: Commit**

```bash
git add db/migrate db/schema.rb
git commit -m "feat: add product_compatible_lids join table

- Many-to-many relationship for cup-lid compatibility
- Supports default selection and custom sort order
- Unique index prevents duplicate pairings"
```

---

## Task 2: Model - ProductCompatibleLid

**Files:**
- Create: `app/models/product_compatible_lid.rb`
- Create: `test/models/product_compatible_lid_test.rb`

**Step 1: Write failing model tests**

Create `test/models/product_compatible_lid_test.rb`:

```ruby
require "test_helper"

class ProductCompatibleLidTest < ActiveSupport::TestCase
  test "belongs to product" do
    compatibility = product_compatible_lids(:one)
    assert_instance_of Product, compatibility.product
  end

  test "belongs to compatible_lid (Product)" do
    compatibility = product_compatible_lids(:one)
    assert_instance_of Product, compatibility.compatible_lid
  end

  test "validates uniqueness of product and compatible_lid combination" do
    existing = product_compatible_lids(:one)
    duplicate = ProductCompatibleLid.new(
      product: existing.product,
      compatible_lid: existing.compatible_lid
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:compatible_lid_id], "has already been taken"
  end

  test "orders by sort_order by default" do
    # Assumes fixtures have different sort_orders
    compatibilities = ProductCompatibleLid.all
    assert_equal compatibilities, compatibilities.sort_by(&:sort_order)
  end

  test "only one default per product" do
    product = products(:branded_cup_8oz)

    # Create first default
    first = ProductCompatibleLid.create!(
      product: product,
      compatible_lid: products(:flat_lid_8oz),
      default: true,
      sort_order: 1
    )

    # Create second default - should unset first
    second = ProductCompatibleLid.create!(
      product: product,
      compatible_lid: products(:domed_lid_8oz),
      default: true,
      sort_order: 2
    )

    first.reload
    assert_not first.default, "First should no longer be default"
    assert second.default, "Second should be default"
  end
end
```

**Step 2: Create fixtures**

Create entries in `test/fixtures/product_compatible_lids.yml`:

```yaml
one:
  product: branded_cup_8oz
  compatible_lid: flat_lid_8oz
  default: true
  sort_order: 1

two:
  product: branded_cup_8oz
  compatible_lid: domed_lid_8oz
  default: false
  sort_order: 2
```

**Step 3: Run tests to verify they fail**

```bash
rails test test/models/product_compatible_lid_test.rb
```

Expected: FAIL - "uninitialized constant ProductCompatibleLid"

**Step 4: Create model with basic associations**

Create `app/models/product_compatible_lid.rb`:

```ruby
class ProductCompatibleLid < ApplicationRecord
  belongs_to :product
  belongs_to :compatible_lid, class_name: "Product"

  validates :compatible_lid_id, uniqueness: { scope: :product_id }

  default_scope { order(:sort_order) }

  before_save :ensure_single_default, if: :default?

  private

  def ensure_single_default
    ProductCompatibleLid
      .where(product_id: product_id, default: true)
      .where.not(id: id)
      .update_all(default: false)
  end
end
```

**Step 5: Run tests to verify they pass**

```bash
rails test test/models/product_compatible_lid_test.rb
```

Expected: PASS - All tests green

**Step 6: Commit**

```bash
git add app/models/product_compatible_lid.rb test/models/product_compatible_lid_test.rb test/fixtures/product_compatible_lids.yml
git commit -m "feat: add ProductCompatibleLid model

- Associations to product and compatible_lid
- Uniqueness validation on product+lid combo
- Auto-unset other defaults when setting new default
- Orders by sort_order"
```

---

## Task 3: Product Model - Compatible Lids Associations

**Files:**
- Modify: `app/models/product.rb`
- Modify: `test/models/product_test.rb`

**Step 1: Write failing tests**

Add to `test/models/product_test.rb`:

```ruby
test "has many compatible_lids associations" do
  product = products(:branded_cup_8oz)
  assert_respond_to product, :product_compatible_lids
  assert_respond_to product, :compatible_lids
end

test "compatible_lids returns products ordered by sort_order" do
  product = products(:branded_cup_8oz)
  lids = product.compatible_lids

  assert_includes lids, products(:flat_lid_8oz)
  assert_includes lids, products(:domed_lid_8oz)

  # Verify order matches sort_order from join table
  assert_equal products(:flat_lid_8oz), lids.first
  assert_equal products(:domed_lid_8oz), lids.second
end

test "default_compatible_lid returns the default lid" do
  product = products(:branded_cup_8oz)
  default_lid = product.default_compatible_lid

  assert_equal products(:flat_lid_8oz), default_lid
end

test "default_compatible_lid returns nil when no default set" do
  product = products(:branded_cup_12oz)
  assert_nil product.default_compatible_lid
end

test "has_compatible_lids? returns true when lids exist" do
  product = products(:branded_cup_8oz)
  assert product.has_compatible_lids?
end

test "has_compatible_lids? returns false when no lids exist" do
  product = products(:branded_cup_12oz)
  assert_not product.has_compatible_lids?
end
```

**Step 2: Run tests to verify they fail**

```bash
rails test test/models/product_test.rb
```

Expected: FAIL - undefined method errors

**Step 3: Add associations and methods to Product**

Add to `app/models/product.rb`:

```ruby
# In Product model, add these associations:
has_many :product_compatible_lids, dependent: :destroy
has_many :compatible_lids,
         through: :product_compatible_lids,
         source: :compatible_lid

# Add these instance methods:
def default_compatible_lid
  product_compatible_lids.find_by(default: true)&.compatible_lid
end

def has_compatible_lids?
  compatible_lids.any?
end
```

**Step 4: Run tests to verify they pass**

```bash
rails test test/models/product_test.rb
```

Expected: PASS - All tests green

**Step 5: Commit**

```bash
git add app/models/product.rb test/models/product_test.rb
git commit -m "feat: add compatible lids associations to Product

- has_many through relationship to compatible_lids
- default_compatible_lid method returns default selection
- has_compatible_lids? convenience method"
```

---

## Task 4: Admin - Nested Form for Compatible Lids

**Files:**
- Modify: `app/views/admin/products/_form.html.erb`
- Modify: `app/controllers/admin/products_controller.rb`
- Create: `app/views/admin/products/_compatible_lid_fields.html.erb`

**Step 1: Update Product controller to accept nested attributes**

Add to `app/controllers/admin/products_controller.rb` in the `product_params` method:

```ruby
def product_params
  params.require(:product).permit(
    # ... existing params ...
    product_compatible_lids_attributes: [
      :id,
      :compatible_lid_id,
      :default,
      :sort_order,
      :_destroy
    ]
  )
end
```

**Step 2: Update Product model to accept nested attributes**

Add to `app/models/product.rb`:

```ruby
accepts_nested_attributes_for :product_compatible_lids,
                              allow_destroy: true,
                              reject_if: :all_blank
```

**Step 3: Create partial for compatible lid fields**

Create `app/views/admin/products/_compatible_lid_fields.html.erb`:

```erb
<div class="border border-base-300 rounded-lg p-4 mb-3" data-nested-form-target="item">
  <%= form.hidden_field :id %>

  <div class="flex items-start gap-3">
    <div class="form-control flex-1">
      <%= form.label :compatible_lid_id, "Lid Product", class: "label" %>
      <%= form.collection_select :compatible_lid_id,
                                 Product.where(product_type: "standard").order(:name),
                                 :id,
                                 :name,
                                 { prompt: "Select a lid product" },
                                 { class: "select select-bordered w-full" } %>
    </div>

    <div class="form-control w-24">
      <%= form.label :sort_order, "Order", class: "label" %>
      <%= form.number_field :sort_order,
                           value: form.object.sort_order || 0,
                           class: "input input-bordered w-full" %>
    </div>

    <div class="form-control">
      <%= form.label :default, class: "label cursor-pointer" %>
      <div class="flex items-center gap-2">
        <%= form.check_box :default, class: "checkbox" %>
        <span class="label-text">Default</span>
      </div>
    </div>

    <div class="form-control">
      <%= form.label :_destroy, "Remove", class: "label" %>
      <%= form.check_box :_destroy, class: "checkbox checkbox-error" %>
    </div>
  </div>
</div>
```

**Step 4: Add compatible lids section to product form**

Add to `app/views/admin/products/_form.html.erb` (after product details section):

```erb
<% if @product.persisted? && @product.product_type == "branded" %>
  <div class="card bg-base-100 shadow-sm mb-6">
    <div class="card-body">
      <h3 class="card-title">Compatible Lids (for configurator)</h3>
      <p class="text-sm text-base-content/70 mb-4">
        Add compatible lid products that will be offered in step 4 of the branded configurator.
      </p>

      <div id="compatible-lids-container">
        <%= form.fields_for :product_compatible_lids do |lid_form| %>
          <%= render "compatible_lid_fields", form: lid_form %>
        <% end %>
      </div>

      <div class="card-actions">
        <%= link_to "Add Compatible Lid",
                    "#",
                    class: "btn btn-sm btn-outline",
                    data: { action: "click->nested-form#add" } %>
      </div>
    </div>
  </div>
<% end %>
```

**Step 5: Test manually in browser**

Start server:
```bash
bin/dev
```

Navigate to admin product edit page for a branded cup product and verify:
- Compatible lids section appears
- Can add/remove compatible lids
- Can set default checkbox
- Can reorder with sort_order

**Step 6: Commit**

```bash
git add app/controllers/admin/products_controller.rb app/models/product.rb app/views/admin/products/
git commit -m "feat: add admin UI for managing compatible lids

- Nested form for product_compatible_lids on product edit
- Only shown for branded products
- Select lid product, set default, set sort order
- Remove functionality via _destroy"
```

---

## Task 5: Configurator Step 4 - UI Structure

**Files:**
- Modify: `app/views/branded_products/configure.html.erb`
- Create: `app/views/branded_products/_step4_lids.html.erb`

**Step 1: Create step 4 partial**

Create `app/views/branded_products/_step4_lids.html.erb`:

```erb
<div class="step-content" data-step="4">
  <h2 class="text-2xl font-bold mb-4">Add Matching Lids (Optional)</h2>

  <% if @compatible_lids.any? %>
    <%= form_with url: branded_product_configure_path(@product.slug),
                  method: :post,
                  data: {
                    controller: "lid-selector",
                    lid_selector_cup_quantity_value: @configuration[:quantity],
                    turbo: false
                  },
                  class: "space-y-6" do |form| %>

      <%= hidden_field_tag "step", 4 %>
      <%= hidden_field_tag "product_id", @product.id %>
      <%= hidden_field_tag "variant_id", @configuration[:variant_id] %>
      <%= hidden_field_tag "quantity", @configuration[:quantity] %>

      <!-- Lid selection cards -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4"
           data-lid-selector-target="cardsContainer">

        <% @compatible_lids.each_with_index do |lid_data, index| %>
          <% lid = lid_data[:product] %>
          <% variant = lid_data[:variant] %>
          <% is_default = lid_data[:is_default] %>
          <% in_stock = lid_data[:in_stock] %>

          <div class="card bg-base-100 border-2 transition-all cursor-pointer <%= 'border-primary' if is_default && in_stock %> <%= 'opacity-50' unless in_stock %>"
               data-lid-selector-target="card"
               data-lid-id="<%= lid.id %>"
               data-variant-id="<%= variant&.id %>"
               data-action="click->lid-selector#selectLid">

            <div class="card-body">
              <!-- Checkmark for selected -->
              <div class="absolute top-3 right-3">
                <div class="w-6 h-6 rounded-full border-2 flex items-center justify-center transition-all"
                     data-lid-selector-target="checkmark"
                     data-lid-id="<%= lid.id %>">
                  <svg class="w-4 h-4 text-primary hidden" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                  </svg>
                </div>
              </div>

              <!-- Lid image -->
              <% if lid.primary_photo.attached? %>
                <%= image_tag lid.primary_photo.variant(resize_to_limit: [200, 200]),
                             alt: lid.name,
                             class: "w-full h-32 object-contain mb-4" %>
              <% else %>
                <div class="w-full h-32 bg-base-200 flex items-center justify-center mb-4">
                  <span class="text-base-content/50">No image</span>
                </div>
              <% end %>

              <!-- Lid info -->
              <h3 class="card-title text-base"><%= lid.name %></h3>

              <% if lid.short_description.present? %>
                <p class="text-sm text-base-content/70"><%= lid.short_description %></p>
              <% end %>

              <% unless in_stock %>
                <div class="badge badge-error">Out of Stock</div>
              <% end %>

              <% if in_stock && variant %>
                <div class="mt-auto pt-4">
                  <p class="text-sm text-base-content/70">
                    <%= number_to_currency(variant.price, unit: "£") %> per pack
                  </p>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Quantity input (shown when lid selected) -->
      <div class="card bg-base-100 border border-base-300 hidden"
           data-lid-selector-target="quantitySection">
        <div class="card-body">
          <h3 class="font-semibold mb-2">Lid Quantity</h3>
          <div class="flex items-center gap-4">
            <%= number_field_tag "lid_quantity",
                                @configuration[:quantity],
                                min: 0,
                                step: 1,
                                class: "input input-bordered w-48",
                                data: {
                                  lid_selector_target: "quantityInput",
                                  action: "change->lid-selector#updatePrice"
                                } %>
            <span class="text-sm text-base-content/70">units</span>
          </div>

          <div class="mt-4" data-lid-selector-target="priceDisplay">
            <!-- Price calculation will be inserted here by Stimulus -->
          </div>
        </div>
      </div>

      <!-- Skip option -->
      <div class="form-control">
        <label class="label cursor-pointer justify-start gap-3">
          <%= check_box_tag "skip_lids",
                           "1",
                           false,
                           class: "checkbox",
                           data: {
                             lid_selector_target: "skipCheckbox",
                             action: "change->lid-selector#toggleSkip"
                           } %>
          <span class="label-text">No thanks, skip lids</span>
        </label>
      </div>

      <!-- Hidden fields for form submission -->
      <%= hidden_field_tag "lid_product_id", "", data: { lid_selector_target: "lidProductIdInput" } %>
      <%= hidden_field_tag "lid_variant_id", "", data: { lid_selector_target: "lidVariantIdInput" } %>

      <!-- Navigation buttons -->
      <div class="flex justify-between mt-8">
        <%= link_to "← Back",
                   branded_product_configure_path(@product.slug, step: 3),
                   class: "btn btn-outline" %>

        <%= button_tag "Continue to Design Upload →",
                      type: "submit",
                      class: "btn btn-primary",
                      data: { lid_selector_target: "continueButton" } %>
      </div>
    <% end %>

  <% else %>
    <!-- No compatible lids - this case shouldn't happen normally -->
    <div class="alert alert-info">
      <p>No matching lids available for this product.</p>
    </div>

    <%= link_to "Continue to Design Upload →",
               branded_product_configure_path(@product.slug, step: 5),
               class: "btn btn-primary mt-4" %>
  <% end %>
</div>
```

**Step 2: Include step 4 in main configure view**

Modify `app/views/branded_products/configure.html.erb` to include step 4:

```erb
<!-- Add after step 3 -->
<%= render "step4_lids" if @step == 4 %>
```

**Step 3: Commit**

```bash
git add app/views/branded_products/
git commit -m "feat: add step 4 lid selection UI structure

- Card-based visual selection for compatible lids
- Shows 2-3 lid options with images and descriptions
- Out of stock badge for unavailable lids
- Quantity input with auto-match to cup quantity
- Skip option checkbox
- Navigation between steps"
```

---

## Task 6: Stimulus Controller - Lid Selector

**Files:**
- Create: `app/frontend/javascript/controllers/lid_selector_controller.js`

**Step 1: Create Stimulus controller**

Create `app/frontend/javascript/controllers/lid_selector_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "card",
    "checkmark",
    "quantitySection",
    "quantityInput",
    "priceDisplay",
    "skipCheckbox",
    "continueButton",
    "lidProductIdInput",
    "lidVariantIdInput",
    "cardsContainer"
  ]

  static values = {
    cupQuantity: Number
  }

  connect() {
    // Pre-select default lid on load
    const defaultCard = this.cardTargets.find(card => {
      return card.classList.contains('border-primary')
    })

    if (defaultCard) {
      this.selectCard(defaultCard)
    }
  }

  selectLid(event) {
    const card = event.currentTarget
    const inStock = !card.classList.contains('opacity-50')

    if (!inStock) {
      return // Don't allow selection of out-of-stock items
    }

    this.selectCard(card)
    this.skipCheckboxTarget.checked = false
  }

  selectCard(card) {
    // Remove selection from all cards
    this.cardTargets.forEach(c => {
      c.classList.remove('border-primary')
      c.classList.add('border-base-300')
    })

    // Hide all checkmarks
    this.checkmarkTargets.forEach(check => {
      check.querySelector('svg').classList.add('hidden')
      check.classList.remove('bg-primary', 'border-primary')
    })

    // Select this card
    card.classList.add('border-primary')
    card.classList.remove('border-base-300')

    // Show checkmark for this card
    const lidId = card.dataset.lidId
    const checkmark = this.checkmarkTargets.find(c => c.dataset.lidId === lidId)
    if (checkmark) {
      checkmark.querySelector('svg').classList.remove('hidden')
      checkmark.classList.add('bg-primary', 'border-primary')
    }

    // Update hidden fields
    const variantId = card.dataset.variantId
    this.lidProductIdInputTarget.value = lidId
    this.lidVariantIdInputTarget.value = variantId

    // Show quantity section
    this.quantitySectionTarget.classList.remove('hidden')

    // Auto-set quantity to match cups
    this.quantityInputTarget.value = this.cupQuantityValue

    // Update price display
    this.updatePrice()

    // Enable continue button
    this.continueButtonTarget.disabled = false
  }

  toggleSkip(event) {
    if (event.target.checked) {
      // Clear selection
      this.cardTargets.forEach(card => {
        card.classList.remove('border-primary')
        card.classList.add('border-base-300')
      })

      this.checkmarkTargets.forEach(check => {
        check.querySelector('svg').classList.add('hidden')
        check.classList.remove('bg-primary', 'border-primary')
      })

      // Hide quantity section
      this.quantitySectionTarget.classList.add('hidden')

      // Clear hidden fields
      this.lidProductIdInputTarget.value = ''
      this.lidVariantIdInputTarget.value = ''

      // Enable continue button (can skip)
      this.continueButtonTarget.disabled = false
    }
  }

  updatePrice() {
    const quantity = parseInt(this.quantityInputTarget.value) || 0
    const selectedCard = this.cardTargets.find(card =>
      card.classList.contains('border-primary')
    )

    if (!selectedCard || quantity === 0) {
      this.priceDisplayTarget.innerHTML = ''
      return
    }

    const variantId = selectedCard.dataset.variantId

    // Fetch price from server
    fetch(`/branded_products/calculate_lid_price?variant_id=${variantId}&quantity=${quantity}`)
      .then(response => response.json())
      .then(data => {
        this.priceDisplayTarget.innerHTML = `
          <div class="space-y-1 text-sm">
            <div class="flex justify-between">
              <span>Price per pack:</span>
              <span class="font-semibold">${data.price_per_pack}</span>
            </div>
            <div class="flex justify-between">
              <span>Number of packs:</span>
              <span class="font-semibold">${data.packs_needed}</span>
            </div>
            <div class="divider my-1"></div>
            <div class="flex justify-between text-base font-bold">
              <span>Subtotal:</span>
              <span>${data.subtotal}</span>
            </div>
          </div>
        `
      })
      .catch(error => {
        console.error('Error fetching price:', error)
        this.priceDisplayTarget.innerHTML = '<p class="text-error">Error calculating price</p>'
      })
  }
}
```

**Step 2: Register controller in application.js**

Verify controller is auto-registered (or manually add if needed) in `app/frontend/entrypoints/application.js`.

**Step 3: Test in browser**

Start dev server and test:
- Clicking cards selects them
- Skip checkbox deselects cards
- Quantity input shows when lid selected
- Navigation works

**Step 4: Commit**

```bash
git add app/frontend/javascript/controllers/lid_selector_controller.js
git commit -m "feat: add lid selector Stimulus controller

- Card selection with visual feedback
- Auto-matched quantity to cup quantity
- Skip toggle functionality
- Price calculation via AJAX
- Form state management"
```

---

## Task 7: Controller - Step 4 Logic

**Files:**
- Modify: `app/controllers/branded_products_controller.rb`

**Step 1: Add step 4 handling to configure action**

Modify the `configure` method in `app/controllers/branded_products_controller.rb`:

```ruby
def configure
  @step = params[:step]&.to_i || 1
  @product = Product.find_by!(slug: params[:slug])

  # Load configuration from session
  @configuration = session[:branded_product_config] || {}

  case @step
  when 1
    # Size selection - existing code
    @variants = @product.active_variants.by_sort_order

  when 2
    # Quantity selection - existing code
    @selected_variant = @product.active_variants.find(@configuration[:variant_id])

  when 3
    # Review configuration - existing code
    @selected_variant = @product.active_variants.find(@configuration[:variant_id])

  when 4
    # Lid selection
    @selected_variant = @product.active_variants.find(@configuration[:variant_id])
    @compatible_lids = load_compatible_lids_for_step4

    # Skip step 4 entirely if no compatible lids
    if @compatible_lids.empty?
      redirect_to branded_product_configure_path(@product.slug, step: 5) and return
    end

  when 5
    # Design upload - existing code
    @selected_variant = @product.active_variants.find(@configuration[:variant_id])

  when 6
    # Final review - existing code
    @selected_variant = @product.active_variants.find(@configuration[:variant_id])

    # Load lid info if selected
    if @configuration[:lid_product_id].present?
      @selected_lid_product = Product.find(@configuration[:lid_product_id])
      @selected_lid_variant = ProductVariant.find(@configuration[:lid_variant_id]) if @configuration[:lid_variant_id]
    end
  end

  render :configure
end
```

**Step 2: Add method to load compatible lids**

Add to `app/controllers/branded_products_controller.rb`:

```ruby
private

def load_compatible_lids_for_step4
  @product.product_compatible_lids.includes(:compatible_lid).map do |pcl|
    lid = pcl.compatible_lid
    variant = lid.active_variants.first # Assume single variant for lids

    {
      product: lid,
      variant: variant,
      is_default: pcl.default,
      in_stock: variant&.available? || false,
      sort_order: pcl.sort_order
    }
  end.sort_by { |lid_data| lid_data[:sort_order] }
end
```

**Step 3: Add step 4 submission handling to update_configuration**

Modify the `update_configuration` method:

```ruby
def update_configuration
  step = params[:step].to_i
  config = session[:branded_product_config] || {}

  case step
  when 1
    # Size selection - existing code
    config[:variant_id] = params[:variant_id]
    session[:branded_product_config] = config
    redirect_to branded_product_configure_path(params[:slug], step: 2)

  when 2
    # Quantity selection - existing code
    config[:quantity] = params[:quantity].to_i
    session[:branded_product_config] = config
    redirect_to branded_product_configure_path(params[:slug], step: 3)

  when 3
    # Review - existing code
    session[:branded_product_config] = config
    redirect_to branded_product_configure_path(params[:slug], step: 4)

  when 4
    # Lid selection
    unless params[:skip_lids] == "1"
      config[:lid_product_id] = params[:lid_product_id]
      config[:lid_variant_id] = params[:lid_variant_id]
      config[:lid_quantity] = params[:lid_quantity].to_i
    else
      # Clear any previous lid selection
      config.delete(:lid_product_id)
      config.delete(:lid_variant_id)
      config.delete(:lid_quantity)
    end

    session[:branded_product_config] = config
    redirect_to branded_product_configure_path(params[:slug], step: 5)

  when 5
    # Design upload - existing code
    # ... existing code ...
    redirect_to branded_product_configure_path(params[:slug], step: 6)
  end
end
```

**Step 4: Handle quantity re-sync when going back**

Add logic to re-sync lid quantity when user changes cup quantity:

```ruby
# In the configure method, when @step == 4:
when 4
  @selected_variant = @product.active_variants.find(@configuration[:variant_id])
  @compatible_lids = load_compatible_lids_for_step4

  # Re-sync lid quantity to match cup quantity if user went back and changed it
  if @configuration[:lid_quantity].present?
    @configuration[:lid_quantity] = @configuration[:quantity]
    session[:branded_product_config] = @configuration
  end

  # Skip step 4 entirely if no compatible lids
  if @compatible_lids.empty?
    redirect_to branded_product_configure_path(@product.slug, step: 5) and return
  end
```

**Step 5: Test manually**

Test the flow:
- Configure cup through steps 1-3
- See step 4 with compatible lids
- Select a lid, verify quantity matches cup quantity
- Skip lids, verify config cleared
- Go back and change cup quantity, verify lid quantity re-syncs

**Step 6: Commit**

```bash
git add app/controllers/branded_products_controller.rb
git commit -m "feat: add step 4 controller logic for lid selection

- Load compatible lids with stock status
- Skip step if no compatible lids exist
- Handle lid selection or skip in session
- Re-sync lid quantity when cup quantity changes
- Clear lid config when skip is selected"
```

---

## Task 8: Price Calculation Endpoint

**Files:**
- Modify: `app/controllers/branded_products_controller.rb`
- Modify: `config/routes.rb`

**Step 1: Add route for price calculation**

Add to `config/routes.rb`:

```ruby
# Inside the branded products routes:
resources :branded_products, only: [:index, :show], param: :slug do
  member do
    get :configure
    post :configure, action: :update_configuration
    get :calculate_lid_price  # NEW
  end
end
```

**Step 2: Add calculate_lid_price action**

Add to `app/controllers/branded_products_controller.rb`:

```ruby
def calculate_lid_price
  variant = ProductVariant.find(params[:variant_id])
  quantity = params[:quantity].to_i

  price_per_pack = variant.price
  packs_needed = (quantity.to_f / variant.pac_size).ceil
  subtotal = price_per_pack * packs_needed

  render json: {
    price_per_pack: number_to_currency(price_per_pack, unit: "£"),
    packs_needed: packs_needed,
    subtotal: number_to_currency(subtotal, unit: "£"),
    raw_subtotal: subtotal
  }
rescue ActiveRecord::RecordNotFound
  render json: { error: "Variant not found" }, status: :not_found
end
```

**Step 3: Test endpoint manually**

```bash
curl "http://localhost:3000/branded_products/[slug]/calculate_lid_price?variant_id=123&quantity=1000"
```

Expected: JSON response with price data

**Step 4: Commit**

```bash
git add app/controllers/branded_products_controller.rb config/routes.rb
git commit -m "feat: add lid price calculation endpoint

- AJAX endpoint for dynamic price updates
- Calculates packs needed and subtotal
- Returns formatted currency strings"
```

---

## Task 9: Add Lids to Cart

**Files:**
- Modify: `app/controllers/branded_products_controller.rb` (or wherever cart addition happens)

**Step 1: Update cart addition logic**

Modify the action that adds configured product to cart (likely in final step):

```ruby
def add_to_cart
  config = session[:branded_product_config]

  # Add cup product to cart (existing logic)
  cup_variant = ProductVariant.find(config[:variant_id])
  Current.cart.add_item(
    variant: cup_variant,
    quantity: config[:quantity],
    customization: {
      design_file_url: config[:design_file_url],
      notes: config[:notes]
    }
  )

  # Add lid product to cart if selected
  if config[:lid_product_id].present? && config[:lid_variant_id].present?
    lid_variant = ProductVariant.find(config[:lid_variant_id])
    Current.cart.add_item(
      variant: lid_variant,
      quantity: config[:lid_quantity]
      # Note: Lids don't need customization/design
    )
  end

  # Clear configuration from session
  session.delete(:branded_product_config)

  redirect_to cart_path, notice: "Products added to cart!"
end
```

**Step 2: Test end-to-end flow**

Full test:
1. Configure cup (steps 1-3)
2. Select lid (step 4)
3. Upload design (step 5)
4. Add to cart (step 6)
5. Verify both cup and lid in cart

**Step 3: Commit**

```bash
git add app/controllers/branded_products_controller.rb
git commit -m "feat: add selected lids to cart with cups

- Adds both cup and lid to cart at checkout
- Lids are standard products (no customization)
- Clears session after successful cart addition"
```

---

## Task 10: Update Fixtures for Testing

**Files:**
- Modify: `test/fixtures/products.yml`
- Modify: `test/fixtures/product_variants.yml`
- Modify: `test/fixtures/product_compatible_lids.yml`

**Step 1: Add lid products to fixtures**

Add to `test/fixtures/products.yml`:

```yaml
flat_lid_8oz:
  name: "Flat Lid - 8oz"
  slug: "flat-lid-8oz"
  sku: "LID-FLAT-8"
  product_type: "standard"
  category: lids
  active: true
  short_description: "Standard closure for 8oz cups"
  meta_title: "Flat Lid 8oz"
  meta_description: "Standard flat lid for 8oz cups"

domed_lid_8oz:
  name: "Domed Lid - 8oz"
  slug: "domed-lid-8oz"
  sku: "LID-DOME-8"
  product_type: "standard"
  category: lids
  active: true
  short_description: "Extra room for toppings"
  meta_title: "Domed Lid 8oz"
  meta_description: "Domed lid with extra room for 8oz cups"

sip_lid_8oz:
  name: "Sip Lid - 8oz"
  slug: "sip-lid-8oz"
  sku: "LID-SIP-8"
  product_type: "standard"
  category: lids
  active: true
  short_description: "Built-in drinking spout"
  meta_title: "Sip Lid 8oz"
  meta_description: "Sip lid with built-in spout for 8oz cups"
```

**Step 2: Add lid variants to fixtures**

Add to `test/fixtures/product_variants.yml`:

```yaml
flat_lid_8oz_variant:
  product: flat_lid_8oz
  name: "Standard Pack"
  sku: "LID-FLAT-8-1000"
  pac_size: 1000
  price: 15.00
  stock: 500
  active: true

domed_lid_8oz_variant:
  product: domed_lid_8oz
  name: "Standard Pack"
  sku: "LID-DOME-8-1000"
  pac_size: 1000
  price: 18.00
  stock: 500
  active: true

sip_lid_8oz_variant:
  product: sip_lid_8oz
  name: "Standard Pack"
  sku: "LID-SIP-8-1000"
  pac_size: 1000
  price: 20.00
  stock: 0  # Out of stock for testing
  active: true
```

**Step 3: Update compatible lids fixtures**

Update `test/fixtures/product_compatible_lids.yml`:

```yaml
one:
  product: branded_cup_8oz
  compatible_lid: flat_lid_8oz
  default: true
  sort_order: 1

two:
  product: branded_cup_8oz
  compatible_lid: domed_lid_8oz
  default: false
  sort_order: 2

three:
  product: branded_cup_8oz
  compatible_lid: sip_lid_8oz
  default: false
  sort_order: 3
```

**Step 4: Run tests to verify fixtures load**

```bash
rails test
```

Expected: All tests pass with new fixtures

**Step 5: Commit**

```bash
git add test/fixtures/
git commit -m "test: add lid product fixtures for testing

- Three lid products (flat, domed, sip)
- Variants with different prices and stock levels
- Compatible lid relationships for branded cup"
```

---

## Task 11: Integration Test - Step 4 Flow

**Files:**
- Create: `test/integration/branded_product_lid_selection_test.rb`

**Step 1: Write integration test**

Create `test/integration/branded_product_lid_selection_test.rb`:

```ruby
require "test_helper"

class BrandedProductLidSelectionTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:branded_cup_8oz)
    @variant = product_variants(:branded_cup_8oz_variant_small)
  end

  test "step 4 displays compatible lids" do
    # Set up session with steps 1-3 completed
    post branded_product_configure_path(@product.slug),
         params: { step: 1, variant_id: @variant.id }

    post branded_product_configure_path(@product.slug),
         params: { step: 2, quantity: 1000 }

    post branded_product_configure_path(@product.slug),
         params: { step: 3 }

    # Step 4 should show compatible lids
    get branded_product_configure_path(@product.slug, step: 4)

    assert_response :success
    assert_select "h2", text: /Add Matching Lids/
    assert_select "[data-controller='lid-selector']"

    # Should show all three lid options
    assert_select ".card[data-lid-id='#{products(:flat_lid_8oz).id}']"
    assert_select ".card[data-lid-id='#{products(:domed_lid_8oz).id}']"
    assert_select ".card[data-lid-id='#{products(:sip_lid_8oz).id}']"

    # Out of stock lid should have badge
    assert_select ".card[data-lid-id='#{products(:sip_lid_8oz).id}'] .badge-error",
                  text: "Out of Stock"
  end

  test "selecting a lid stores it in session" do
    # Set up session
    post branded_product_configure_path(@product.slug),
         params: { step: 1, variant_id: @variant.id }
    post branded_product_configure_path(@product.slug),
         params: { step: 2, quantity: 1000 }
    post branded_product_configure_path(@product.slug),
         params: { step: 3 }

    # Select a lid
    lid = products(:flat_lid_8oz)
    lid_variant = product_variants(:flat_lid_8oz_variant)

    post branded_product_configure_path(@product.slug),
         params: {
           step: 4,
           lid_product_id: lid.id,
           lid_variant_id: lid_variant.id,
           lid_quantity: 1000
         }

    assert_redirected_to branded_product_configure_path(@product.slug, step: 5)

    # Verify session has lid data
    assert_equal lid.id.to_s, session[:branded_product_config][:lid_product_id]
    assert_equal lid_variant.id.to_s, session[:branded_product_config][:lid_variant_id]
    assert_equal 1000, session[:branded_product_config][:lid_quantity]
  end

  test "skipping lids clears selection from session" do
    # Set up session with lid selected
    post branded_product_configure_path(@product.slug),
         params: { step: 1, variant_id: @variant.id }
    post branded_product_configure_path(@product.slug),
         params: { step: 2, quantity: 1000 }
    post branded_product_configure_path(@product.slug),
         params: { step: 3 }
    post branded_product_configure_path(@product.slug),
         params: {
           step: 4,
           lid_product_id: products(:flat_lid_8oz).id,
           lid_variant_id: product_variants(:flat_lid_8oz_variant).id,
           lid_quantity: 1000
         }

    # Go back and skip
    get branded_product_configure_path(@product.slug, step: 4)
    post branded_product_configure_path(@product.slug),
         params: { step: 4, skip_lids: "1" }

    assert_redirected_to branded_product_configure_path(@product.slug, step: 5)

    # Verify lid data cleared from session
    assert_nil session[:branded_product_config][:lid_product_id]
    assert_nil session[:branded_product_config][:lid_variant_id]
    assert_nil session[:branded_product_config][:lid_quantity]
  end

  test "lid quantity re-syncs when cup quantity changes" do
    # Set up with specific quantities
    post branded_product_configure_path(@product.slug),
         params: { step: 1, variant_id: @variant.id }
    post branded_product_configure_path(@product.slug),
         params: { step: 2, quantity: 1000 }
    post branded_product_configure_path(@product.slug),
         params: { step: 3 }
    post branded_product_configure_path(@product.slug),
         params: {
           step: 4,
           lid_product_id: products(:flat_lid_8oz).id,
           lid_variant_id: product_variants(:flat_lid_8oz_variant).id,
           lid_quantity: 1000
         }

    # Go back and change cup quantity
    post branded_product_configure_path(@product.slug),
         params: { step: 2, quantity: 2000 }
    post branded_product_configure_path(@product.slug),
         params: { step: 3 }

    # Visit step 4 again
    get branded_product_configure_path(@product.slug, step: 4)

    # Lid quantity should match new cup quantity
    assert_equal 2000, session[:branded_product_config][:lid_quantity]
  end

  test "step 4 is skipped when product has no compatible lids" do
    # Use a product with no compatible lids
    product_without_lids = products(:branded_cup_12oz) # Assuming no lids configured
    variant = product_without_lids.active_variants.first

    post branded_product_configure_path(product_without_lids.slug),
         params: { step: 1, variant_id: variant.id }
    post branded_product_configure_path(product_without_lids.slug),
         params: { step: 2, quantity: 1000 }
    post branded_product_configure_path(product_without_lids.slug),
         params: { step: 3 }

    # Should redirect directly to step 5 (design upload)
    assert_redirected_to branded_product_configure_path(product_without_lids.slug, step: 5)
  end
end
```

**Step 2: Run tests**

```bash
rails test test/integration/branded_product_lid_selection_test.rb
```

Expected: Tests should pass (or fail initially if implementation incomplete)

**Step 3: Fix any failing tests**

Iterate on implementation based on test failures.

**Step 4: Commit**

```bash
git add test/integration/branded_product_lid_selection_test.rb
git commit -m "test: add integration tests for step 4 lid selection

- Tests lid display and selection
- Tests skip functionality
- Tests quantity re-sync when going back
- Tests automatic skip when no lids available"
```

---

## Task 12: System Test - End-to-End Flow

**Files:**
- Create: `test/system/branded_product_with_lids_test.rb`

**Step 1: Write system test**

Create `test/system/branded_product_with_lids_test.rb`:

```ruby
require "application_system_test_case"

class BrandedProductWithLidsTest < ApplicationSystemTestCase
  setup do
    @product = products(:branded_cup_8oz)
    @variant = product_variants(:branded_cup_8oz_variant_small)
  end

  test "user can configure cup and add matching lid" do
    visit branded_product_path(@product.slug)

    # Step 1: Select size
    click_button "Configure Product"
    find(".variant-card[data-variant-id='#{@variant.id}']").click
    click_button "Continue"

    # Step 2: Select quantity
    select "1,000 units", from: "quantity"
    click_button "Continue"

    # Step 3: Review
    assert_text @variant.name
    assert_text "1,000 units"
    click_button "Continue"

    # Step 4: Select lid
    assert_text "Add Matching Lids"

    # Verify three lid cards are shown
    assert_selector ".card[data-lid-id]", count: 3

    # Select flat lid (default should be pre-selected)
    flat_lid_card = find(".card[data-lid-id='#{products(:flat_lid_8oz).id}']")
    assert flat_lid_card[:class].include?("border-primary")

    # Verify quantity matches cup quantity
    assert_field "lid_quantity", with: "1000"

    click_button "Continue to Design Upload"

    # Step 5: Upload design
    assert_text "Upload Design"
    attach_file "design_file", Rails.root.join("test/fixtures/files/sample_design.pdf")
    click_button "Continue"

    # Step 6: Final review and add to cart
    assert_text "Review Your Configuration"
    assert_text @product.name
    assert_text "Flat Lid - 8oz" # Lid should be shown in review

    click_button "Add to Cart"

    # Verify both items in cart
    assert_current_path cart_path
    assert_text @product.name
    assert_text "Flat Lid - 8oz"
  end

  test "user can skip lid selection" do
    visit branded_product_path(@product.slug)

    # Navigate through steps 1-3
    click_button "Configure Product"
    find(".variant-card[data-variant-id='#{@variant.id}']").click
    click_button "Continue"
    select "1,000 units", from: "quantity"
    click_button "Continue"
    click_button "Continue"

    # Step 4: Skip lids
    check "No thanks, skip lids"
    click_button "Continue to Design Upload"

    # Should proceed to step 5
    assert_text "Upload Design"

    # Complete configuration
    attach_file "design_file", Rails.root.join("test/fixtures/files/sample_design.pdf")
    click_button "Continue"
    click_button "Add to Cart"

    # Verify only cup in cart (no lid)
    assert_text @product.name
    assert_no_text "Lid"
  end

  test "out of stock lids are shown but not selectable" do
    visit branded_product_path(@product.slug)

    # Navigate to step 4
    click_button "Configure Product"
    find(".variant-card[data-variant-id='#{@variant.id}']").click
    click_button "Continue"
    select "1,000 units", from: "quantity"
    click_button "Continue"
    click_button "Continue"

    # Verify out of stock lid shows badge
    sip_lid_card = find(".card[data-lid-id='#{products(:sip_lid_8oz).id}']")
    assert sip_lid_card.has_css?(".badge-error", text: "Out of Stock")
    assert sip_lid_card[:class].include?("opacity-50")

    # Try to click it (should not select)
    sip_lid_card.click

    # Should not become selected
    assert_not sip_lid_card[:class].include?("border-primary")
  end

  test "changing cup quantity updates lid quantity" do
    visit branded_product_path(@product.slug)

    # Configure with 1000 quantity
    click_button "Configure Product"
    find(".variant-card[data-variant-id='#{@variant.id}']").click
    click_button "Continue"
    select "1,000 units", from: "quantity"
    click_button "Continue"
    click_button "Continue"

    # Lid quantity should match
    assert_field "lid_quantity", with: "1000"

    # Go back and change quantity
    click_link "← Back"
    click_link "← Back"
    select "2,000 units", from: "quantity"
    click_button "Continue"
    click_button "Continue"

    # Lid quantity should update
    assert_field "lid_quantity", with: "2000"
  end
end
```

**Step 2: Run system tests**

```bash
rails test:system test/system/branded_product_with_lids_test.rb
```

Expected: Tests open browser and test full flow

**Step 3: Fix any failures**

Debug and fix issues found by system tests.

**Step 4: Commit**

```bash
git add test/system/branded_product_with_lids_test.rb
git commit -m "test: add system tests for end-to-end lid selection flow

- Tests complete configurator flow with lid selection
- Tests skip functionality
- Tests out-of-stock lid handling
- Tests quantity synchronization"
```

---

## Task 13: Documentation and Final Polish

**Files:**
- Modify: `CLAUDE.md`
- Create: `docs/features/branded-product-configurator.md` (optional)

**Step 1: Update CLAUDE.md**

Add documentation about the lid selection feature to `CLAUDE.md`:

```markdown
### Working with Branded Product Configurator

The branded product configurator allows customers to customize cups with their branding:

**Configuration Steps:**
1. Select size (variant)
2. Select quantity
3. Review configuration
4. Add matching lids (optional) - NEW
5. Upload design file
6. Final review and add to cart

**Step 4: Matching Lids (Optional)**
- Shows 2-3 compatible lid products based on cup selection
- Admin configures compatible lids via `product_compatible_lids` join table
- Default lid is pre-selected
- Quantity auto-matches cup quantity but can be edited
- Out-of-stock lids shown with badge but not selectable
- Step automatically skipped if no compatible lids configured
- Lid quantity re-syncs if user changes cup quantity

**Database Schema:**
- `product_compatible_lids` - Join table linking cups to compatible lids
  - `product_id` - The cup product
  - `compatible_lid_id` - The lid product
  - `default` - Boolean for pre-selection
  - `sort_order` - Display order in UI

**Admin Setup:**
- Edit a branded cup product
- Add compatible lids in "Compatible Lids" section
- Set one as default
- Adjust sort order for display

**Session Data:**
Configuration stored in `session[:branded_product_config]`:
- `variant_id` - Selected cup variant
- `quantity` - Cup quantity
- `lid_product_id` - Selected lid product (if any)
- `lid_variant_id` - Selected lid variant (if any)
- `lid_quantity` - Lid quantity (if any)
- `design_file_url` - Uploaded design URL
```

**Step 2: Run full test suite**

```bash
rails test
rails test:system
```

Expected: All tests pass

**Step 3: Manual QA checklist**

Test in browser:
- [ ] Admin can add/remove compatible lids
- [ ] Admin can set default lid
- [ ] Step 4 shows for products with compatible lids
- [ ] Step 4 skips for products without compatible lids
- [ ] Default lid is pre-selected
- [ ] Out-of-stock lids show badge and can't be selected
- [ ] Quantity matches cup quantity initially
- [ ] Can edit lid quantity
- [ ] Skip checkbox works
- [ ] Going back and changing cup quantity updates lid quantity
- [ ] Both cup and lid added to cart
- [ ] Skipping lids means only cup in cart

**Step 4: Final commit**

```bash
git add CLAUDE.md docs/
git commit -m "docs: document matching lids feature

- Updated CLAUDE.md with step 4 documentation
- Admin setup instructions
- Session data structure
- Database schema reference"
```

---

## Completion Checklist

- [ ] Database migration for `product_compatible_lids` table
- [ ] `ProductCompatibleLid` model with associations and validations
- [ ] Product model associations for compatible lids
- [ ] Admin UI for managing compatible lids (nested form)
- [ ] Step 4 view with card-based lid selection
- [ ] Stimulus controller for interactive lid selection
- [ ] Controller logic for step 4 (load lids, handle selection)
- [ ] AJAX endpoint for price calculation
- [ ] Cart addition logic for both cups and lids
- [ ] Test fixtures for lid products and compatibility
- [ ] Integration tests for step 4 flow
- [ ] System tests for end-to-end flow
- [ ] Documentation in CLAUDE.md
- [ ] All tests passing
- [ ] Manual QA complete

---

## Notes for Engineer

**Assumptions:**
- Branded product configurator already exists for steps 1-3, 5-6
- Session-based configuration storage already in place
- Cart can handle multiple products being added at once
- Lid products are standard products (not branded/customizable)
- Each lid product has a single variant (simplification)

**Edge Cases Handled:**
- No compatible lids → Skip step 4 entirely
- Out of stock lids → Show greyed out with badge
- User changes cup selection → Reset lid selection
- User changes cup quantity → Re-sync lid quantity
- Skip lids → Clear lid config from session

**DRY / YAGNI Applied:**
- Using existing Product model for lids (no separate Lid model)
- Leveraging existing session structure
- Reusing cart addition logic
- Simple join table (no over-engineering)

**Testing Strategy:**
- Unit tests for models and associations
- Integration tests for controller flow and session management
- System tests for end-to-end user experience
- Manual QA for visual polish and UX

**Potential Future Enhancements:**
- Multiple lid variants per product
- Lid-specific design upload
- Quantity recommendations based on cup/lid ratio
- Admin bulk management of compatibilities
- Compatibility suggestions based on product attributes
