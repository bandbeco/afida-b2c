# Data Model: Sample Pack Feature

**Date**: 2025-11-30
**Status**: Complete

## Overview

No database schema changes required. The sample pack is implemented as a regular `Product` with a `ProductVariant`, using existing tables and relationships.

## Entity: Sample Pack Product

Uses existing `products` table.

| Field | Type | Value | Notes |
|-------|------|-------|-------|
| name | string | "Sample Pack" | Display name |
| slug | string | "sample-pack" | URL identifier, matches `SAMPLE_PACK_SLUG` constant |
| product_type | string | "standard" | Uses existing enum |
| category_id | bigint | nil | No category (excluded from listings via scope) |
| active | boolean | true | Visible on samples page |
| description_short | text | [Marketing copy] | For meta description |
| description_standard | text | [Marketing copy] | For product page |
| description_detailed | text | [Marketing copy] | What's included |
| sample_eligible | boolean | false | Unused for this product |
| meta_title | string | "Free Sample Pack" | SEO |
| meta_description | string | [Marketing copy] | SEO |

## Entity: Sample Pack Variant

Uses existing `product_variants` table.

| Field | Type | Value | Notes |
|-------|------|-------|-------|
| product_id | bigint | [sample_pack.id] | FK to product |
| name | string | "Sample Pack" | Display name |
| sku | string | "SAMPLE-PACK" | Unique identifier |
| price | decimal | 0.00 | Free product |
| pac_size | integer | 1 | Single pack |
| active | boolean | true | Available |
| stock_quantity | integer | 999 | Effectively unlimited |

## Model Additions

### Product Model (`app/models/product.rb`)

```ruby
# Constant for sample pack identification
SAMPLE_PACK_SLUG = "sample-pack".freeze

# Instance method to check if product is sample pack
def sample_pack?
  slug == SAMPLE_PACK_SLUG
end

# Scope to exclude sample pack from shop listings
scope :shoppable, -> {
  where(product_type: ["standard", "customizable_template"])
    .where.not(slug: SAMPLE_PACK_SLUG)
}
```

### Cart Model (`app/models/cart.rb`)

```ruby
# Check if cart contains sample pack
def has_sample_pack?
  cart_items.joins(product_variant: :product)
    .where(products: { slug: Product::SAMPLE_PACK_SLUG })
    .exists?
end

# Validation to limit sample pack quantity
validate :sample_pack_quantity_limit

private

def sample_pack_quantity_limit
  sample_pack_items = cart_items.select { |item|
    item.product_variant.product.sample_pack?
  }

  if sample_pack_items.sum(&:quantity) > 1
    errors.add(:base, "Only one sample pack allowed per order")
  end
end
```

## Relationships

```
Product (sample-pack)
    │
    └── ProductVariant (SAMPLE-PACK, £0.00)
            │
            └── CartItem (quantity: 1)
                    │
                    └── Cart
                            │
                            └── Order (via checkout)
```

## State Transitions

Sample pack follows standard product lifecycle:

1. **Available** → Product exists with `active: true`
2. **In Cart** → `CartItem` created with `quantity: 1`
3. **Checkout** → Standard Stripe Checkout flow
4. **Ordered** → `OrderItem` created with `price: 0.00`

No special states or transitions required.

## Validation Rules

| Entity | Rule | Implementation |
|--------|------|----------------|
| Cart | Max 1 sample pack | `sample_pack_quantity_limit` validation |
| CartItem | Quantity forced to 1 | UI hides selector; validation prevents > 1 |
| Product | Slug uniqueness | Existing slug validation |

## Indexes

No new indexes required. Existing indexes on `products.slug` and `cart_items.cart_id` are sufficient.

## Migration

**No migration required.** Sample pack product created manually via admin interface or seed data.

### Seed Data (optional)

```ruby
# db/seeds/sample_pack.rb (or in main seeds.rb)
sample_pack = Product.find_or_create_by!(slug: "sample-pack") do |p|
  p.name = "Sample Pack"
  p.product_type = "standard"
  p.category = nil
  p.active = true
  p.description_short = "Try our eco-friendly products before you buy"
  p.description_standard = "Get a curated selection of our best-selling eco-friendly catering supplies delivered to your door."
  p.description_detailed = "Our sample pack includes a selection of cups, lids, takeaway containers, napkins, and straws so you can evaluate our products before placing a larger order."
  p.meta_title = "Free Sample Pack - Try Before You Buy"
  p.meta_description = "Request a free sample pack of eco-friendly catering supplies. Just pay shipping."
end

sample_pack.variants.find_or_create_by!(sku: "SAMPLE-PACK") do |v|
  v.name = "Sample Pack"
  v.price = 0.00
  v.pac_size = 1
  v.active = true
  v.stock_quantity = 999
end
```

## Data Integrity

| Concern | Mitigation |
|---------|------------|
| Sample pack deleted | Code handles nil gracefully; landing page shows fallback |
| Slug changed | Constant `SAMPLE_PACK_SLUG` must be updated |
| Multiple sample packs | Slug uniqueness prevents this |
| Price changed from £0 | Business decision; code handles any price |
