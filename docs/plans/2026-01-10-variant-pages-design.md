# Variant-Level Product Pages Design

**Date:** 2026-01-10
**Status:** Draft
**Author:** Laurent + Claude

## Summary

Replace consolidated product pages (one page with variant selector) with individual pages per SKU. Each ProductVariant becomes a standalone, purchasable page with its own URL.

## Problem Statement

The current variant selector approach:
- Reduces SEO surface area (fewer indexable URLs)
- Adds friction for customers who know what they want
- Doesn't match competitor patterns (causes owner discomfort)
- Over-engineers simple purchases (most products have 1-5 variants)

The selector works well for branded products (complex configuration) but is overkill for standard commodity products.

## Decision

- **Standard products:** One page per SKU, simple layout, no selector
- **Branded products:** Keep the guided configurator (unchanged)
- **Search:** Header search with Postgres full-text, filters on shop page

## URL Structure

**New pattern:**
```
/products/:variant-slug
```

**Examples:**
- `/products/8oz-single-wall-white-coffee-cup`
- `/products/12inch-pizza-box`
- `/products/dinner-4fold-2ply-black-napkin`

**Slug generation:**
Built from variant name + product name:
- `"single-wall 8oz white"` + `"Coffee Cups"` → `8oz-single-wall-white-coffee-cup`

## Page Layout

### Variant Page (`/products/:slug`)

```
┌─────────────────────────────────────────────────────┐
│ Breadcrumb: Home > Cups > 8oz Single Wall White    │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────┐    8oz Single Wall White          │
│  │             │    Coffee Cup                      │
│  │   PHOTO     │                                    │
│  │             │    £36.05 / pack (1,000 units)    │
│  └─────────────┘    SKU: 8WSW                      │
│                                                     │
│                     Short description here...       │
│                                                     │
│                     ┌─────────────────────┐        │
│                     │  Qty: [ 1 ▼ ]       │        │
│                     └─────────────────────┘        │
│                                                     │
│                     Total: £36.05                  │
│                                                     │
│                     [ Add to Cart ]                │
│                                                     │
│                     ✓ Delivered in 2-3 days        │
│                     ✓ Free delivery over £100      │
├─────────────────────────────────────────────────────┤
│ Product Details                                     │
│ Extended description...                             │
├─────────────────────────────────────────────────────┤
│ See Also: Other Coffee Cups                         │
│ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐                   │
│ │12oz │ │16oz │ │4oz  │ │DW   │                   │
│ │ SW  │ │ SW  │ │ SW  │ │12oz │                   │
│ └─────┘ └─────┘ └─────┘ └─────┘                   │
└─────────────────────────────────────────────────────┘
```

**Key elements:**
- Hero: Photo + title + price + SKU
- Purchase: Simple quantity dropdown (1, 2, 3, 5, 10) + Add to Cart
- Trust signals: Delivery info, free shipping threshold
- Details: Longer description, specs (dimensions, material)
- Related variants: Horizontal scroll of sibling variants from same product family

### Shop Page (`/shop`)

Shows all ~85 variants as individual cards with search and filters.

```
┌─────────────────────────────────────────────────────┐
│ Shop All                                            │
│                                                     │
│ ┌─────────────────────────────────────────────────┐│
│ │ Search: [________________] 🔍                   ││
│ │                                                 ││
│ │ Filters:                                        ││
│ │ Category: [All ▼]  Size: [All ▼]               ││
│ │ Colour: [All ▼]    Material: [All ▼]           ││
│ └─────────────────────────────────────────────────┘│
│                                                     │
│ Showing 85 products                                 │
│                                                     │
│ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐  │
│ │8oz  │ │12oz │ │16oz │ │4oz  │ │12oz │ │16oz  │  │
│ │SW W │ │SW W │ │SW W │ │SW W │ │DW K │ │DW W  │  │
│ │£36  │ │£42  │ │£52  │ │£33  │ │£39  │ │£50   │  │
│ └─────┘ └─────┘ └─────┘ └─────┘ └─────┘ └─────┘  │
└─────────────────────────────────────────────────────┘
```

**Filter behaviour:**
- Filters update URL params (`/shop?category=cups&size=8oz`)
- Turbo Frame updates results without full page reload
- Filters extracted from variant option values (no manual tagging)

### Category Pages (`/categories/:slug`)

Same card layout as shop, pre-filtered to that category.

## Search

### Header Search

- Search icon in header (expands on click, always visible on desktop)
- Type → instant dropdown with top 5 results
- Press enter or "View all" → `/shop?q=...` with full results + filters
- Mobile: full-screen search overlay

### Implementation

Postgres full-text search using tsvector.

**Indexed fields:**
- Variant name
- Variant SKU
- Product name
- Category name
- Colour, material

**Example queries:**

| User types | Finds |
|------------|-------|
| `8oz cup` | 8oz coffee cups, soup containers, ice cream cups |
| `kraft` | All kraft/brown products |
| `pizza` | All pizza box sizes |
| `8WSW` | Exact SKU match |
| `napkin black` | Black napkins |

**Implementation:**
```ruby
# ProductVariant
scope :search, ->(query) {
  joins(:product)
    .where("search_vector @@ plainto_tsquery('english', ?)", query)
}
```

## Data Model

### Changes

**ProductVariant gains one field:**

| Field | Type | Purpose |
|-------|------|---------|
| `slug` | string | URL identifier, unique, indexed |

**Slug generation:**
```ruby
before_validation :generate_slug, on: :create

def generate_slug
  base = "#{name} #{product.name}".parameterize
  self.slug = base
end
```

### Model Roles

- **Product** — Product family for grouping, shared content, Google Shopping `item_group_id`, compatible lids relationships
- **ProductVariant** — Primary purchasable entity with its own page

No other schema changes. Filters use existing `variant_option_values` join table.

## SEO

### Per-Variant SEO

| Element | Source |
|---------|--------|
| Title | `"8oz Single Wall White Coffee Cup \| Afida"` |
| Meta description | Variant-specific or inherited with interpolation |
| Canonical | Self-referencing |
| Structured data | `Product` schema with single `Offer` |

### Structured Data

```json
{
  "@type": "Product",
  "name": "8oz Single Wall White Coffee Cup",
  "sku": "8WSW",
  "offers": {
    "@type": "Offer",
    "price": "36.05",
    "priceCurrency": "GBP",
    "availability": "InStock"
  }
}
```

### Internal Linking

- "See also" links variants to siblings
- Category pages link to all variants
- Breadcrumbs: Home → Category → Variant

### Sitemap

Update `SitemapGeneratorService` to list variant URLs.

## Migration

### What Stays

- `Product` model (as grouping mechanism)
- `ProductVariant` model (gains slug)
- Branded product configurator (unchanged)
- Cart/checkout flow (already variant-based)
- Admin (minor tweaks)

### What Gets Deprecated

- `variant_selector_controller.js` for standard products
- Current `products/show.html.erb` accordion UI
- `@options`, `@variants_json` view setup for standard products

### New Files

- `app/views/product_variants/show.html.erb`
- `app/controllers/product_variants_controller.rb` (or extend existing)
- Search components (header + results)
- Filter components for shop page

### Routes

```ruby
# New
resources :product_variants, only: [:show], path: 'products'
# /products/:slug resolves to ProductVariant
```

## Out of Scope

- Meilisearch/Algolia (upgrade path if needed later)
- Changes to branded product configurator
- Changes to admin product management (beyond preview links)

## Success Criteria

1. Each variant has its own indexable URL
2. Shop page shows all variants with working search + filters
3. Header search returns relevant results instantly
4. "See also" section shows related variants
5. Google Shopping feed continues to work
6. Branded configurator unchanged
