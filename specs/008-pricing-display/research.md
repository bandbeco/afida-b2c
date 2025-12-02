# Research: Pricing Display Consolidation

**Feature**: 008-pricing-display
**Date**: 2025-11-26

## Research Summary

This feature consolidates existing pricing display logic. Research focused on understanding current implementation patterns and making architectural decisions during brainstorming.

## Decision 1: Data Storage Strategy

**Question**: How should OrderItem store pricing data to support both pack and unit pricing display?

**Decision**: Store pack price (not unit price) in `price` column, add `pac_size` column to OrderItem.

**Rationale**:
- Pack price is the "source of truth" - it's what customers see on product pages
- Unit price can be derived: `pack_price / pac_size`
- Storing derived values (unit price) loses precision and context
- `pac_size` enables accurate display of "Pack of X" information

**Alternatives Considered**:
1. **Store unit price + add pac_size**: Requires multiplication to get pack price, potential rounding errors
2. **Store both prices**: Redundant data, risk of inconsistency
3. **Look up from product_variant at display time**: Breaks historical accuracy if variant changes

## Decision 2: Pricing Type Determination

**Question**: How should the system determine whether to display pack or unit pricing?

**Decision**: Use `pack_priced?` method: `!configured? && pac_size.present? && pac_size > 1`

**Rationale**:
- Branded/configured products are always unit-priced
- Standard products with pac_size > 1 are pack-priced
- pac_size of 1 or null treated as unit pricing (avoids "pack of 1" display)
- Simple boolean check, no database lookups required

**Alternatives Considered**:
1. **Separate `pricing_type` column**: Adds complexity, redundant with existing data
2. **Check product_variant.pac_size at runtime**: Breaks historical accuracy, adds query

## Decision 3: Centralization Approach

**Question**: Where should the pricing display logic live?

**Decision**: View helper (`PricingHelper#format_price_display`) + model methods for data access.

**Rationale**:
- Rails convention: formatting belongs in helpers
- Model methods (`pack_priced?`, `pack_price`, `unit_price`) encapsulate business logic
- Helper handles presentation (currency formatting, labels)
- Works with both CartItem and OrderItem (duck typing)

**Alternatives Considered**:
1. **Model-only (returns formatted string)**: Mixes presentation with business logic
2. **Presenter/Decorator class**: Over-engineering for this use case
3. **Partial with inline logic**: Current approach, creates duplication

## Decision 4: OrderItem.create_from_cart_item Changes

**Question**: How should the order creation flow change?

**Decision**: Modify to store `cart_item.price` (pack price) and `cart_item.product_variant.pac_size`.

**Current code**:
```ruby
price: cart_item.unit_price,  # Stores calculated unit price
```

**New code**:
```ruby
price: cart_item.price,                           # Store pack price
pac_size: cart_item.product_variant.pac_size,     # Store pack size
```

**Rationale**:
- Preserves historical pricing context
- Enables accurate display reconstruction
- No migration needed for existing orders (pac_size will be null, falls back to unit display)

## Decision 5: Backward Compatibility

**Question**: How should existing orders (if any) be handled?

**Decision**: Graceful degradation - orders without `pac_size` display as unit pricing.

**Rationale**:
- Site is not yet live, so no existing orders to migrate
- Design handles edge case defensively for future robustness
- No data migration required

## Decision 6: Price Format Specifications

**Question**: What precision and format should be used?

**Decision**:
- Pack price: 2 decimal places (e.g., "£15.99")
- Unit price: 4 decimal places (e.g., "£0.0320")
- Format: "£15.99 / pack (£0.0320 / unit)" or "£0.0320 / unit"

**Rationale**:
- Matches existing cart display
- 4 decimal places for unit price avoids misleading rounding (£0.03 vs £0.032)
- Clear labels prevent confusion

## Technical Research: Existing Codebase Patterns

### Current CartItem Implementation (working correctly)
- Uses `configured?` to distinguish branded vs standard
- Accesses `product_variant.pac_size` for pack information
- Inline conditional logic in `_cart_item.html.erb` (lines 37-49)

### Current OrderItem Implementation (needs fixing)
- Stores `cart_item.unit_price` - loses pack context
- No `pac_size` column
- Views show "£X.XX each" regardless of pricing type

### PDF Generator Pattern
- Uses `format_currency(item.price)` helper method
- Will need to use new `format_price_display` helper
- Prawn doesn't support HTML, so helper must return plain string

### Helper Pattern in Codebase
- Helpers in `app/helpers/` follow `{name}_helper.rb` convention
- `SeoHelper`, `ProductHelper`, `FaqHelper` exist as examples
- Helpers included automatically in views

## No External Research Required

This feature:
- Uses existing Rails patterns (helpers, migrations, model methods)
- No new gems or dependencies
- No external API integrations
- No complex algorithms

All decisions made during collaborative brainstorming session with user.
