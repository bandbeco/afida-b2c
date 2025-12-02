# Data Model: Variant-Level Sample Request System

**Date**: 2025-12-01
**Feature**: 011-variant-samples

## Schema Changes

### ProductVariant (Modified)

```
┌───────────────────────────────────────────────────────────────┐
│                      product_variants                          │
├───────────────────────────────────────────────────────────────┤
│ ... existing columns ...                                       │
├───────────────────────────────────────────────────────────────┤
│ + sample_eligible : boolean, default: false, null: false      │ NEW
│ + sample_sku      : string, null: true                        │ NEW
├───────────────────────────────────────────────────────────────┤
│ INDEX: sample_eligible (for efficient scope queries)          │
└───────────────────────────────────────────────────────────────┘
```

**Field Descriptions:**

| Field | Type | Description |
|-------|------|-------------|
| `sample_eligible` | boolean | When true, variant appears on /samples page and can be added as free sample |
| `sample_sku` | string | Optional separate SKU for sample fulfillment. If blank, derived as "SAMPLE-{sku}" |

**Validation Rules:**
- `sample_eligible` defaults to `false`
- `sample_sku` is optional (derived via `effective_sample_sku` method)

---

## Entity Relationships

```
┌─────────────────┐
│    Category     │
└────────┬────────┘
         │ has_many
         ▼
┌─────────────────┐
│    Product      │
└────────┬────────┘
         │ has_many
         ▼
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│ ProductVariant  │──────▶│    CartItem     │──────▶│   OrderItem     │
│ sample_eligible │       │    price: 0     │       │    price: 0     │
│ sample_sku      │       │   quantity: 1   │       │   quantity: 1   │
└─────────────────┘       └────────┬────────┘       └────────┬────────┘
         │                         │                         │
         │                         │ belongs_to              │ belongs_to
         │                         ▼                         ▼
         │                ┌─────────────────┐       ┌─────────────────┐
         │                │      Cart       │       │     Order       │
         │                │ + sample_items  │       │ + with_samples  │
         │                │ + sample_count  │       │ + contains_samples?
         │                │ + only_samples? │       │ + sample_request?
         │                │ + at_sample_limit?      └─────────────────┘
         │                └─────────────────┘
         │
    scope: sample_eligible
         │
         ▼
┌─────────────────┐
│ SamplesController│
│ (reads variants) │
└─────────────────┘
```

---

## Model Methods

### ProductVariant (Additions)

```ruby
# Scope
scope :sample_eligible, -> { where(sample_eligible: true) }

# Method
def effective_sample_sku
  sample_sku.presence || "SAMPLE-#{sku}"
end
```

### Cart (Additions)

```ruby
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
```

### Order (Additions)

```ruby
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
```

---

## Sample Detection Logic

### Cart Context

| Scenario | `sample_count` | `only_samples?` | Shipping |
|----------|----------------|-----------------|----------|
| Empty cart | 0 | false | N/A |
| 1 sample only | 1 | true | £7.50 flat |
| 5 samples only | 5 | true | £7.50 flat |
| 1 sample + 1 paid | 1 | false | Standard options |
| 3 samples + 2 paid | 3 | false | Standard options |

### Order Context

| Scenario | `contains_samples?` | `sample_request?` | Badge |
|----------|---------------------|-------------------|-------|
| Regular order | false | false | None |
| Sample-only order | true | true | "Samples Only" |
| Mixed order | true | false | "Contains Samples" |

---

## Migration

```ruby
class AddSampleFieldsToProductVariants < ActiveRecord::Migration[8.0]
  def change
    add_column :product_variants, :sample_eligible, :boolean, default: false, null: false
    add_column :product_variants, :sample_sku, :string

    add_index :product_variants, :sample_eligible
  end
end
```

**Migration Properties:**
- Reversible: Yes (uses `add_column`)
- Data migration: None required (new columns have safe defaults)
- Index: Added for query performance on `sample_eligible` scope

---

## Data Invariants

1. **Sample limit**: Cart cannot contain more than 5 sample items (enforced in controller)
2. **No duplicate samples**: Same variant cannot be added twice as sample (enforced in controller)
3. **Sample price**: Sample cart/order items always have `price = 0`
4. **Sample quantity**: Sample items always have `quantity = 1`
5. **Active variants only**: Only `active: true` variants appear on samples page
6. **Eligibility required**: Only `sample_eligible: true` variants can be added as samples
