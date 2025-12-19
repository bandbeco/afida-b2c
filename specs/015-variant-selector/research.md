# Research: Unified Variant Selector

**Feature**: 015-variant-selector
**Date**: 2025-12-18

## Research Summary

All technical unknowns have been resolved through codebase analysis. The existing patterns provide clear guidance for the unified implementation.

---

## Decision 1: Stimulus Controller Architecture

**Decision**: Create single `variant_selector_controller.js` combining patterns from both existing controllers.

**Rationale**:
- `product_options_controller.js` handles 2-option products with button selection
- `product_configurator_controller.js` handles sparse matrices with dynamic filtering
- Both use identical variant matching logic and cart submission patterns
- Unified controller eliminates 400+ lines of duplicate code

**Alternatives Considered**:
- Keep both controllers with shared module → Rejected (still two entry points to maintain)
- Abstract base class → Rejected (over-engineering for Stimulus patterns)

---

## Decision 2: Accordion UI Implementation

**Decision**: Use DaisyUI collapse component with radio button state management (same as branded configurator).

**Rationale**:
- Pattern already proven in `branded_configurator_controller.js`
- Radio buttons with shared `name` attribute handle mutual exclusion automatically
- CSS transitions handled by DaisyUI without custom JavaScript
- Step indicators with checkmarks already implemented

**Implementation Pattern**:
```html
<div class="collapse collapse-arrow bg-base-100 border border-base-300">
  <input type="radio" name="variant-accordion" />
  <div class="collapse-title">
    <span class="step-indicator">①</span> Select Size
  </div>
  <div class="collapse-content">
    <!-- Option buttons -->
  </div>
</div>
```

**Alternatives Considered**:
- Custom accordion with JavaScript state → Rejected (reinventing DaisyUI)
- Details/summary HTML elements → Rejected (less styling control)

---

## Decision 3: Natural Sort Algorithm

**Decision**: Use JavaScript natural sort with numeric prefix extraction.

**Rationale**:
- PostgreSQL `naturally_sorted` scope exists but is for database queries
- Frontend needs JavaScript sorting for dynamic option value display
- Pattern handles all current size formats: "8oz", "12oz", "6x140mm", "10"", etc.

**Implementation**:
```javascript
naturalSort(values) {
  return [...values].sort((a, b) => {
    const aNum = parseInt(a.match(/^\d+/)?.[0] || '0')
    const bNum = parseInt(b.match(/^\d+/)?.[0] || '0')
    if (aNum !== bNum) return aNum - bNum
    return a.localeCompare(b)
  })
}
```

**Alternatives Considered**:
- Server-side sorting only → Rejected (need dynamic re-sorting on filter)
- Third-party library (natural-sort) → Rejected (overkill for simple case)

---

## Decision 4: Option Data Source

**Decision**: Use existing `ProductVariant.option_values` JSONB column as single source of truth.

**Rationale**:
- Already denormalized on variants for performance
- Consolidated products already use this pattern
- No migration needed for option data structure
- ProductOption tables become unnecessary after migration

**Data Flow**:
```ruby
# Controller prepares data
@variants_json = @product.active_variants.map do |v|
  {
    sku: v.sku,
    price: v.price.to_f,
    pac_size: v.pac_size,
    option_values: v.option_values,
    pricing_tiers: v.pricing_tiers,
    image_url: variant_image_url(v)
  }
end
```

**Alternatives Considered**:
- Keep ProductOption tables as source → Rejected (duplicate data, N+1 queries)
- New options table design → Rejected (unnecessary complexity)

---

## Decision 5: Option Label Display

**Decision**: Use `ProductOptionValue.label` field for display, fall back to raw value.

**Rationale**:
- Label field already exists (added in migration 20251114124913)
- Allows "6x140mm" to display as "6 × 140mm" or similar
- Backward compatible - missing labels use raw value

**Implementation**:
```ruby
# Build label lookup in controller
@option_labels = {}
@product.product_options.each do |option|
  @option_labels[option.name] = option.values.each_with_object({}) do |ov, h|
    h[ov.value] = ov.label.presence || ov.value
  end
end
```

---

## Decision 6: Pricing Tier Storage

**Decision**: Add `pricing_tiers` JSONB column to `product_variants` table.

**Rationale**:
- Pricing is variant-specific (8oz cup has different tiers than 12oz)
- JSONB allows flexible tier structure without schema changes
- Nullable column provides graceful fallback to standard pricing
- Matches existing pattern of storing structured data on variants

**Schema**:
```json
[
  { "quantity": 1, "price": "16.00" },
  { "quantity": 3, "price": "14.50" },
  { "quantity": 5, "price": "13.00" }
]
```

**Alternatives Considered**:
- Separate pricing_tiers table → Rejected (over-normalized for simple lookup)
- Extend BrandedProductPrice table → Rejected (different pricing model)

---

## Decision 7: Cart Submission Pattern

**Decision**: Retain existing cart submission pattern unchanged.

**Rationale**:
- All current controllers use identical form submission
- CartItemsController already handles variant SKU + quantity
- No changes needed to cart or checkout flow
- Backward compatible with existing cart items

**Pattern**:
```html
<form action="/cart/cart_items" method="post">
  <input type="hidden" name="cart_item[variant_sku]" />
  <input type="hidden" name="cart_item[quantity]" />
</form>
```

---

## Decision 8: URL Parameter Handling

**Decision**: Support URL parameters for pre-selection and shareability.

**Rationale**:
- Existing controllers already implement this pattern
- Enables bookmarkable/shareable product configurations
- Improves SEO for specific variant pages
- Customer service can link to specific variants

**Implementation**:
```javascript
// On page load
loadFromUrlParams() {
  const params = new URLSearchParams(window.location.search)
  this.optionPriorityValue.forEach(optionName => {
    const value = params.get(optionName)
    if (value) this.selectOption(optionName, value)
  })
}

// On selection change
updateUrl() {
  const params = new URLSearchParams()
  Object.entries(this.selections).forEach(([k, v]) => params.set(k, v))
  history.replaceState({}, '', `?${params}`)
}
```

---

## Decision 9: Event Emission for Compatible Lids

**Decision**: Emit custom event when variant selection changes for downstream components.

**Rationale**:
- Compatible lids controller listens for variant changes
- Decouples selector from lid loading logic
- Existing pattern: `product-options:variant-changed`

**Implementation**:
```javascript
emitVariantChanged(variant) {
  this.dispatch('variant-changed', {
    detail: {
      variantId: variant?.id,
      size: variant?.option_values?.size,
      sku: variant?.sku
    }
  })
}
```

---

## Decision 10: Migration Strategy

**Decision**: Three-phase migration with rollback capability.

**Rationale**:
- Phase 1 (data): Populate option_values JSON from ProductOption tables
- Phase 2 (UI): Deploy unified selector, keep old tables
- Phase 3 (cleanup): Remove old controllers, views, tables after validation
- Each phase independently deployable and reversible

**Alternatives Considered**:
- Big bang migration → Rejected (too risky)
- Feature flag → Considered but likely unnecessary given phased approach

---

## Technology Best Practices Applied

### Stimulus Controller Patterns
- Use `static targets` for DOM references
- Use `static values` for data from server
- Lazy load controller via `lazyControllers` in application.js
- Emit events for cross-controller communication

### DaisyUI Accordion
- Radio inputs with shared `name` for mutual exclusion
- `collapse-arrow` class for indicator
- `collapse-content` auto-hides when unchecked
- Use `checked` attribute to control initial/programmatic state

### Rails Conventions
- Helper methods for view logic (natural sort, label lookup)
- Controller prepares data, view renders it
- Turbo-compatible form submission
- Fixtures for all test data

---

## Open Items

None - all technical decisions resolved.
