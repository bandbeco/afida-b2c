# Feature Specification: Pricing Display Consolidation

**Feature Branch**: `008-pricing-display`
**Created**: 2025-11-26
**Status**: Draft
**Input**: User description: "Consolidate pricing display logic for standard (pack-priced) and branded (unit-priced) products across order confirmation pages, admin order views, and PDF summaries"

## Problem Statement

The application has two pricing models:
- **Standard products**: Priced per pack (e.g., "£15.99 for a pack of 500")
- **Branded products**: Priced per unit (e.g., "£0.032 per unit")

Currently, the order confirmation page, admin order views, and PDF order summaries display pricing incorrectly for standard products - showing a generic "£X.XX each" without distinguishing between pack and unit pricing. The cart already handles this correctly but with duplicated inline logic. This inconsistency confuses customers and staff reviewing orders.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Customer Views Order Confirmation (Priority: P1)

A customer completes a purchase containing standard pack-priced products. When viewing the order confirmation page, they should see pricing displayed in the same format as the cart - showing the pack price with the unit price breakdown.

**Why this priority**: This is the primary customer-facing touchpoint after purchase. Incorrect pricing display undermines trust and causes confusion about what they paid.

**Independent Test**: Can be fully tested by completing a checkout with standard products and verifying the order show page displays "£X.XX / pack (£X.XXXX / unit)" format.

**Acceptance Scenarios**:

1. **Given** a completed order with standard pack-priced products, **When** the customer views the order confirmation page, **Then** each line item displays the pack price with unit price breakdown (e.g., "£15.99 / pack (£0.0320 / unit)")

2. **Given** a completed order with branded unit-priced products, **When** the customer views the order confirmation page, **Then** each line item displays the unit price (e.g., "£0.0320 / unit")

3. **Given** a completed order with mixed product types, **When** the customer views the order confirmation page, **Then** each line item displays the appropriate pricing format for its product type

---

### User Story 2 - Admin Reviews Order Details (Priority: P2)

An administrator reviews customer orders in the admin panel. They need to see accurate pricing information to handle customer inquiries and verify order details.

**Why this priority**: Admin staff rely on accurate pricing data for customer service and order verification. Incorrect display causes operational confusion.

**Independent Test**: Can be fully tested by viewing an order in the admin panel and verifying pricing displays match the customer-facing format.

**Acceptance Scenarios**:

1. **Given** an order with standard pack-priced products, **When** an admin views the order in the admin panel, **Then** line items display pack price with unit breakdown

2. **Given** an order with branded products, **When** an admin views the order in the admin panel, **Then** line items display unit pricing

---

### User Story 3 - PDF Order Summary Generation (Priority: P3)

When an order summary PDF is generated (for printing or email attachment), the pricing should display correctly and consistently with the web views.

**Why this priority**: PDF summaries serve as permanent records. While less frequently viewed than web pages, they must be accurate for accounting and customer reference.

**Independent Test**: Can be fully tested by generating a PDF summary for an order and verifying pricing format matches web display.

**Acceptance Scenarios**:

1. **Given** an order with standard products, **When** a PDF summary is generated, **Then** pricing displays in pack format with unit breakdown

2. **Given** an order with branded products, **When** a PDF summary is generated, **Then** pricing displays in unit format

---

### User Story 4 - Cart Display Consistency (Priority: P2)

The cart already displays pricing correctly but uses duplicated inline logic. The same centralized pricing logic should be used in the cart for consistency and maintainability.

**Why this priority**: Ensures the cart remains consistent as the source of truth for pricing display, and reduces code duplication.

**Independent Test**: Can be fully tested by adding standard and branded products to cart and verifying display matches expected format using the centralized logic.

**Acceptance Scenarios**:

1. **Given** a cart with standard pack-priced products, **When** viewing the cart, **Then** pricing displays as "£X.XX / pack (£X.XXXX / unit)"

2. **Given** a cart with branded products, **When** viewing the cart, **Then** pricing displays as "£X.XXXX / unit"

---

### Edge Cases

- What happens when a product has a pack size of 1? (Should display as unit pricing, not "pack of 1")
- How does the system handle orders placed before this change? (Legacy orders without pack size data display unit pricing only)
- What happens if pack size data is missing or null? (Treat as unit pricing)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display standard product pricing in format "£X.XX / pack (£X.XXXX / unit)" where pack price is shown with 2 decimal places and unit price with 4 decimal places

- **FR-002**: System MUST display branded product pricing in format "£X.XXXX / unit" with 4 decimal places

- **FR-003**: System MUST determine pricing type based on: if product is not branded/configured AND has pack size greater than 1, display pack pricing; otherwise display unit pricing

- **FR-004**: System MUST store sufficient data with order items to reconstruct pricing display (pack price and pack size for standard products)

- **FR-005**: System MUST apply consistent pricing display across: order confirmation page, admin order detail views, PDF order summaries, and cart

- **FR-006**: System MUST gracefully handle legacy orders or items without pack size data by displaying unit pricing format

- **FR-007**: System MUST treat pack size of 1 or null as unit pricing (not pack pricing)

### Key Entities

- **Order Item**: Represents a line item in a completed order. Must store the original pack price and pack size to enable correct pricing display. Has methods to determine if pack-priced and to calculate unit price from pack price.

- **Cart Item**: Represents a line item in an active cart. Already has access to product variant data for pack size. Should use the same pricing display logic as order items.

- **Pricing Display**: Centralized logic for formatting prices consistently. Accepts any item (cart or order) and returns formatted pricing string based on item's pricing type.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All order confirmation pages display pricing in the correct format (pack or unit) with 100% accuracy

- **SC-002**: Pricing display is consistent across all 4 touchpoints (order page, admin views, PDF summaries, cart) - verified by visual comparison

- **SC-003**: Pricing logic is defined in a single location - any future pricing format changes require updating only one place

- **SC-004**: Legacy orders (if any exist) continue to display without errors, falling back to unit pricing format

- **SC-005**: Customer support inquiries related to pricing confusion are eliminated for new orders

## Assumptions

- The site is not yet live, so there are no existing orders requiring data migration
- Pack price is the "source of truth" for standard products; unit price is derived by dividing pack price by pack size
- Currency is GBP (£) throughout the application
- Pack prices use 2 decimal precision; unit prices use 4 decimal precision
- The term "branded" and "configured" are used interchangeably to identify custom/unit-priced products
