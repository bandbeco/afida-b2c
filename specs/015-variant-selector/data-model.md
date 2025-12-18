# Data Model: Unified Variant Selector

**Feature**: 015-variant-selector
**Date**: 2025-12-18

## Entity Overview

```
┌─────────────┐       ┌──────────────────┐
│   Product   │──────<│  ProductVariant  │
└─────────────┘  1:N  └──────────────────┘
                              │
                              │ option_values (JSONB)
                              │ pricing_tiers (JSONB) ← NEW
                              ▼
                      ┌──────────────────┐
                      │  Option Values   │
                      │  (denormalized)  │
                      └──────────────────┘
```

## Existing Entities (No Changes)

### Product

| Field | Type | Description |
|-------|------|-------------|
| id | bigint | Primary key |
| name | string | Product name |
| slug | string | URL-friendly identifier |
| product_type | enum | "standard", "customizable_template" |
| active | boolean | Whether product is visible |
| ... | ... | Other existing fields |

**Relevant Methods**:
- `active_variants` - Returns active variants for product
- `default_variant` - Returns first active variant

### ProductVariant (Existing + New Column)

| Field | Type | Description |
|-------|------|-------------|
| id | bigint | Primary key |
| product_id | bigint | Foreign key to Product |
| sku | string | Stock keeping unit |
| price | decimal | Price per pack |
| pac_size | integer | Units per pack |
| stock_quantity | integer | Available inventory |
| option_values | jsonb | **EXISTING** - Option selections |
| pricing_tiers | jsonb | **NEW** - Volume discount tiers |
| active | boolean | Whether variant is purchasable |

## New Column: pricing_tiers

### Schema

```ruby
# Migration
add_column :product_variants, :pricing_tiers, :jsonb, default: nil
```

### Structure

```json
[
  { "quantity": 1, "price": "16.00" },
  { "quantity": 3, "price": "14.50" },
  { "quantity": 5, "price": "13.00" },
  { "quantity": 10, "price": "12.00" }
]
```

| Field | Type | Description |
|-------|------|-------------|
| quantity | integer | Number of packs at this tier |
| price | string | Price per pack (stored as string to preserve precision) |

### Validation Rules

- Array must be sorted by quantity ascending
- Quantity must be positive integer
- Price must be valid decimal string
- No duplicate quantities allowed
- If present, must have at least one tier

### Model Validation

```ruby
# app/models/product_variant.rb
validate :pricing_tiers_format, if: :pricing_tiers?

private

def pricing_tiers_format
  return if pricing_tiers.blank?

  unless pricing_tiers.is_a?(Array)
    errors.add(:pricing_tiers, "must be an array")
    return
  end

  quantities = []
  pricing_tiers.each_with_index do |tier, i|
    unless tier.is_a?(Hash) && tier["quantity"].is_a?(Integer) && tier["quantity"] > 0
      errors.add(:pricing_tiers, "tier #{i} must have positive integer quantity")
    end

    unless tier["price"].present? && tier["price"].to_s.match?(/\A\d+\.?\d*\z/)
      errors.add(:pricing_tiers, "tier #{i} must have valid price")
    end

    if quantities.include?(tier["quantity"])
      errors.add(:pricing_tiers, "duplicate quantity #{tier['quantity']}")
    end
    quantities << tier["quantity"]
  end

  unless quantities == quantities.sort
    errors.add(:pricing_tiers, "must be sorted by quantity")
  end
end
```

## Existing JSONB: option_values

### Structure (Unchanged)

```json
{
  "material": "Paper",
  "size": "8oz",
  "colour": "White"
}
```

### Valid Option Keys

| Key | Example Values | Sort Order |
|-----|----------------|------------|
| material | "Paper", "Kraft", "Bamboo", "Plastic" | Alphabetical |
| type | "Fork", "Knife", "Spoon", "Stirrer" | Alphabetical |
| size | "8oz", "12oz", "16oz", "6x140mm", "10\"" | Natural (numeric) |
| colour | "Black", "White", "Red", "Natural" | Alphabetical |

### Option Priority Order

Display order is hardcoded: `material` → `type` → `size` → `colour`

Only options with multiple values across variants are displayed as selection steps.

## Tables to Remove (Phase 3)

After migration is validated, these tables become redundant:

### product_options

| Field | Type | Notes |
|-------|------|-------|
| id | bigint | - |
| name | string | e.g., "size", "colour" |
| display_type | string | "dropdown", "radio", "swatch" |
| position | integer | Display order |

### product_option_values

| Field | Type | Notes |
|-------|------|-------|
| id | bigint | - |
| product_option_id | bigint | FK to product_options |
| value | string | e.g., "8oz" |
| label | string | Display label (optional) |
| position | integer | Display order |

### product_option_assignments

| Field | Type | Notes |
|-------|------|-------|
| id | bigint | - |
| product_id | bigint | FK to products |
| product_option_id | bigint | FK to product_options |
| position | integer | Display order for this product |

## Data Migration

### Rake Task: product_options:migrate_to_json

```ruby
# lib/tasks/product_options.rake
namespace :product_options do
  desc "Migrate ProductOption data to variant option_values JSON"
  task migrate_to_json: :environment do
    Product.find_each do |product|
      product.variants.find_each do |variant|
        # Skip if already has option_values
        next if variant.option_values.present?

        option_values = {}
        product.product_option_assignments.includes(product_option: :values).each do |assignment|
          option = assignment.product_option
          # Find the value assigned to this variant
          assigned_value = variant.product_option_values.find_by(product_option: option)
          option_values[option.name] = assigned_value&.value if assigned_value
        end

        variant.update_column(:option_values, option_values) if option_values.present?
      end
    end

    puts "Migration complete. Verify data before removing ProductOption tables."
  end

  desc "Verify option_values migration"
  task verify_migration: :environment do
    issues = []

    ProductVariant.where.not(option_values: nil).find_each do |variant|
      if variant.option_values.blank?
        issues << "Variant #{variant.sku}: empty option_values"
      end
    end

    if issues.any?
      puts "Issues found:"
      issues.each { |i| puts "  - #{i}" }
    else
      puts "All variants verified successfully!"
    end
  end
end
```

## Fixture Data

### test/fixtures/product_variants.yml

```yaml
# Existing fixtures with pricing_tiers added

paper_straw_8oz_black:
  product: eco_straws
  sku: "STRAW-PAPER-8OZ-BLACK"
  price: 25.00
  pac_size: 500
  option_values:
    material: "Paper"
    size: "8oz"
    colour: "Black"
  pricing_tiers:
    - quantity: 1
      price: "25.00"
    - quantity: 3
      price: "23.00"
    - quantity: 5
      price: "21.00"
  active: true

pizza_box_12inch:
  product: pizza_boxes
  sku: "PIZZA-12"
  price: 35.00
  pac_size: 50
  option_values:
    size: "12\""
  pricing_tiers: null  # No tiers - uses standard pricing
  active: true
```

## Query Patterns

### Get Options for Product

```ruby
# Product model method
def extract_options_from_variants
  option_counts = Hash.new { |h, k| h[k] = Set.new }

  active_variants.each do |variant|
    variant.option_values&.each do |key, value|
      option_counts[key] << value
    end
  end

  # Filter to options with multiple values, sort by priority
  priority = %w[material type size colour]
  option_counts
    .select { |_, values| values.size > 1 }
    .sort_by { |key, _| priority.index(key) || 999 }
    .to_h
    .transform_values(&:to_a)
end
```

### Get Variants for Selector

```ruby
# Product model method
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

### Find Variant by Selections

```ruby
# Used in cart/order creation
def find_variant_by_options(selections)
  active_variants.find do |v|
    selections.all? { |key, value| v.option_values[key] == value }
  end
end
```
