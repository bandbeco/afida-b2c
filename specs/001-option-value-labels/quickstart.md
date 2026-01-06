# Quickstart: Product Option Value Labels

**Feature**: 001-option-value-labels
**Date**: 2026-01-06

## Overview

This feature replaces the JSONB `option_values` column on `ProductVariant` with a proper join table, enabling clean separation of stored values from display labels.

## Key Changes Summary

| Component | Change |
|-----------|--------|
| New model | `VariantOptionValue` - join table model |
| ProductVariant | Remove JSONB, add `option_values_hash`, `option_labels_hash` |
| Product | Replace `extract_options_from_variants` with `available_options` |
| Views | Use `option_labels_hash` for display |
| Seeds | Use join table assignment instead of JSONB |

## Getting Started

### 1. Run migrations
```bash
rails db:migrate
```

### 2. Reset database with updated seeds
```bash
rails db:reset
```

### 3. Verify setup
```bash
rails console
```
```ruby
# Check join table records exist
VariantOptionValue.count
# => Should be > 0

# Check variant has options
v = ProductVariant.first
v.option_values_hash
# => {"size"=>"8oz", "colour"=>"White"}

v.option_labels_hash
# => {"size"=>"8 oz", "colour"=>"White"}
```

## Usage Examples

### Display option labels in views
```erb
<%# Before (JSONB) %>
<%= variant.option_values["size"] %>

<%# After (with labels) %>
<%= variant.option_labels_hash["size"] %>

<%# Summary string %>
<%= variant.options_summary %>
```

### Get available options for a product
```ruby
product.available_options
# => {"size"=>["8oz", "12oz"], "colour"=>["White", "Black"]}
```

### Assign options to a variant (seeds/admin)
```ruby
variant.save!

size_value = ProductOptionValue.joins(:product_option)
  .find_by!(product_options: { name: 'size' }, value: '8oz')
variant.option_values << size_value
```

### Query variants by option
```ruby
# All 8oz variants
ProductVariant.joins(:option_values)
  .where(product_option_values: { value: '8oz' })
```

## Testing

### Run model tests
```bash
rails test test/models/variant_option_value_test.rb
rails test test/models/product_variant_test.rb
```

### Run system tests for variant selector
```bash
rails test:system test/system/variant_selector_test.rb
```

## Key Constraints

1. **One value per option per variant**: A variant cannot have both "8oz" AND "12oz" for size
2. **Referential integrity**: Option values must exist before assignment
3. **Auto-populated option_id**: `product_option_id` is set automatically from the option value

## Files to Review

| File | Purpose |
|------|---------|
| `app/models/variant_option_value.rb` | New join table model |
| `app/models/product_variant.rb` | Updated associations and methods |
| `app/models/product.rb` | Updated `available_options` method |
| `db/seeds/products_from_csv.rb` | Updated seeding logic |
| `test/fixtures/variant_option_values.yml` | Test fixtures |

## Troubleshooting

### "already has a value for this option" error
A variant already has a value assigned for that option type. Remove the existing value first or update it.

### RecordNotFound when seeding
The option value doesn't exist in `ProductOptionValue`. Check the value string matches exactly (case-sensitive).

### N+1 query warnings
Use eager loading: `includes(option_values: :product_option)` when loading variants.
