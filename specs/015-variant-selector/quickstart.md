# Quickstart: Unified Variant Selector

**Feature**: 015-variant-selector
**Date**: 2025-12-18

## Overview

This guide explains how to implement and use the unified variant selector component.

## Prerequisites

- Rails 8.x with PostgreSQL
- Vite + Stimulus setup
- TailwindCSS 4 + DaisyUI
- Existing Product/ProductVariant models

## Implementation Steps

### Step 1: Database Migration

```bash
rails generate migration AddPricingTiersToProductVariants pricing_tiers:jsonb
rails db:migrate
```

### Step 2: Model Methods

Add to `app/models/product.rb`:

```ruby
def extract_options_from_variants
  option_counts = Hash.new { |h, k| h[k] = Set.new }

  active_variants.each do |variant|
    variant.option_values&.each do |key, value|
      option_counts[key] << value
    end
  end

  priority = %w[material type size colour]
  option_counts
    .select { |_, values| values.size > 1 }
    .sort_by { |key, _| priority.index(key) || 999 }
    .to_h
    .transform_values(&:to_a)
end

def variants_for_selector
  active_variants.map do |v|
    {
      id: v.id,
      sku: v.sku,
      price: v.price.to_f,
      pac_size: v.pac_size,
      option_values: v.option_values,
      pricing_tiers: v.pricing_tiers,
      image_url: v.primary_photo&.url
    }
  end
end
```

### Step 3: Controller Setup

In `app/controllers/products_controller.rb`:

```ruby
def show
  @product = Product.find_by!(slug: params[:slug])
  @options = @product.extract_options_from_variants
  @variants_json = @product.variants_for_selector.to_json
end
```

### Step 4: View Partial

Create `app/views/products/_variant_selector.html.erb`:

```erb
<div data-controller="variant-selector"
     data-variant-selector-variants-value="<%= @variants_json %>"
     data-variant-selector-options-value="<%= @options.to_json %>"
     data-variant-selector-priority-value='["material","type","size","colour"]'
     class="space-y-2">

  <%# Option Steps %>
  <% @options.each_with_index do |(option_name, values), index| %>
    <div class="collapse collapse-arrow bg-base-100 border border-base-300 rounded-lg"
         data-variant-selector-target="step"
         data-option-name="<%= option_name %>">
      <input type="radio"
             name="variant-accordion"
             <%= "checked" if index == 0 %>
             data-variant-selector-target="stepRadio" />
      <div class="collapse-title font-medium flex items-center gap-2">
        <span class="step-indicator flex items-center justify-center w-6 h-6 rounded-full text-sm font-bold"
              data-variant-selector-target="stepIndicator">
          <%= index + 1 %>
        </span>
        <span>Select <%= option_name.titleize %></span>
        <span class="text-primary font-semibold hidden"
              data-variant-selector-target="stepSelection"></span>
      </div>
      <div class="collapse-content">
        <div class="flex flex-wrap gap-2 pt-2">
          <% values.each do |value| %>
            <button type="button"
                    class="btn btn-outline btn-sm"
                    data-variant-selector-target="optionButton"
                    data-option-name="<%= option_name %>"
                    data-value="<%= value %>"
                    data-action="click->variant-selector#selectOption">
              <%= value %>
            </button>
          <% end %>
        </div>
      </div>
    </div>
  <% end %>

  <%# Quantity Step %>
  <div class="collapse collapse-arrow bg-base-100 border border-base-300 rounded-lg"
       data-variant-selector-target="quantityStep">
    <input type="radio" name="variant-accordion" data-variant-selector-target="quantityStepRadio" />
    <div class="collapse-title font-medium flex items-center gap-2">
      <span class="step-indicator flex items-center justify-center w-6 h-6 rounded-full text-sm font-bold"
            data-variant-selector-target="quantityStepIndicator">
        <%= @options.size + 1 %>
      </span>
      <span>Select Quantity</span>
    </div>
    <div class="collapse-content">
      <div data-variant-selector-target="quantityContent" class="pt-2">
        <!-- Populated by JavaScript -->
      </div>
    </div>
  </div>

  <%# Add to Cart %>
  <button type="button"
          class="btn btn-primary btn-block mt-4"
          data-variant-selector-target="addToCartButton"
          data-action="click->variant-selector#addToCart"
          disabled>
    Add to Cart
  </button>

  <%# Hidden Form %>
  <form data-variant-selector-target="form"
        action="/cart/cart_items"
        method="post"
        data-turbo-frame="_top">
    <%= hidden_field_tag :authenticity_token, form_authenticity_token %>
    <input type="hidden" name="cart_item[variant_sku]" data-variant-selector-target="variantSkuInput" />
    <input type="hidden" name="cart_item[quantity]" data-variant-selector-target="quantityInput" value="1" />
  </form>
</div>
```

### Step 5: Stimulus Controller

Create `app/frontend/javascript/controllers/variant_selector_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "step", "stepRadio", "stepIndicator", "stepSelection",
    "optionButton", "quantityStep", "quantityStepRadio",
    "quantityStepIndicator", "quantityContent",
    "addToCartButton", "form", "variantSkuInput", "quantityInput"
  ]

  static values = {
    variants: Array,
    options: Object,
    priority: Array
  }

  connect() {
    this.selections = {}
    this.selectedQuantity = 1
    this.loadFromUrlParams()
  }

  selectOption(event) {
    const button = event.currentTarget
    const optionName = button.dataset.optionName
    const value = button.dataset.value

    // Update selection
    this.selections[optionName] = value

    // Clear downstream selections
    this.clearDownstreamSelections(optionName)

    // Update UI
    this.updateOptionButtons()
    this.updateStepHeaders()
    this.collapseStepAndExpandNext(optionName)
    this.updateQuantityStep()
    this.updateUrl()
  }

  // ... Additional methods
}
```

### Step 6: Register Controller

In `app/frontend/entrypoints/application.js`:

```javascript
const lazyControllers = {
  // ... existing controllers
  "variant-selector": () => import("../javascript/controllers/variant_selector_controller"),
}
```

## Usage

### Basic Product Page

```erb
<%# app/views/products/show.html.erb %>
<div class="grid grid-cols-1 md:grid-cols-2 gap-8">
  <%# Product Image %>
  <div>
    <%= image_tag @product.primary_photo&.url, class: "w-full rounded-lg" %>
  </div>

  <%# Product Info + Selector %>
  <div>
    <h1 class="text-3xl font-bold"><%= @product.name %></h1>
    <p class="text-xl text-gray-600 mt-2">From <%= number_to_currency(@product.price_range.min) %></p>
    <p class="mt-4"><%= @product.description_standard_with_fallback %></p>

    <div class="mt-6">
      <%= render "products/variant_selector" %>
    </div>
  </div>
</div>
```

### With Pricing Tiers

When a variant has `pricing_tiers`, the quantity step displays tier cards:

```erb
<%# Tier cards are rendered by JavaScript when variant is selected %>
```

### Without Pricing Tiers

Falls back to quantity dropdown:

```erb
<%# Dropdown is rendered by JavaScript when variant has no tiers %>
```

## Testing

### System Test

```ruby
# test/system/variant_selector_test.rb
require "application_system_test_case"

class VariantSelectorTest < ApplicationSystemTestCase
  test "selecting options reveals quantity step" do
    product = products(:eco_straws)
    visit product_path(product)

    # First step expanded
    assert_selector "[data-option-name='material']"

    # Select material
    click_button "Paper"

    # Step collapses, next expands
    assert_selector ".collapse-title", text: /Select Material : Paper/

    # Select size
    click_button "8oz"

    # Quantity step now visible
    assert_selector "[data-variant-selector-target='quantityContent']"
  end
end
```

### Unit Test

```ruby
# test/models/product_test.rb
class ProductTest < ActiveSupport::TestCase
  test "extract_options_from_variants returns multi-value options only" do
    product = products(:eco_straws)
    options = product.extract_options_from_variants

    assert options.key?("material")
    assert options.key?("size")
    assert options["material"].size > 1
  end
end
```

## Troubleshooting

### Controller Not Loading

1. Check `lazyControllers` registration in application.js
2. Verify `data-controller="variant-selector"` in HTML
3. Check browser console for import errors

### Options Not Filtering

1. Verify `option_values` JSON on variants
2. Check variant `active` status
3. Inspect `this.variantsValue` in browser console

### Accordion Not Collapsing

1. Ensure all steps have same `name="variant-accordion"` on radio
2. Check DaisyUI collapse classes are applied
3. Verify JavaScript is setting `checked` attribute

## Related Files

- Spec: [spec.md](./spec.md)
- Data Model: [data-model.md](./data-model.md)
- Research: [research.md](./research.md)
- Design: [../../docs/plans/2025-12-18-unified-variant-selector-design.md](../../docs/plans/2025-12-18-unified-variant-selector-design.md)
