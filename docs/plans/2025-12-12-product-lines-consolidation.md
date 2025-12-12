# Product Consolidation (Simple Approach)

## Overview

Consolidate multiple related products into single configurable pages. Inspired by [BrandYour.co](https://brandyour.co/) - one product page per category with options for all variants.

**Goal:** Fewer pages, better UX, concentrated SEO. No new database tables.

## Approach

Use existing Product + ProductVariant models. Each consolidated "page" is a single Product with variants containing structured `option_values` for the configurator.

**Example:** Instead of 9 napkin products → 1 "Napkins" product with 12 variants.

## Data Model

**No schema changes.** Uses existing:
- `Product` - one per consolidated page
- `ProductVariant` - one per purchasable option
- `ProductVariant#option_values` (JSONB) - stores tier/size/colour/style

### Variant option_values structure

```json
{
  "tier": "Classic",
  "size": "Cocktail",
  "colour": "White",
  "material": "Paper 2-ply"
}
```

The configurator reads these to build dynamic selectors.

## Configurator UX

### Flow

1. **Select first option** (e.g., Size or Material - depends on product)
2. **Select remaining options** - dynamically filtered based on available variants
3. **Quantity & Add to Cart**

### Pricing Display

Show both: "£46.64 (9.3p each)"

### Default State

Nothing pre-selected. Price shows "Select options" until complete.

### Dynamic Filtering

Prevents invalid combinations:
- Only shows options that exist in variant data
- Updates available choices as user makes selections
- Handles sparse matrices (e.g., Red/White straw only in 8x200)

---

## Napkins Implementation

### Current State (9 products)

| Slug | Material | Size | Colours |
|---|---|---|---|
| paper-cocktail-napkins | Paper 2-ply | 24cm | White, Black |
| airlaid-cocktail-napkins | Airlaid | 23cm | White |
| bamboo-cocktail-napkins | Bamboo | 25cm | Natural |
| paper-dinner-napkins | Paper 2-ply | 40cm | White, Black |
| premium-dinner-napkins | Paper 3-ply | 40cm | White, Black |
| airlaid-napkins | Airlaid | 40cm | White, Black |
| airlaid-pocket-napkins | Airlaid Pocket | 40cm | White |
| paper-napkins | Paper 1-ply | 33cm | White |

### Target State (1 product)

**Product:** Napkins
**Slug:** `napkins`
**URL:** `/products/napkins`

**Variants (12 total):**

| option_values | SKU | Price | Pack |
|---|---|---|---|
| `{size: "Cocktail", material: "Paper", colour: "White"}` | PCNWH | £28.79 | 2000 |
| `{size: "Cocktail", material: "Paper", colour: "Black"}` | PCNBL | £28.79 | 2000 |
| `{size: "Cocktail", material: "Airlaid", colour: "White"}` | AIRCNWH | £78.59 | 2400 |
| `{size: "Cocktail", material: "Bamboo", colour: "Natural"}` | BB-BOX-NAP | £40.80 | 2400 |
| `{size: "Dinner", material: "Paper 2-ply", colour: "White"}` | 4FDINWH | £51.76 | 2000 |
| `{size: "Dinner", material: "Paper 2-ply", colour: "Black"}` | 4FDINBL | £68.21 | 2000 |
| `{size: "Dinner", material: "Paper 3-ply", colour: "White"}` | 8FDINWH | £53.82 | 2000 |
| `{size: "Dinner", material: "Paper 3-ply", colour: "Black"}` | 8FDINBL | £53.82 | 2000 |
| `{size: "Dinner", material: "Airlaid", colour: "White"}` | 8FAIRWH | £46.74 | 500 |
| `{size: "Dinner", material: "Airlaid", colour: "Black"}` | 8FAIRBL | £63.79 | 500 |
| `{size: "Dinner", material: "Airlaid Pocket", colour: "White"}` | APIN-8-W | £46.64 | 500 |
| `{size: "Dispenser", material: "Paper 1-ply", colour: "White"}` | 33-1-NAP | £32.81 | 5000 |

### Configurator Flow

```
Step 1: Select Size
┌─────────────┬─────────────┬─────────────┐
│ Cocktail    │ Dinner      │ Dispenser   │
│ 23-25cm     │ 40cm        │ 33cm        │
└─────────────┴─────────────┴─────────────┘

Step 2: Select Material (filtered by size)
Cocktail → Paper | Airlaid | Bamboo
Dinner → Paper 2-ply | Paper 3-ply | Airlaid | Airlaid Pocket
Dispenser → Paper 1-ply (auto-selected)

Step 3: Select Colour (filtered by size + material)
Most → White | Black
Bamboo → Natural (auto-selected)
Dispenser → White (auto-selected)

Step 4: Quantity & Add to Cart
```

---

## Straws Implementation

### Current State (3 products, 12 variants)

| Slug | Material | Sizes | Colours |
|---|---|---|---|
| paper-straws | Paper | 6x150, 6x200, 8x200 | White, Black, Red/White (8x200 only) |
| bio-fibre-straws | Bio Fibre | 6x150, 6x200 | Black, Natural |
| bamboo-pulp-straws | Bamboo | 6x150, 6x200, 8x200, 10x200 | Natural |

### Target State (1 product)

**Product:** Straws
**Slug:** `straws`
**URL:** `/products/straws`

**Configurator Flow:**

```
Step 1: Select Material
┌─────────────┬─────────────┬─────────────┐
│ Paper       │ Bio Fibre   │ Bamboo      │
│ Classic     │ Premium     │ Eco         │
└─────────────┴─────────────┴─────────────┘

Step 2: Select Size (filtered by material)
Paper → 6x150 | 6x200 | 8x200
Bio Fibre → 6x150 | 6x200
Bamboo → 6x150 | 6x200 | 8x200 | 10x200

Step 3: Select Colour (filtered by material + size)
Paper 6x150/6x200 → White | Black
Paper 8x200 → Red/White
Bio Fibre → Black | Natural
Bamboo → Natural (auto-selected)

Step 4: Quantity & Add to Cart
```

---

## Implementation Steps

1. **Create new consolidated Product** with all variants merged
2. **Set option_values** on each variant with structured tier/size/material/colour
3. **Build configurator component** that reads option_values and filters dynamically
4. **Update product page template** to detect consolidated products and render configurator
5. **Deactivate old products** (set `active: false`)
6. **Test** all variant paths work correctly

## Benefits

- **No new tables** - uses existing Product/Variant models
- **Ship faster** - configurator is view logic, not data architecture
- **BrandYour-style UX** - clean, simple, one page per category
- **Easy to extend** - add more categories by creating consolidated products

## Trade-offs

- **Larger variant count per product** - manageable (12-15 variants)
- **Admin editing** - one product with many variants vs many products
- **Mixed pack sizes** - display needs to handle 500 vs 2000 packs clearly
