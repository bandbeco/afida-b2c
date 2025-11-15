# Feature Specification: Quick Add to Cart

**Feature ID**: 005
**Branch**: `005-quick-add-to-cart`
**Date**: 2025-01-15
**Status**: Draft

## User Story

**As a** returning customer browsing the shop or category pages
**I want to** add products to my cart without visiting the product detail page
**So that** I can quickly complete my shopping for familiar products

## Problem Statement

Currently, all add-to-cart actions require visiting the product detail page. For returning customers who know exactly what they want (e.g., "I need 5 packs of 12oz hot cups"), this creates unnecessary friction:

- Extra page load and navigation
- Slower checkout process for bulk/repeat orders
- Poor UX for mobile users with limited screen space

## Functional Requirements

### FR1: Quick Add Button on Product Cards
- Display "Quick Add" button on product cards (shop page and category pages)
- Button positioned at bottom of card, below price information
- Button only shown for standard products (product_type: "standard")
- Button hidden for customizable products (product_type: "customizable_template")
- Button disabled if product has no active variants

### FR2: Quick Add Modal
- Clicking "Quick Add" opens a modal overlay
- Modal is server-rendered via Turbo Frame (single shared instance)
- Modal displays:
  - Product name and thumbnail image
  - Variant selector (dropdown) if product has multiple variants
  - Quantity selector (dropdown) with multiples of pack size (1-10 packs)
  - Pack size indicator (e.g., "Pack size: 50 units")
  - Price preview that updates with variant/quantity changes
  - "Add to Basket" submit button
- Modal supports keyboard navigation (ESC to close, Tab navigation, focus trap)
- On mobile, modal displays as bottom-sheet (slides up from bottom)

### FR3: Add to Cart Behavior
- Submitting modal form adds item to cart
- If product+variant already exists in cart: increment quantity of existing line item
- If new product+variant: create new cart line item
- Modal closes on successful add
- Cart drawer auto-opens showing updated cart

### FR4: Progressive Enhancement
- If JavaScript is disabled, "Quick Add" button links to product detail page
- Feature gracefully degrades to standard product page flow

## Non-Functional Requirements

### NFR1: Performance
- Modal content loads in <500ms
- No N+1 queries when rendering product cards with Quick Add buttons
- Single shared modal reduces DOM weight (vs. per-card modal instances)
- Turbo Frame ensures server is source of truth for pricing/availability

### NFR2: Accessibility
- Keyboard navigation fully functional (ESC, Tab, Enter)
- Screen reader support for modal (aria-label, role="dialog")
- Focus trap within modal
- Focus returns to trigger button on modal close

### NFR3: Mobile Experience
- Touch-friendly button sizes (min 44x44pt)
- Bottom-sheet modal on mobile (slides up from bottom)
- Swipe-to-close gesture supported

### NFR4: Consistency
- Uses existing cart drawer controller and Turbo Stream responses
- Follows DaisyUI modal component patterns
- Reuses existing CartItemsController#create logic

## Success Criteria

### Measurable Outcomes
- Conversion rate: Increase add-to-cart from listing pages by 20%
- Time to first cart add: Reduce average time by 30%
- Cart abandonment: Maintain or reduce current rate
- Mobile usage: Quick Add used on mobile at similar rate to desktop

### Technical Success Criteria
- All system tests passing (quick add flow, keyboard nav, cart updates)
- No performance regression on shop page load time
- RuboCop and Brakeman passing
- Accessibility audit passing (WCAG 2.1 AA)

## Out of Scope

- Quick Add for customizable products (branded cups) - too complex for modal
- Multi-product bulk add (add multiple different products at once)
- Save for later / wishlist functionality
- Quick Add from search results (only shop/category pages)
- Product recommendations in modal

## User Flows

### Primary Flow: Single-Variant Product
1. User browses shop page
2. User clicks "Quick Add" on product card
3. Modal opens with quantity selector (variant pre-selected)
4. User selects quantity (e.g., "3 packs")
5. User clicks "Add to Basket"
6. Modal closes, cart drawer opens showing updated cart
7. User continues shopping or proceeds to checkout

### Alternate Flow: Multi-Variant Product
1. User browses category page
2. User clicks "Quick Add" on multi-variant product
3. Modal opens with variant selector + quantity selector
4. User selects variant (e.g., "12oz")
5. Price updates to reflect variant selection
6. User selects quantity (e.g., "2 packs")
7. User clicks "Add to Basket"
8. Modal closes, cart drawer opens showing updated cart

### Edge Case Flow: Product Already in Cart
1. User clicks "Quick Add" on product already in cart
2. Modal opens normally
3. User selects variant + quantity
4. User clicks "Add to Basket"
5. Quantity is incremented on existing cart line item (no duplicate)
6. Modal closes, cart drawer shows updated quantity

## Dependencies

- Existing cart system (Cart, CartItem models)
- Existing cart drawer controller (Stimulus)
- Existing CartItemsController#create logic
- Turbo Frame support (already in place)
- DaisyUI modal component

## Risks and Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Modal too slow on mobile | High | Medium | Use Turbo Frame with aggressive caching, monitor performance metrics |
| Accessibility issues | Medium | Low | Full keyboard nav + screen reader testing, WCAG 2.1 AA compliance |
| Cart state sync issues | High | Low | Reuse existing CartItemsController logic, comprehensive system tests |
| Users confused by modal | Low | Low | Clear "Quick Add" label, familiar modal pattern, user testing |

## Future Enhancements (Not in Scope)

- Quick Add from search results
- Quick view (expanded modal with full product details)
- Save for later / wishlist integration
- Multi-product quick add
- Quick Add for customizable products (simplified version)
