# Research: Variant-Level Sample Request System

**Date**: 2025-12-01
**Feature**: 011-variant-samples

## Existing Codebase Patterns

### Database Schema Discovery

**ProductVariant fields (existing):**
- `sku` (string, unique)
- `price` (decimal)
- `name` (string)
- `active` (boolean)
- `pac_size` (integer, nullable)
- `option_values` (jsonb)
- Various dimensional fields

**Cart fields (existing):**
- `user_id` (optional)
- Uses `cart_items` association

**CartItem fields (existing):**
- `cart_id`, `product_variant_id`
- `quantity`, `price`
- `configuration` (jsonb, for branded products)
- `calculated_price` (for configured items)

**Order/OrderItem (existing):**
- Standard order fields with `stripe_session_id`
- `branded_order_status` enum for configured products

### Code Patterns Discovery

**Adding items to cart** (from `cart_items_controller.rb`):
- Standard products: `find_or_initialize_by` pattern with quantity accumulation
- Configured products: Always create new item with unit price
- Turbo Stream responses for both formats

**Checkout shipping** (from `checkouts_controller.rb` + `shipping.rb`):
- `Shipping.stripe_shipping_options` returns array of shipping rate data
- Standard: £5.00, Express: £10.00
- Uses `Shipping::ALLOWED_COUNTRIES` for UK-only

**Model scopes** (from `product_variant.rb`):
- `scope :active, -> { where(active: true) }`
- Delegate pattern for inheriting from parent product

---

## Research Decisions

### Decision 1: Sample Eligibility Storage

**Decision**: Add `sample_eligible` boolean and `sample_sku` string to `product_variants` table

**Rationale**:
- Variant-level control allows granular sample management (e.g., only certain sizes)
- Boolean with index enables efficient scope: `scope :sample_eligible, -> { where(sample_eligible: true) }`
- Optional `sample_sku` enables inventory tracking separate from regular SKU

**Alternatives considered**:
- Separate `samples` table: Rejected - adds unnecessary complexity for simple flag
- Product-level eligibility: Rejected - loses granularity for multi-variant products

### Decision 2: Cart Item Price Strategy for Samples

**Decision**: Samples use existing `cart_items` with `price: 0` and detection via `product_variant.sample_eligible?`

**Rationale**:
- Consistent with existing cart architecture (no new tables)
- Zero price integrates naturally with subtotal calculations
- Detection via variant flag avoids ambiguity with legitimately free items

**Alternatives considered**:
- New `sample_cart_items` table: Rejected - duplicates existing functionality
- `is_sample` boolean on cart_item: Rejected - derivable from variant + price

### Decision 3: Shipping Logic Integration

**Decision**: Extend `Shipping` module with `sample_only_shipping_option` and modify `CheckoutsController` to check `cart.only_samples?`

**Rationale**:
- Follows existing pattern of shipping options module
- Single conditional in checkout controller: `if cart.only_samples? then ... else ...`
- Sample-only shipping: £7.50 flat rate (750 pence)

**Alternatives considered**:
- Override entire shipping calculation: Rejected - too invasive
- New controller for sample checkout: Rejected - duplicates payment flow

### Decision 4: Samples Page Architecture

**Decision**: New `SamplesController` with Turbo Frame-based category expansion

**Rationale**:
- Turbo Frames enable lazy loading of variants per category (performance)
- Category cards initially collapsed; expand inline on click
- Consistent with existing Hotwire patterns in codebase

**Alternatives considered**:
- Modal-based selection: Rejected - poor UX for browsing multiple categories
- Full page per category: Rejected - disrupts browsing flow

### Decision 5: Sample Count Tracking

**Decision**: Real-time methods on `Cart` model: `sample_items`, `sample_count`, `only_samples?`, `at_sample_limit?`

**Rationale**:
- SQL-based counting via joins (efficient)
- Methods align with existing cart patterns (`items_count`, `subtotal_amount`)
- `SAMPLE_LIMIT = 5` constant on Cart model

**Alternatives considered**:
- Counter cache column: Rejected - complexity for rare feature
- Client-side counting: Rejected - must be server-authoritative for validation

### Decision 6: Admin UI Integration

**Decision**: Add fields to existing variant form; add badges/filters to orders index

**Rationale**:
- No new admin pages required
- Variant form: checkbox + text field in new "Sample Settings" section
- Order badges: "Samples Only" or "Contains Samples" via helper methods

**Alternatives considered**:
- Dedicated samples admin section: Rejected - overkill for simple config

### Decision 7: Order Sample Tracking

**Decision**: Add methods to `Order` model to detect samples: `contains_samples?`, `sample_request?`, and scope `with_samples`

**Rationale**:
- Detection via join to `product_variants.sample_eligible` + `order_items.price = 0`
- `sample_request?` = samples only; `contains_samples?` = has any samples
- Enables admin filtering and order type indicators

**Alternatives considered**:
- Store sample flag on order_items: Rejected - derivable from variant
- Order-level sample flag: Rejected - doesn't capture mixed orders

---

## Technical Approach Summary

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ ProductVariant  │     │    CartItem     │     │   OrderItem     │
│ + sample_eligible│────▶│   price: 0     │────▶│   price: 0      │
│ + sample_sku    │     │   quantity: 1   │     │   quantity: 1   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ SamplesController│     │     Cart        │     │     Order       │
│ - index          │     │ + sample_items  │     │ + with_samples  │
│ - category       │     │ + sample_count  │     │ + sample_request?│
└─────────────────┘     │ + only_samples? │     └─────────────────┘
                        │ + at_sample_limit?│
                        └─────────────────┘
                                │
                                ▼
                        ┌─────────────────┐
                        │ CheckoutsController│
                        │ + sample shipping │
                        │   (£7.50 flat)    │
                        └─────────────────┘
```

---

## Dependencies & Patterns

### Hotwire Patterns to Use

1. **Turbo Frame for category expansion**: `turbo_frame_tag "category_#{id}"` with lazy loading
2. **Turbo Stream for cart updates**: Replace variant card, counter, cart counter on add/remove
3. **Stimulus for UI state**: `category-expand` controller for chevron rotation, `sample-counter` for visibility

### Stripe Integration Points

1. **Shipping options**: Add sample-only option to `Shipping` module
2. **Line items**: £0 samples appear as free items in Stripe Checkout
3. **VAT**: Applied only to shipping for samples-only orders (per existing pattern)

### Test Patterns to Follow

1. **Model tests**: Scope tests for `sample_eligible`, method tests for cart/order helpers
2. **Controller tests**: Integration tests for sample add/remove/limit enforcement
3. **System tests**: Full E2E flow with Capybara for sample browsing → checkout
