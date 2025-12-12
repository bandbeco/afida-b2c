# Product Lines Consolidation

## Overview

Consolidate multiple related products into single configurable pages using a new ProductLine model. This simplifies customer navigation, reduces admin overhead, enables cross-selling, and concentrates SEO authority.

**Related:** This builds on top of the existing ProductOptions system (see `2025-10-22-product-consolidation.md`). ProductOptions handle variant attributes (size, colour) within a product. ProductLine groups multiple products into one configurable page.

## Data Model

### New Table: `product_lines`

| Column | Type | Purpose |
|---|---|---|
| `id` | bigint | Primary key |
| `name` | string | Display name ("Cocktail Napkins") |
| `slug` | string | URL slug (`cocktail-napkins`) |
| `description_short` | text | For category cards |
| `description_standard` | text | Above fold on page |
| `description_detailed` | text | Below fold on page |
| `meta_title` | string | SEO |
| `meta_description` | text | SEO |
| `category_id` | bigint | FK to categories |
| `active` | boolean | Published state |
| `created_at` | datetime | |
| `updated_at` | datetime | |

### New Table: `product_line_items`

Join model between ProductLine and Product.

| Column | Type | Purpose |
|---|---|---|
| `id` | bigint | Primary key |
| `product_line_id` | bigint | FK to product_lines |
| `product_id` | bigint | FK to products |
| `tier_label` | string | Display label ("Classic", "Premium") |
| `tier_description` | string | Short descriptor ("Paper 2-ply") |
| `sort_order` | integer | Display order within line |
| `created_at` | datetime | |
| `updated_at` | datetime | |

### Associations

```ruby
class ProductLine < ApplicationRecord
  belongs_to :category
  has_many :product_line_items, dependent: :destroy
  has_many :products, through: :product_line_items
end

class ProductLineItem < ApplicationRecord
  belongs_to :product_line
  belongs_to :product
end

class Product < ApplicationRecord
  has_many :product_line_items
  has_many :product_lines, through: :product_line_items
  # existing: has_many :variants
end
```

## Routing

Priority-based slug resolution in ProductsController:

1. Check `ProductLine` for slug → render configurable page template
2. Else check `Product` for slug → render standard product page template
3. Else 404

Existing standalone products continue to work unchanged.

## Category Pages

When a ProductLine exists for a category:
- The ProductLine appears as a single card (using its own name, description_short, photos)
- Member products are hidden from the category listing
- Standalone products (not in any ProductLine) appear normally

## Configurator UX

### General Flow

1. **Select Tier** - Cards showing tier_label, tier_description, price range
2. **Select Options** - Dynamic filtering based on selected product's available variants
3. **Quantity & Add to Cart**

### Pricing Display

Show both pack price and unit price: "£46.64 (9.3p each)"

### Default State

Nothing pre-selected. Price shows "Select options" or similar until all required selections made.

### Dynamic Filtering

Handles sparse variant matrices (not all size/colour combinations exist):
- Shows only valid options for current selections
- Updates available choices as user makes selections
- Prevents selection of non-existent variant combinations

---

## Napkins Implementation

### Product Lines to Create

| ProductLine | Slug | Category |
|---|---|---|
| Cocktail Napkins | `cocktail-napkins` | napkins |
| Dinner Napkins | `dinner-napkins` | napkins |
| Dispenser Napkins | `dispenser-napkins` | napkins |

### Cocktail Napkins (Configurable)

**URL:** `/products/cocktail-napkins`

**Member Products:**

| Product | Tier Label | Tier Description | Sort |
|---|---|---|---|
| Paper Cocktail Napkins | Classic | Paper 2-ply, 24cm | 1 |
| Airlaid Cocktail Napkins | Premium | Airlaid, 23cm | 2 |
| Bamboo Cocktail Napkins | Eco-Friendly | Bamboo Pulp, 25cm | 3 |

**Configurator Flow:**

```
Step 1: Select Type
┌─────────────────┬──────────────────┬─────────────────────┐
│ Classic         │ Premium          │ Eco-Friendly        │
│ Paper 2-ply     │ Airlaid          │ Bamboo Pulp         │
│ £28.79 (1.4p)   │ £78.59 (3.3p)    │ £40.80 (1.7p)       │
└─────────────────┴──────────────────┴─────────────────────┘

Step 2: Select Colour
- Classic/Premium: White | Black
- Eco-Friendly: Natural (auto-selected, no picker shown)

Step 3: Quantity & Add to Cart
```

### Dinner Napkins (Configurable)

**URL:** `/products/dinner-napkins`

**Member Products:**

| Product | Tier Label | Tier Description | Sort |
|---|---|---|---|
| Paper Dinner Napkins | Standard | 2-ply paper, 4-fold | 1 |
| Premium Dinner Napkins | Premium | 3-ply paper, 8-fold | 2 |
| Luxury Airlaid Napkins | Luxury Airlaid | Linen-feel, 8-fold | 3 |
| Airlaid Pocket Napkins | Luxury Airlaid Pocket | Linen-feel, cutlery pocket | 4 |

**Configurator Flow:**

```
Step 1: Select Quality Tier
┌─────────────────┬──────────────────┬─────────────────────┐
│ Standard        │ Premium          │ Luxury Airlaid      │
│ 2-ply paper     │ 3-ply paper      │ Linen-feel          │
│ £51.76 (2.6p)   │ £53.82 (2.7p)    │ £46.64 (9.3p)       │
└─────────────────┴──────────────────┴─────────────────────┘

Step 2: Select Colour
- All tiers: White | Black

Step 3: Select Style (Luxury Airlaid only)
- Classic Fold | Cutlery Pocket

Step 4: Quantity & Add to Cart
```

### Dispenser Napkins (Simple)

**URL:** `/products/dispenser-napkins`

**Type:** Simple product page (no configurator)

This is a ProductLine with a single member product, rendered as a standard product page.

**Product Details:**
- White 1-ply Paper, 33x33cm
- 4-fold
- £32.81 (0.7p each), 5000 pack

**Target Use Case:** Quick service, ice cream parlours, takeaway counters.

---

## Future Application: Straws

This model supports consolidating other product categories with varying option matrices.

**ProductLine:** "Straws" with slug `straws`

**Member Products:**

| Product | Tier Label | Available Sizes | Available Colours |
|---|---|---|---|
| Paper Straws | Classic | 6x150, 6x200, 8x200 | White, Black, Red/White (8x200 only) |
| Bio Fibre Straws | Premium | 6x150, 6x200 | Black, Natural |
| Bamboo Pulp Straws | Eco-Friendly | 6x150, 6x200, 8x200, 10x200 | Natural |

**Why this works:**
- Each member product retains its own variant matrix
- Configurator dynamically shows available options per selected type
- Handles sparse matrices (Red/White only in 8x200) via dynamic filtering

---

## Migration Steps

1. Create `product_lines` and `product_line_items` tables
2. Create ProductLine and ProductLineItem models with associations
3. Update routing to check ProductLine before Product
4. Create configurable product page template
5. Create ProductLine records for Cocktail, Dinner, Dispenser napkins
6. Create ProductLineItem records linking existing products with tier labels
7. Deactivate individual napkin products (set `active: false`) so they don't appear in category
8. Test category page shows 3 ProductLine cards instead of 9 product cards
9. Test configurator flow for each napkin type
