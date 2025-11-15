# API Contracts: Product Descriptions Enhancement

**Feature**: 004-product-descriptions
**Date**: 2025-11-15

## Overview

This feature does not introduce new API endpoints or external integrations. All changes are internal to the Rails application (database, views, models).

## Modified Endpoints

### Admin Product Update (Existing)

**Endpoint**: `PATCH /admin/products/:id`

**Request** (form data):
```ruby
params = {
  product: {
    name: "Product Name",
    sku: "SKU123",
    # ... other existing fields ...
    description_short: "Brief description text",     # NEW
    description_standard: "Medium description text", # NEW
    description_detailed: "Detailed description text" # NEW
  }
}
```

**Response** (unchanged):
- Success: Redirect to admin products index with flash message
- Failure: Re-render form with validation errors

**Strong Parameters Update**:
```ruby
# app/controllers/admin/products_controller.rb
def product_params
  params.require(:product).permit(
    :name, :sku, :slug, # ... existing fields ...
    :description_short,   # NEW
    :description_standard, # NEW
    :description_detailed  # NEW
  )
end
```

**Validation**: All three description fields are optional (no presence validation)

## Public-Facing Endpoints (Modified Responses)

### Product Show Page

**Endpoint**: `GET /products/:slug`

**Response Changes** (HTML):
- Product intro section now includes `@product.description_standard_with_fallback`
- Product details section now includes `@product.description_detailed_with_fallback`
- Meta tags use `@product.description_standard` for description when custom `meta_description` blank

**Example**:
```erb
<!-- Above fold -->
<p class="text-lg text-gray-700 mb-6">
  <%= @product.description_standard_with_fallback %>
</p>

<!-- Below fold -->
<div class="product-details mt-8">
  <h2 class="text-2xl font-semibold mb-4">Product Details</h2>
  <div class="prose prose-lg">
    <%= simple_format(@product.description_detailed_with_fallback) %>
  </div>
</div>
```

### Shop & Category Pages

**Endpoints**:
- `GET /shop`
- `GET /categories/:slug`

**Response Changes** (HTML):
- Product cards now include `product.description_short_with_fallback`

**Example**:
```erb
<div class="product-card">
  <h3><%= product.name %></h3>
  <p class="text-sm text-gray-600">
    <%= product.description_short_with_fallback %>
  </p>
  <!-- ... rest of card ... -->
</div>
```

## Stimulus Controller Contract

### Character Counter Controller

**Controller Name**: `character-counter`

**Data Attributes**:
```html
<textarea
  data-controller="character-counter"
  data-character-counter-target="input"
  data-character-counter-min-value="10"
  data-character-counter-target-value="25"
  data-character-counter-max-value="50"
></textarea>
<div data-character-counter-target="counter"></div>
```

**Values**:
- `min` (number) - Minimum target words (shows yellow below this)
- `target` (number) - Ideal target words (shows green in range)
- `max` (number) - Maximum recommended words (shows red above this)

**Targets**:
- `input` - The textarea element to count
- `counter` - The display element for count and feedback

**Behavior**:
- Listens to `input` event on textarea
- Counts words (split by whitespace)
- Updates counter target with current word count
- Applies CSS classes based on thresholds:
  - `text-green-600` when count in [min, max] range
  - `text-yellow-600` when count < min
  - `text-red-600` when count > max

**Example Output**:
```html
<!-- Green (in range) -->
<div class="text-green-600">22 words</div>

<!-- Yellow (too few) -->
<div class="text-yellow-600">8 words</div>

<!-- Red (too many) -->
<div class="text-red-600">65 words</div>
```

## Database Contract

### Product Table Schema

**Before Migration**:
```ruby
create_table "products" do |t|
  # ... existing columns ...
  t.text "description"
  # ... more columns ...
end
```

**After Migration**:
```ruby
create_table "products" do |t|
  # ... existing columns ...
  # REMOVED: t.text "description"
  t.text "description_short"
  t.text "description_standard"
  t.text "description_detailed"
  # ... more columns ...
end
```

## Data Contract (CSV)

**Source File**: `lib/data/products.csv`

**Required Columns**:
- `sku` - Unique product identifier for matching
- `description_short` - Short description text
- `description_standard` - Standard description text
- `description_detailed` - Detailed description text

**Format**: CSV with headers, UTF-8 encoding

**Contract**: Migration expects CSV to exist and have these columns. Products without matching SKU will be skipped with warning (not error).

## Backward Compatibility

### Migration Reversibility

The migration is fully reversible:

**Down migration**:
1. Re-adds `description` column
2. Copies `description_standard` to `description` (best single-field fallback)
3. Removes three new description columns

**Risk**: If down migration is run after manual edits in production, `description_short` and `description_detailed` data will be lost (only `description_standard` preserved).

**Recommendation**: Do not roll back after production deployment unless absolutely necessary.

## No External APIs

This feature is entirely internal to the Rails application. No external API calls, webhooks, or third-party integrations.

## Summary

- **Modified Endpoints**: 1 (admin product update - strong params only)
- **New Endpoints**: 0
- **Modified Views**: 4 (shop, category show, product show, admin form)
- **New Stimulus Controllers**: 1 (character-counter)
- **Database Changes**: Remove 1 column, add 3 columns (same table)
- **External APIs**: None
- **Backward Compatibility**: Reversible migration with data preservation caveat
