# Feature Specification: Variant-Level Sample Request System

**Feature Branch**: `011-variant-samples`
**Created**: 2025-12-01
**Status**: Draft
**Input**: User description: "Allow visitors to select up to 5 specific product variants as free samples, checkout via Stripe with £7.50 flat shipping (or free when combined with paid products)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Browse and Select Samples (Priority: P1)

A visitor wants to try eco-friendly catering products before committing to a bulk purchase. They visit the samples page to browse available products by category and select specific variants to receive as free samples.

**Why this priority**: This is the core value proposition—enabling customers to "try before they buy" reduces purchase anxiety and increases confidence in product selection. Without sample browsing and selection, no other sample functionality delivers value.

**Independent Test**: Can be fully tested by visiting /samples, expanding a category, and clicking "Add Sample" on variant cards. Delivers immediate value by showing customers what samples are available.

**Acceptance Scenarios**:

1. **Given** a visitor on the samples page, **When** they view the page, **Then** they see all product categories that contain sample-eligible variants, displayed as clickable cards
2. **Given** a visitor viewing category cards, **When** they click "View Samples" on a category, **Then** the category expands inline to reveal all sample-eligible variants from that category
3. **Given** an expanded category showing variants, **When** the visitor clicks "Add Sample" on a variant card, **Then** the variant is added to their cart as a free sample item
4. **Given** a variant card for a sample already in the cart, **When** the visitor views that card, **Then** it shows "Added" with a checkmark and allows removal

---

### User Story 2 - Sample Limit Enforcement (Priority: P1)

Visitors are limited to 5 free samples per order to manage costs and prevent abuse while still providing value to prospective customers.

**Why this priority**: Without limit enforcement, the business could face significant costs from unlimited sample requests. This is essential for the feature to be commercially viable.

**Independent Test**: Can be tested by adding 5 samples, then attempting to add a 6th. The limit prevents abuse while still providing generous sampling opportunity.

**Acceptance Scenarios**:

1. **Given** a visitor with 4 samples in their cart, **When** they add a 5th sample, **Then** the sample is added successfully and a counter shows "5 of 5 samples selected"
2. **Given** a visitor with 5 samples in their cart, **When** they attempt to add another sample, **Then** the add button is disabled and shows "Limit Reached"
3. **Given** a visitor at the sample limit, **When** they remove a sample from their cart, **Then** they can add a different sample (the limit is recalculated)
4. **Given** a visitor with samples in their cart, **When** they view the samples page, **Then** a sticky counter shows how many samples they have selected out of 5

---

### User Story 3 - Samples-Only Checkout (Priority: P1)

A visitor who only wants to try samples before making a purchase can checkout with just samples, paying a flat £7.50 shipping fee.

**Why this priority**: This enables the core business model—customers can trial products with minimal commitment. The flat shipping fee covers handling costs.

**Independent Test**: Can be tested by adding only samples to cart and proceeding to checkout. The shipping fee appears correctly in the checkout flow.

**Acceptance Scenarios**:

1. **Given** a cart containing only sample items (no paid products), **When** the visitor proceeds to checkout, **Then** a single shipping option of £7.50 ("Sample Delivery") is presented
2. **Given** a samples-only checkout session, **When** the visitor views the cart summary, **Then** the items show as "Free" with "(Sample)" label and the total shows only the £7.50 shipping
3. **Given** a visitor completing samples-only checkout, **When** payment is successful, **Then** an order is created with the sample items and £7.50 shipping charge

---

### User Story 4 - Mixed Cart (Samples + Paid Products) (Priority: P2)

A visitor adds both samples and regular products to their cart. The samples ship free alongside the paid order.

**Why this priority**: This encourages customers to combine samples with purchases, potentially increasing order value while simplifying logistics.

**Independent Test**: Can be tested by adding both samples and regular products, then proceeding to checkout. Samples appear as free, and normal shipping options are presented.

**Acceptance Scenarios**:

1. **Given** a cart with both samples and paid products, **When** the visitor views the cart, **Then** samples show as "Free" and paid products show their normal prices
2. **Given** a mixed cart at checkout, **When** the visitor selects shipping, **Then** standard shipping options apply (not the £7.50 samples-only rate) and samples ship free with the order
3. **Given** a mixed cart order, **When** the order is completed, **Then** the order record identifies which items are samples vs. paid purchases

---

### User Story 5 - Admin Sample Management (Priority: P2)

Store administrators need to control which product variants are available as samples and track sample-containing orders.

**Why this priority**: Without admin controls, the business cannot manage inventory or adjust which products are sample-eligible. Essential for operations.

**Independent Test**: Can be tested by logging into admin, editing a variant's sample eligibility, and verifying it appears/disappears from the samples page.

**Acceptance Scenarios**:

1. **Given** an admin editing a product variant, **When** they toggle "Available as free sample", **Then** the variant becomes visible (or hidden) on the public samples page
2. **Given** an admin viewing the orders list, **When** orders contain samples, **Then** a badge indicates "Samples Only" or "Contains Samples"
3. **Given** an admin filtering orders, **When** they select "Samples Only" or "Contains Samples" filter, **Then** only matching orders are displayed
4. **Given** an admin viewing order details for a sample order, **When** they view line items, **Then** sample items are clearly labeled with their sample SKU

---

### User Story 6 - Cart Display for Samples (Priority: P3)

Samples appear distinctively in the cart so visitors understand they are free and part of their sample selection.

**Why this priority**: Important for user experience and clarity, but the core functionality works without distinctive styling.

**Independent Test**: Can be tested by adding samples to cart and visiting the cart page. Samples should be visually distinguishable from regular items.

**Acceptance Scenarios**:

1. **Given** a visitor viewing their cart with samples, **When** they look at sample line items, **Then** the price shows "Free" (not "£0.00") with a "(Sample)" label
2. **Given** a sample item in the cart, **When** the visitor views it, **Then** quantity controls are hidden (samples are always quantity 1)
3. **Given** a cart with both samples and paid items, **When** the visitor views totals, **Then** samples contribute £0 to the subtotal while still showing in the items list

---

### Edge Cases

- What happens when a visitor tries to add the same sample variant twice?
  - The system prevents duplicate samples; the button changes to "Added" status
- What happens when a sample-eligible variant is deactivated by admin while in a visitor's cart?
  - The cart item remains but will fail validation at checkout with a clear message
- What happens when a visitor has 5 samples and removes one, then tries to add two new ones?
  - Only one can be added; the limit is enforced per add action
- How does the system handle a cart that started as samples-only but then has a paid product added?
  - Shipping recalculates automatically; samples ship free with the paid order
- What if a product has multiple variants but only some are sample-eligible?
  - Only sample-eligible variants appear on the samples page; non-eligible variants of the same product do not appear

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow administrators to mark individual product variants as sample-eligible
- **FR-002**: System MUST provide a dedicated samples browsing page showing all sample-eligible variants organized by category
- **FR-003**: Visitors MUST be able to expand categories to view and select sample variants inline
- **FR-004**: System MUST enforce a maximum of 5 samples per cart
- **FR-005**: System MUST prevent adding duplicate sample variants to the same cart
- **FR-006**: Sample items MUST be added to cart with a price of £0
- **FR-007**: System MUST display samples with "Free" pricing and "(Sample)" label in cart views
- **FR-008**: System MUST apply £7.50 flat shipping for carts containing only samples
- **FR-009**: System MUST apply standard shipping (with samples shipping free) for mixed carts containing both samples and paid products
- **FR-010**: System MUST track sample-specific SKUs for inventory and fulfillment purposes
- **FR-011**: Admin MUST be able to filter orders by sample status (samples-only, contains-samples, standard)
- **FR-012**: Order views MUST clearly indicate sample items and their SKUs
- **FR-013**: Sample quantity controls MUST be hidden in cart (samples are fixed at quantity 1)
- **FR-014**: System MUST update sample count display in real-time when samples are added or removed

### Key Entities

- **ProductVariant**: Extended to include sample eligibility flag and optional sample-specific SKU
- **CartItem**: Represents a sample in the cart when linked to a sample-eligible variant with £0 price
- **Cart**: Tracks sample count and determines if cart is samples-only or mixed
- **Order**: Records which items were samples for fulfillment and reporting
- **OrderItem**: Preserves sample status and SKU at order time

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Visitors can browse available samples and add up to 5 to their cart in under 2 minutes
- **SC-002**: 95% of sample requests complete checkout successfully on first attempt
- **SC-003**: Sample-only orders correctly charge £7.50 shipping with 100% accuracy
- **SC-004**: Mixed orders correctly waive sample shipping charges with 100% accuracy
- **SC-005**: Administrators can identify sample-containing orders within 5 seconds using filters
- **SC-006**: Sample limit enforcement prevents 100% of attempts to add more than 5 samples
- **SC-007**: Visitors clearly understand which items are samples (evidenced by zero support tickets asking "why is this item £0?")

## Clarifications

### Session 2025-12-01

- Q: Should the system rate-limit repeat sample orders per customer? → A: No rate limiting - rely on £7.50 shipping cost as natural deterrent
- Q: Should checkout payment failure handling differ for samples-only orders? → A: Same as regular checkout - cart preserved, user can retry

## Assumptions

- Sample delivery timeframe is 3-5 business days (standard handling time for sample orders)
- No per-customer rate limiting for sample orders; the £7.50 shipping fee serves as a natural deterrent against abuse
- Samples are UK-only (aligns with existing shipping configuration)
- VAT does not apply to £0 sample items (only to the £7.50 shipping if applicable)
- Sample limit of 5 is per order, not per customer lifetime
- Sample-eligible variants must still be active to appear on the samples page
