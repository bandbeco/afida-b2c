# Research: Sample Pack Feature

**Date**: 2025-11-30
**Status**: Complete
**Source**: Brainstorming session with stakeholder

## Research Summary

This feature was fully designed through an interactive brainstorming session. All technical decisions were made collaboratively and documented in the [design document](../../docs/plans/2025-11-30-sample-pack-design.md).

## Key Decisions

### 1. Sample Selection Model

**Decision**: Single "Sample Pack" product only (no individual sample selection)

**Rationale**:
- Simplest to launch and manage
- Validates demand before adding complexity
- Clear value proposition for customers
- Easy to curate pack contents

**Alternatives Considered**:
- Individual sample selection from `sample_eligible` products — rejected for v1 complexity
- Category-specific sample packs — deferred to future iteration

### 2. Checkout Flow

**Decision**: Cart-based flow with £0.00 product through existing Stripe Checkout

**Rationale**:
- Reuses 100% of existing infrastructure
- No special order handling required
- Shipping calculated through existing Stripe shipping options
- Order confirmation emails work unchanged

**Alternatives Considered**:
- Dedicated Stripe Checkout session for samples only — rejected (duplicates infrastructure)
- Simple form + Stripe Payment Link — rejected (less integrated experience)

### 3. Product Identification

**Decision**: Slug convention (`sample-pack`) with constant and helper method

**Rationale**:
- No database migration required
- Clean, readable code: `product.sample_pack?`
- Constant prevents magic strings: `Product::SAMPLE_PACK_SLUG`
- Easy to find and modify if slug changes

**Alternatives Considered**:
- Dedicated boolean field (`is_sample_pack`) — rejected (requires migration for single product)
- Reuse `sample_eligible` field — rejected (semantic mismatch)
- New product_type enum value — rejected (over-engineering for single product)

### 4. Quantity Limiting

**Decision**: 1 per order, enforced via model validation + friendly controller redirect

**Rationale**:
- Model validation ensures data integrity
- Controller check provides better UX ("already in cart" message)
- No lifetime tracking needed for v1

**Alternatives Considered**:
- Lifetime limit per customer/email — deferred to future if abuse detected
- No limits — rejected (potential for abuse)

### 5. Shop Visibility

**Decision**: `shoppable` scope excludes sample pack from listings

**Rationale**:
- Keeps shop focused on sellable products
- Single point of exclusion logic
- Explicit and easy to understand

**Alternatives Considered**:
- Null category — rejected (implicit behavior)
- Hidden category — rejected (adds unnecessary category management)
- `catalog_products` scope modification — considered but `shoppable` is more descriptive

### 6. Discovery Pages

**Decision**: Both dedicated landing page (`/samples`) and product page (`/products/sample-pack`)

**Rationale**:
- Landing page optimized for marketing campaigns and ads
- Product page provides consistent UX for organic discovery
- Both routes point to same product — flexibility without duplication

**Alternatives Considered**:
- Landing page only — rejected (breaks product page consistency)
- Product page only — rejected (loses marketing optimization opportunity)
- Redirect from one to other — rejected (loses flexibility)

## Existing Codebase Patterns

### Model Scopes (from `app/models/product.rb`)

```ruby
scope :catalog_products, -> { where(product_type: ["standard", "customizable_template"]) }
scope :quick_add_eligible, -> { where(product_type: "standard") }
```

The `shoppable` scope follows this established pattern.

### Cart Validation Pattern (from `app/models/cart.rb`)

Cart already has validations. Adding `sample_pack_quantity_limit` follows existing structure.

### Controller Guard Pattern (from `app/controllers/cart_items_controller.rb`)

Existing `create` action has early returns for error conditions. Sample pack check fits this pattern.

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| Rails | 8.x | Framework |
| PostgreSQL | 14+ | Database (no changes) |
| Stripe | Existing | Payment (unchanged) |
| TailwindCSS | 4 | Styling for landing page |
| DaisyUI | Existing | UI components |

## Outstanding Questions

None — all questions resolved during brainstorming session.

## Next Steps

1. Proceed to Phase 1: Data Model and Contracts
2. Generate tasks via `/speckit.tasks`
3. Implement following TDD workflow
