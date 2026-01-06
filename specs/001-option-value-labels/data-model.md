# Data Model: Product Option Value Labels

**Feature**: 001-option-value-labels
**Date**: 2026-01-06

## Entity Relationship Overview

```
┌─────────────────┐       ┌──────────────────────┐       ┌─────────────────────┐
│  ProductOption  │       │  ProductOptionValue  │       │   ProductVariant    │
├─────────────────┤       ├──────────────────────┤       ├─────────────────────┤
│ id              │──┐    │ id                   │──┐    │ id                  │
│ name            │  │    │ product_option_id    │  │    │ product_id          │
│ display_type    │  │    │ value                │  │    │ sku                 │
│ required        │  └───<│ label                │  │    │ price               │
│ position        │       │ position             │  │    │ pac_size            │
└─────────────────┘       └──────────────────────┘  │    │ ...                 │
                                                    │    └─────────────────────┘
                                                    │              │
                                                    │              │
                          ┌────────────────────────┐│              │
                          │  VariantOptionValue    ││              │
                          │  (NEW JOIN TABLE)      ││              │
                          ├────────────────────────┤│              │
                          │ id                     ││              │
                          │ product_variant_id     │◄──────────────┘
                          │ product_option_value_id│◄──────────────┘
                          │ product_option_id      │  (denormalized for constraint)
                          │ created_at             │
                          │ updated_at             │
                          └────────────────────────┘
```

## New Entity: VariantOptionValue

### Purpose
Join table linking `ProductVariant` to `ProductOptionValue`, replacing the JSONB `option_values` column. Enables proper relationships with labels while enforcing data integrity constraints.

### Schema

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | bigint | PK, auto-increment | Primary key |
| `product_variant_id` | bigint | NOT NULL, FK → product_variants | The variant being configured |
| `product_option_value_id` | bigint | NOT NULL, FK → product_option_values | The selected option value |
| `product_option_id` | bigint | NOT NULL, FK → product_options | Denormalized for constraint enforcement |
| `created_at` | datetime | NOT NULL | Rails timestamp |
| `updated_at` | datetime | NOT NULL | Rails timestamp |

### Indexes

| Name | Columns | Type | Purpose |
|------|---------|------|---------|
| `idx_variant_option_values_unique` | `(product_variant_id, product_option_value_id)` | UNIQUE | Prevent duplicate assignments |
| `idx_variant_one_value_per_option` | `(product_variant_id, product_option_id)` | UNIQUE | One value per option type per variant |
| `index_variant_option_values_on_product_variant_id` | `product_variant_id` | BTREE | FK lookup |
| `index_variant_option_values_on_product_option_value_id` | `product_option_value_id` | BTREE | FK lookup |
| `index_variant_option_values_on_product_option_id` | `product_option_id` | BTREE | FK lookup |

### Associations

```ruby
class VariantOptionValue < ApplicationRecord
  belongs_to :product_variant
  belongs_to :product_option_value
  belongs_to :product_option
end
```

### Validations

| Validation | Rule | Error Message |
|------------|------|---------------|
| product_option_id uniqueness | Scoped to product_variant_id | "already has a value for this option" |

### Callbacks

| Callback | Trigger | Action |
|----------|---------|--------|
| `before_validation :set_product_option_from_value` | On create/update | Auto-populate `product_option_id` from `product_option_value.product_option_id` |

## Modified Entity: ProductVariant

### Changes

| Change | Before | After |
|--------|--------|-------|
| `option_values` column | JSONB column | REMOVED |
| `variant_option_values` association | N/A | `has_many :variant_option_values, dependent: :destroy` |
| `option_values` association | N/A | `has_many :option_values, through: :variant_option_values, source: :product_option_value` |

### New Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `option_values_hash` | `Hash<String, String>` | Returns `{ "size" => "8oz", "colour" => "White" }` - backwards compatible with JSONB structure |
| `option_labels_hash` | `Hash<String, String>` | Returns `{ "size" => "8 oz", "colour" => "White" }` - uses labels with value fallback |
| `options_summary` | `String` | Returns `"8 oz, White"` - comma-separated labels for display |

## Modified Entity: Product

### Changes

| Change | Before | After |
|--------|--------|-------|
| `extract_options_from_variants` method | Parses JSONB from variants | REMOVED |
| `available_options` method | N/A | NEW - queries through join table associations |

### Updated Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `available_options` | `Hash<String, Array<String>>` | Returns `{ "size" => ["8oz", "12oz"], "colour" => ["White", "Black"] }` - options with multiple values |
| `variants_for_selector` | `Array<Hash>` | Returns variant data for JS selector; uses `option_values_hash` internally |

## Unchanged Entities

### ProductOption
No changes. Defines option types (size, colour, material).

### ProductOptionValue
No changes. Stores `value` (machine-readable) and `label` (human-readable).

### ProductOptionAssignment
No changes. Links products to which options they use.

## Data Migration

### Strategy
Re-seed approach - no data migration scripts needed for pre-launch site.

### Order of Operations
1. Create `variant_option_values` table (migration)
2. Remove `option_values` column from `product_variants` (migration)
3. Update seed files to use join table
4. Run `rails db:reset`

### Seed Data Example

```ruby
# Before (JSONB)
variant.option_values = { 'size' => '8oz', 'colour' => 'White' }

# After (join table)
variant.save!
size_value = ProductOptionValue.joins(:product_option)
  .find_by!(product_options: { name: 'size' }, value: '8oz')
variant.option_values << size_value

colour_value = ProductOptionValue.joins(:product_option)
  .find_by!(product_options: { name: 'colour' }, value: 'White')
variant.option_values << colour_value
```

## Query Patterns

### Get variant's option values with labels
```ruby
variant.variant_option_values.includes(product_option_value: :product_option)
```

### Find all variants with a specific option value
```ruby
ProductVariant.joins(:option_values).where(product_option_values: { value: '8oz' })
```

### Get product's available options
```ruby
product.active_variants.includes(option_values: :product_option)
```
