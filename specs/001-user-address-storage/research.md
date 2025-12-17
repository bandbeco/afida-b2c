# Research: User Address Storage

**Feature**: 001-user-address-storage
**Date**: 2025-12-17
**Status**: Complete

## Research Questions Resolved

### 1. Address Storage Architecture

**Decision**: Separate `addresses` table (not JSONB on users)

**Rationale**:
- Cleaner queries and easier indexing for "pick one of many" pattern
- Standard Rails conventions with `has_many` association
- Unlimited addresses per user without schema changes
- Simpler validation and default handling per-record

**Alternatives Considered**:
- JSONB column on users table: Simpler schema but awkward for multiple addresses, harder to query/index, no per-address callbacks

### 2. Billing vs Delivery Addresses

**Decision**: Delivery addresses only

**Rationale**:
- Stripe Checkout already collects billing address as part of card payment
- User's stated pain point was re-entering shipping address, not billing
- Reduces complexity without losing functionality
- Can add billing later if B2B customers need separate invoice addresses

**Alternatives Considered**:
- Separate billing and delivery: More complex, addresses a problem Stripe already solves
- Billing = Delivery with checkbox: Adds UI complexity without clear benefit

### 3. Number of Addresses Per User

**Decision**: Multiple addresses with one default

**Rationale**:
- B2B customers (restaurants, cafes) often ship to different locations
- Default address provides convenience for repeat orders
- "Set as default" is simple UX pattern

**Alternatives Considered**:
- Single address: Too limiting for B2B use case
- Multiple without default: Less convenient, requires selection every time

### 4. Address Selection UI

**Decision**: Modal on checkout click (not inline on cart page)

**Rationale**:
- Keeps cart page focused on items/totals
- Quick interaction without page navigation
- Consistent with cart drawer pattern already in use
- Easy to show "Use saved" vs "Enter new" options

**Alternatives Considered**:
- Inline on cart page: Clutters cart, especially with multiple addresses
- Intermediate page: Extra page load, slower checkout flow

### 5. Post-Checkout Address Save

**Decision**: Prompt on confirmation page (not auto-save)

**Rationale**:
- User control over what gets saved
- Simple UX: just need nickname to save
- Only shown when address is new (fuzzy match on line1 + postcode)
- Respects user privacy (not all addresses should be saved)

**Alternatives Considered**:
- Auto-save all addresses: Privacy concerns, accumulates unwanted addresses
- Account settings only: Misses natural opportunity at checkout completion

### 6. Address Fields

**Decision**: UK-focused B2B fields

| Field | Required | Rationale |
|-------|----------|-----------|
| nickname | Yes | Identify addresses in lists ("Office", "Warehouse") |
| recipient_name | Yes | Who receives the delivery |
| company_name | No | B2B customers need company for business premises |
| line1 | Yes | Street address |
| line2 | No | Apt, unit, floor |
| city | Yes | Standard address component |
| postcode | Yes | UK delivery requirement |
| phone | No | Courier contact (helpful but not required) |
| country | Yes | Hardcoded to GB (UK-only shipping) |
| default | Yes | Boolean for default selection |

**Alternatives Considered**:
- County field: Not required for UK postal delivery
- Full international: Out of scope (UK-only shipping)

### 7. Stripe Checkout Prefill

**Decision**: Use `customer_details` parameter

**Rationale**:
- Stripe Checkout accepts prefilled address via `customer_details.address`
- User can still edit in Stripe (confirmation step)
- Company name concatenated into line2 (Stripe limitation)
- Phone passed when available

**Research Source**: Stripe Checkout Session API documentation

```ruby
session_params[:customer_details] = {
  address: {
    line1: address.line1,
    line2: [address.company_name, address.line2].compact.join(", ").presence,
    city: address.city,
    postal_code: address.postcode,
    country: address.country
  },
  name: address.recipient_name,
  phone: address.phone
}
```

### 8. Default Address Assignment on Delete

**Decision**: Oldest remaining address becomes default

**Rationale**:
- Deterministic behavior (no user surprise)
- Oldest address likely most established/primary
- Simple to implement with `created_at` ordering

**Alternatives Considered**:
- Most recently used: Requires tracking usage, adds complexity
- No default until manually set: Poor UX for users who had a default

## Technology Decisions

### Stimulus Controller for Modal

**Decision**: New `checkout-address` Stimulus controller

**Rationale**:
- Follows existing codebase patterns
- Handles radio selection, form submission
- Lazy-loaded via existing controller registration pattern
- No external dependencies

### Routes

**Decision**: Nested under `account` namespace

```ruby
namespace :account do
  resources :addresses, except: [:show] do
    member do
      patch :set_default
    end
    collection do
      post :create_from_order
    end
  end
end
```

**Rationale**:
- Consistent with existing account structure
- RESTful with additional actions for specific needs
- `create_from_order` handles post-checkout save flow

## Design Document Reference

Full design details including wireframes available at:
`docs/plans/2025-12-17-user-address-storage.md`

## Open Questions

None - all questions resolved through brainstorming session.
