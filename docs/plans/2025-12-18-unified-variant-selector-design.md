# Unified Variant Selector Design

**Date:** 2025-12-18
**Status:** Draft

## Overview

Unify the standard product UI and consolidated product configurator into a single variant selector component with a consistent accordion-style interface.

## Goals

- Eliminate duplicate code (3 Stimulus controllers → 1)
- Consistent UX across all non-branded products
- Simplify data model (remove ProductOption tables)
- Prepare for future volume pricing tiers

## Scope

### In Scope

- Unify standard + consolidated products into one variant selector
- Migrate option data from `ProductOption` tables to `ProductVariant.option_values` JSON
- Add `pricing_tiers` JSONB column for future volume discounts
- Accordion-style UI with auto-collapse behavior

### Out of Scope

- Branded product configurator (stays separate - different pricing model)
- Compatible lids section (stays as separate component below selector)
- Quick-add modal (stays simpler, shares backend logic only)

## Data Model Changes

### Migrate to `option_values` JSON

**Before:** Standard products use three tables:
- `ProductOption` - defines options (Size, Colour)
- `ProductOptionValue` - defines values (8oz, 12oz, Red, Blue)
- `ProductOptionAssignment` - links variants to values

**After:** All products use `ProductVariant.option_values` JSON:
```json
{
  "size": "8oz",
  "colour": "White",
  "material": "Paper"
}
```

### Add Pricing Tiers

Add `pricing_tiers` JSONB column to `product_variants`:

```json
[
  { "quantity": 1, "price": "16.00" },
  { "quantity": 3, "price": "14.50" },
  { "quantity": 5, "price": "13.00" }
]
```

- `quantity` = number of packs
- `price` = price per pack at this tier
- When `pricing_tiers` is null/empty, fall back to `variant.price` with simple dropdown

### Tables to Remove (after migration)

- `product_options`
- `product_option_values`
- `product_option_assignments`

## UI Design

### Accordion Structure

```
┌─────────────────────────────────────────────────┐
│ ✓ Select Material : Paper                    ▲  │  ← Collapsed, shows selection
├─────────────────────────────────────────────────┤
│ ② Select Size                                ▼  │  ← Expanded, awaiting selection
│ ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐         │
│ │  8oz  │ │ 12oz  │ │ 16oz  │ │ 20oz  │         │
│ └───────┘ └───────┘ └───────┘ └───────┘         │
├─────────────────────────────────────────────────┤
│ ③ Select Quantity                            ▼  │
│   (disabled until size selected)                │
├─────────────────────────────────────────────────┤
│              [ Add to Cart ]                    │
└─────────────────────────────────────────────────┘
```

### Collapse Behavior

- Auto-collapse step when user makes a selection
- Header updates to show "✓ Select {option} : {value}"
- Next incomplete step auto-expands
- Clicking any header toggles that step open/closed
- Quantity step stays expanded until "Add to Cart" clicked

### Option Steps

**Step order (hardcoded priority):**
1. `material`
2. `type`
3. `size`
4. `colour`

Steps only appear if the product has variants with that option.

**Value sorting:**
- `size`: Natural sort (8oz → 12oz → 16oz, 6x140mm → 8x200mm)
- All others: Alphabetical

**Filtering:**
- Each selection filters available values in subsequent steps
- Unavailable combinations shown as disabled (greyed out)
- Auto-select if only one value available

### Quantity Step

**With pricing tiers:**

```
┌─────────────────────────────────────────────┐
│ 1 pack       £16.00/pack           £16.00   │
│ (100 units)  £0.160/unit                    │
├─────────────────────────────────────────────┤
│ 3 packs      £14.50/pack  save 9%  £43.50   │  ← Selected
│ (300 units)  £0.145/unit                    │
├─────────────────────────────────────────────┤
│ 5 packs      £13.00/pack  save 19% £65.00   │
│ (500 units)  £0.130/unit                    │
└─────────────────────────────────────────────┘
```

- Pack quantity as primary display
- Pack price and total price
- Unit count in smaller font
- Calculated unit price in smaller font (for comparison)
- Savings percentage vs single-pack price

**Without pricing tiers (fallback):**

```
┌─────────────────────────────────────────────┐
│  Quantity: [ 1 pack (100 units)      ▼ ]    │
│                                             │
│  £16.00 / pack                              │
└─────────────────────────────────────────────┘
```

## Backend Changes

### ProductsController#show

**Before:** Branching between standard and consolidated views

```ruby
if product.use_configurator?
  # consolidated logic
  render partial: 'consolidated_product'
else
  # standard logic
  render partial: 'standard_product'
end
```

**After:** Single path

```ruby
@options = @product.extract_options_from_variants
@variants_json = @product.variants_for_selector
render :show  # uses _variant_selector partial
```

### New Model Methods

**Product#extract_options_from_variants**

Returns options hash sorted by priority, values sorted appropriately:

```ruby
{
  material: ['Bamboo', 'Kraft', 'Paper'],  # alphabetical
  size: ['8oz', '12oz', '16oz']            # natural sort
}
```

**Product#variants_for_selector**

Returns variant data for frontend JavaScript:

```ruby
[
  {
    id: 123,
    sku: "CUP-PAPER-8OZ-WHITE",
    option_values: { material: "Paper", size: "8oz", colour: "White" },
    price: "16.00",
    pac_size: 100,
    pricing_tiers: [...],
    image_url: "/path/to/image.jpg"
  },
  ...
]
```

## Frontend Changes

### New Files

- `app/frontend/javascript/controllers/variant_selector_controller.js`
- `app/views/products/_variant_selector.html.erb`

### Stimulus Controller Data Attributes

```html
<div data-controller="variant-selector"
     data-variant-selector-variants-value="<%= @variants_json %>"
     data-variant-selector-options-value="<%= @options.to_json %>"
     data-variant-selector-priority-value='["material","type","size","colour"]'>
```

### Files to Remove (after migration complete)

- `app/frontend/javascript/controllers/product_options_controller.js`
- `app/frontend/javascript/controllers/product_configurator_controller.js`
- `app/views/products/_standard_product.html.erb`
- `app/views/products/_consolidated_product.html.erb`
- `app/views/products/_configurator.html.erb`
- `app/models/product_option.rb`
- `app/models/product_option_value.rb`
- `app/models/product_option_assignment.rb`

### Quick-Add Modal

Stays simple (no accordion). Uses inline buttons and quantity dropdown for speed. Shares backend variant-matching logic via shared helper methods.

## Migration Strategy

### Phase 1: Data Migration

1. Create rake task `product_options:migrate_to_json`
2. For each standard product variant:
   - Read assigned `ProductOptionValue` records
   - Write to `ProductVariant.option_values` JSON
3. Verify all variants have correct `option_values`
4. Keep old tables temporarily (rollback safety)

### Phase 2: Build Variant Selector

1. Create `variant_selector_controller.js`
2. Create `_variant_selector.html.erb` partial
3. Add model methods: `extract_options_from_variants`, `variants_for_selector`
4. Update `ProductsController#show` to use new partial
5. Test with both standard and consolidated products

### Phase 3: Cleanup

1. Remove old Stimulus controllers from `application.js` registration
2. Remove old view partials
3. Remove `ProductOption`, `ProductOptionValue`, `ProductOptionAssignment` models
4. Create migration to drop database tables
5. Update admin UI if needed

### Rollback Plan

- Phase 1 keeps old tables intact
- Phase 2 can be feature-flagged if needed
- Phase 3 only happens after production validation

## Testing Checklist

- [ ] Standard product with single option (size only) works
- [ ] Standard product with multiple options (size + colour) works
- [ ] Consolidated product with sparse matrix works
- [ ] Option filtering disables unavailable combinations
- [ ] Auto-select works when only one value available
- [ ] Accordion collapse/expand works correctly
- [ ] Header shows selection after collapse
- [ ] Quantity tiers display correctly (when present)
- [ ] Quantity dropdown fallback works (when no tiers)
- [ ] Natural sort works for sizes (8oz < 12oz < 16oz)
- [ ] Add to Cart creates correct cart item
- [ ] Product images update on variant selection
- [ ] Compatible lids section still works below selector

## Future Enhancements

- Add pricing tiers to standard products (business decision)
- Consider adopting accordion UI for quick-add modal
- Visual improvements inspired by BrandYour (selection badges)
