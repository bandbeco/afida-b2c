# Product Consolidation (Simple Approach)

## Overview

Consolidate multiple related products into single configurable pages. Inspired by [BrandYour.co](https://brandyour.co/) - one product page per category with options for all variants.

**Goal:** Fewer pages, better UX, concentrated SEO. No new database tables.

## Approach

Use existing Product + ProductVariant models. Each consolidated "page" is a single Product with variants containing structured `option_values` for the configurator.

The `option_values` JSONB column on ProductVariant is the **single source of truth**. The existing ProductOption/ProductOptionValue tables can remain for admin UI hints but are not used by the configurator.

## Data Model

**No schema changes.** Uses existing:
- `Product` - one per consolidated page
- `ProductVariant` - one per purchasable option
- `ProductVariant#option_values` (JSONB) - stores size/material/colour

### Variant option_values structure

```json
{
  "size": "Cocktail",
  "material": "Paper",
  "colour": "White"
}
```

The configurator reads these to build dynamic selectors. Invalid combinations simply don't exist as variant records - no exclusion rules needed.

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
- Handles sparse matrices automatically (e.g., Red/White straw only in 8x200)

### Configurator Logic (Pseudocode)

```ruby
# Get all variants for this product
variants = product.variants.active

# Step 1: Show all unique materials
materials = variants.pluck("option_values->>'material'").uniq

# Step 2: User picks "Paper" - filter to Paper variants, show available sizes
paper_variants = variants.where("option_values->>'material' = ?", "Paper")
sizes = paper_variants.pluck("option_values->>'size'").uniq

# Step 3: User picks "8x200mm" - filter further, show available colours
paper_8x200_variants = paper_variants.where("option_values->>'size' = ?", "8x200mm")
colours = paper_8x200_variants.pluck("option_values->>'colour'").uniq
# → Returns ["Red & White"] only - auto-selected since it's the only choice
```

---

## Full Consolidation Plan

### Summary

| Category | Current | Consolidated To | Reduction |
|----------|---------|-----------------|-----------|
| Napkins | 8 slugs | 3 pages (by use case) | -5 |
| Straws | 3 slugs | 1 page | -2 |
| Wooden Cutlery | 4 slugs | 1 page | -3 |
| Pizza Boxes | 1 slug | 1 page | 0 |
| Ice Cream Cups | 1 slug | 1 page | 0 |
| Cup Carriers | 1 slug | 1 page | 0 |
| Coffee Stirrers | 1 slug | 1 page | 0 |

**Phase 1 (Do Now):** Napkins, Straws, Wooden Cutlery
**Phase 2 (Later):** Cups, Lids, Takeaway Containers (already sensibly split)

---

## Napkins Implementation (3 pages by use case)

### Why 3 Pages?

B2B customers think about **use case first**:
- "I need napkins for cocktail service"
- "I need napkins for dinner service"
- "I need napkins for our soft-serve machine"

### Current State (8 products)

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

### Target State (3 products)

#### 1. Cocktail Napkins

**Slug:** `cocktail-napkins`
**URL:** `/products/cocktail-napkins`

| option_values | SKU | Price | Pack |
|---|---|---|---|
| `{material: "Paper", colour: "White"}` | PCNWH | £28.79 | 2000 |
| `{material: "Paper", colour: "Black"}` | PCNBL | £28.79 | 2000 |
| `{material: "Airlaid", colour: "White"}` | AIRCNWH | £78.59 | 2400 |
| `{material: "Bamboo", colour: "Natural"}` | BB-BOX-NAP | £40.80 | 2400 |

**Configurator Flow:**
```
Step 1: Select Material
Paper (Budget) | Airlaid (Premium) | Bamboo (Eco)

Step 2: Select Colour (filtered)
Paper → White | Black
Airlaid → White (auto-selected)
Bamboo → Natural (auto-selected)
```

#### 2. Dinner Napkins

**Slug:** `dinner-napkins`
**URL:** `/products/dinner-napkins`

| option_values | SKU | Price | Pack |
|---|---|---|---|
| `{material: "Paper 2-ply", colour: "White"}` | 4FDINWH | £51.76 | 2000 |
| `{material: "Paper 2-ply", colour: "Black"}` | 4FDINBL | £68.21 | 2000 |
| `{material: "Paper 3-ply", colour: "White"}` | 8FDINWH | £53.82 | 2000 |
| `{material: "Paper 3-ply", colour: "Black"}` | 8FDINBL | £53.82 | 2000 |
| `{material: "Airlaid", colour: "White"}` | 8FAIRWH | £46.74 | 500 |
| `{material: "Airlaid", colour: "Black"}` | 8FAIRBL | £63.79 | 500 |
| `{material: "Airlaid Pocket", colour: "White"}` | APIN-8-W | £46.64 | 500 |

**Configurator Flow:**
```
Step 1: Select Material (quality-first)
Paper 2-ply (Budget) | Paper 3-ply (Standard) | Airlaid (Premium) | Airlaid Pocket (Luxury)

Step 2: Select Colour (filtered)
Paper 2-ply → White | Black
Paper 3-ply → White | Black
Airlaid → White | Black
Airlaid Pocket → White (auto-selected)
```

#### 3. Dispenser Napkins

**Slug:** `dispenser-napkins`
**URL:** `/products/dispenser-napkins`

| option_values | SKU | Price | Pack |
|---|---|---|---|
| `{material: "Paper 1-ply", colour: "White"}` | 33-1-NAP | £32.81 | 5000 |

**Simple product page** - no configurator needed (single variant).

---

## Straws Implementation (1 page)

### Current State (3 products, 13 variants)

| Slug | Material | Sizes | Colours |
|---|---|---|---|
| paper-straws | Paper | 6x150, 6x200, 8x200 | White, Black, Red/White (8x200 only) |
| bio-fibre-straws | Bio Fibre | 6x150, 6x200 | Black, Natural |
| bamboo-pulp-straws | Bamboo | 6x150, 6x200, 8x200, 10x200 | Natural |

### Target State (1 product)

**Slug:** `straws`
**URL:** `/products/straws`

| option_values | SKU | Price | Pack |
|---|---|---|---|
| `{material: "Paper", size: "6x150mm", colour: "White"}` | PS6150W | £X | Y |
| `{material: "Paper", size: "6x150mm", colour: "Black"}` | PS6150B | £X | Y |
| `{material: "Paper", size: "6x200mm", colour: "White"}` | PS6200W | £X | Y |
| `{material: "Paper", size: "6x200mm", colour: "Black"}` | PS6200B | £X | Y |
| `{material: "Paper", size: "8x200mm", colour: "Red & White"}` | PS8200RW | £X | Y |
| `{material: "Bio Fibre", size: "6x150mm", colour: "Black"}` | BB-FBRBL-15 | £69.56 | 2500 |
| `{material: "Bio Fibre", size: "6x150mm", colour: "Natural"}` | BB-FBRN-15 | £69.56 | 2500 |
| `{material: "Bio Fibre", size: "6x200mm", colour: "Black"}` | BB-FBRBL-20 | £78.62 | 2500 |
| `{material: "Bio Fibre", size: "6x200mm", colour: "Natural"}` | BB-FBRN-20 | £78.62 | 2500 |
| `{material: "Bamboo", size: "6x150mm", colour: "Natural"}` | BB-PULP-15 | £90.00 | 5000 |
| `{material: "Bamboo", size: "6x200mm", colour: "Natural"}` | BB-PULP-20 | £96.50 | 5000 |
| `{material: "Bamboo", size: "8x200mm", colour: "Natural"}` | BB-PULP-JUM | £150.49 | 5000 |
| `{material: "Bamboo", size: "10x200mm", colour: "Natural"}` | BB-PULP-10M | £147.00 | 3600 |

**Configurator Flow:**
```
Step 1: Select Material
Paper (Classic) | Bio Fibre (Premium) | Bamboo (Eco)

Step 2: Select Size (filtered by material)
Paper → 6x150mm | 6x200mm | 8x200mm
Bio Fibre → 6x150mm | 6x200mm
Bamboo → 6x150mm | 6x200mm | 8x200mm | 10x200mm

Step 3: Select Colour (filtered by material + size)
Paper 6x150/6x200 → White | Black
Paper 8x200 → Red & White (auto-selected)
Bio Fibre → Black | Natural
Bamboo → Natural (auto-selected)
```

---

## Wooden Cutlery Implementation (1 page)

### Current State (4 products)

| Slug | Type |
|---|---|
| wooden-forks | Fork |
| wooden-knives | Knife |
| wooden-spoons | Spoon |
| wooden-cutlery-kits | Kit (Fork + Knife + Napkin) |

### Target State (1 product)

**Slug:** `wooden-cutlery`
**URL:** `/products/wooden-cutlery`

**Configurator Flow:**
```
Step 1: Select Type
Fork | Knife | Spoon | Cutlery Kit
```

Simple single-option configurator.

---

## Implementation Steps

### Phase 1: Data Migration

1. Create new consolidated Product records
2. Move/copy variants to new products with structured `option_values`
3. Deactivate old products (`active: false`)

### Phase 2: Configurator Component

1. Build Stimulus controller for dynamic option filtering
2. Create partial for configurator UI
3. Detect consolidated products and render configurator instead of standard variant selector

### Phase 3: Testing

1. Test all variant paths in configurator
2. Verify sparse matrices handled correctly
3. Test add-to-cart flow

---

## Benefits

- **No new tables** - uses existing Product/Variant models
- **Ship faster** - configurator is view logic, not data architecture
- **BrandYour-style UX** - clean, simple, one page per category
- **Easy to extend** - add more categories by creating consolidated products
- **Sparse matrices handled** - variant records ARE the valid combinations

## Trade-offs

- **Larger variant count per product** - manageable (4-13 variants)
- **Admin editing** - one product with many variants vs many products
- **Mixed pack sizes** - display needs to handle 500 vs 5000 packs clearly
