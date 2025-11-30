# Feature Specification: Sample Pack

**Version**: 1.0.0
**Status**: Approved
**Date**: 2025-11-30
**Design Document**: [docs/plans/2025-11-30-sample-pack-design.md](../../docs/plans/2025-11-30-sample-pack-design.md)

## Summary

Enable site visitors to request a free sample pack of eco-friendly products, paying only for shipping. The sample pack integrates with the existing cart and checkout flow as a £0.00 product.

## User Stories

### US-1: Add Sample Pack to Cart

**As a** site visitor
**I want to** add a sample pack to my cart
**So that** I can try Afida's eco-friendly products before making a larger purchase

**Acceptance Criteria:**
- Sample pack appears on dedicated `/samples` landing page
- Sample pack has its own product page at `/products/sample-pack`
- Clicking "Add to Cart" adds the sample pack as a £0.00 line item
- Quantity is always 1 (no quantity selector shown)
- Price displays as "Free — just pay shipping" instead of £0.00

### US-2: Limit Sample Pack Quantity

**As a** business owner
**I want to** limit sample packs to one per order
**So that** I prevent abuse while still allowing genuine sampling

**Acceptance Criteria:**
- Only one sample pack can be added per order
- If visitor tries to add a second, show flash message: "Sample pack already in your cart"
- Server-side validation prevents more than 1 sample pack in any cart

### US-3: Mix Samples with Products

**As a** site visitor
**I want to** add the sample pack alongside regular products in my cart
**So that** I can sample new items while ordering products I already know

**Acceptance Criteria:**
- Sample pack can coexist with regular paid products in the same cart
- Checkout flow works unchanged (shipping calculated, VAT applied to paid items)
- Order confirmation shows sample pack as £0.00 line item

### US-4: Exclude Sample Pack from Shop

**As a** business owner
**I want to** keep the sample pack out of the main shop listings
**So that** the shop remains focused on sellable products

**Acceptance Criteria:**
- Sample pack does not appear on `/shop` page
- Sample pack does not appear in category listings
- Sample pack is only discoverable via `/samples` page or direct URL

## Functional Requirements

### FR-1: Product Model Extensions

- Add constant `SAMPLE_PACK_SLUG = "sample-pack"` to Product model
- Add `sample_pack?` instance method returning `slug == SAMPLE_PACK_SLUG`
- Add `shoppable` scope excluding sample pack from listings

### FR-2: Cart Validation

- Add `has_sample_pack?` method to Cart model
- Add validation preventing more than 1 sample pack per cart
- Add controller check redirecting with flash if sample pack already in cart

### FR-3: UI Modifications

- Hide quantity selector on sample pack product page
- Display "Free — just pay shipping" instead of £0.00 price
- Show "Free" in cart line item for sample pack

### FR-4: Samples Landing Page

- Update existing `/samples` page with marketing content
- Load sample pack product and display add-to-cart CTA
- Graceful fallback if sample pack product doesn't exist

## Non-Functional Requirements

### NFR-1: Performance

- `has_sample_pack?` query must use efficient SQL (exists? check)
- No N+1 queries when displaying cart with sample pack

### NFR-2: SEO

- Samples landing page must have proper meta tags
- Sample pack product page must have canonical URL

## Out of Scope

- Lifetime "one per customer" tracking
- Special order type or status for sample orders
- Automated "what's in the box" list
- Sample-specific email templates
- Analytics tracking beyond standard orders

## Success Criteria

- Site visitors can add sample pack to cart and checkout
- Sample pack quantity limited to 1 per order (enforced)
- Sample pack excluded from shop listings
- Both landing page and product page functional
- All existing checkout functionality unchanged
