# Feature Specification: Collections & Curated Sample Packs

**Feature Branch**: `019-collections`
**Created**: 2026-01-17
**Status**: Draft
**Input**: User description: "Collections and curated sample packs - audience-based product groupings that cross-cut categories (e.g., Coffee Shop Essentials) and pre-selected sample packs for specific customer types"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Browse Products by Audience Type (Priority: P1)

A coffee shop owner visits the website looking for supplies. Instead of browsing through individual categories (cups, lids, napkins, straws), they can go to a "Coffee Shop Essentials" collection page that shows all products relevant to their business in one place.

**Why this priority**: This is the core value proposition - audience-centric navigation reduces friction and helps customers find relevant products faster. It directly supports marketing campaigns where links can point to focused landing pages.

**Independent Test**: Can be fully tested by creating a collection, adding products, and verifying the public collection page displays correctly with all products.

**Acceptance Scenarios**:

1. **Given** a collection "Coffee Shop Essentials" exists with 12 products, **When** a visitor navigates to `/collections/coffee-shop`, **Then** they see the collection name, description, and all 12 products displayed in a grid.

2. **Given** multiple featured collections exist, **When** a visitor navigates to `/collections`, **Then** they see a list of all featured collections with images and descriptions.

3. **Given** a collection has products from multiple categories, **When** viewing the collection page, **Then** products from all categories appear together, ordered by the collection's product ordering.

---

### User Story 2 - Request Curated Sample Pack (Priority: P2)

A restaurant owner is interested in trying products but doesn't want to browse through individual items. They can select a "Restaurant Sample Pack" which pre-selects the most popular products for restaurants. With one click, they add all recommended samples to their cart.

**Why this priority**: Curated sample packs reduce decision fatigue and increase sample request conversion. They leverage the existing samples flow while making it easier for specific customer segments to try relevant products.

**Independent Test**: Can be fully tested by creating a sample pack collection, visiting the pack page, and clicking "Add All to Cart" to verify all eligible products are added as samples.

**Acceptance Scenarios**:

1. **Given** a sample pack "Coffee Shop Sample Pack" exists with 5 sample-eligible products, **When** a visitor clicks "Add All to Cart", **Then** all 5 products are added to their cart as free samples.

2. **Given** a visitor already has 3 samples in their cart and the pack has 5 products, **When** they click "Add All to Cart", **Then** only 2 products are added (respecting the 5-sample limit) and they see a message about the limit.

3. **Given** a sample pack page is displayed, **When** a visitor prefers to choose individually, **Then** they can add individual products from the pack one at a time.

4. **Given** a visitor is on the samples index page, **When** sample packs exist, **Then** they see the curated packs prominently displayed above the category browser.

---

### User Story 3 - Manage Collections in Admin (Priority: P3)

An administrator needs to create, edit, and organise collections. They can create a new collection, add/remove products, set SEO metadata, and control display order.

**Why this priority**: Admin functionality enables the business to maintain collections without developer intervention. Required for the feature to be sustainable long-term.

**Independent Test**: Can be fully tested by logging into admin, creating a collection, adding products, editing details, and reordering collections.

**Acceptance Scenarios**:

1. **Given** an admin is on the collections index page, **When** they click "New Collection", **Then** they see a form to create a collection with name, slug, description, SEO fields, and image upload.

2. **Given** an admin is editing a collection, **When** they select products using checkboxes, **Then** those products are associated with the collection.

3. **Given** multiple collections exist, **When** an admin visits the order page, **Then** they can reorder collections using up/down buttons.

4. **Given** an admin marks a collection as "Sample Pack", **When** saved, **Then** the collection appears on the samples page rather than the collections index.

---

### Edge Cases

- What happens when a collection has no products? Display an empty state with a message.
- What happens when a product in a collection is deactivated? It should not appear on the public collection page.
- What happens when a sample pack contains products that are not sample-eligible? Those products are skipped when adding to cart.
- What happens when a product belongs to multiple collections? It appears in all of them independently.
- What happens when a collection's slug conflicts with an existing route? Validation prevents duplicate slugs.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow products to belong to multiple collections (many-to-many relationship)
- **FR-002**: System MUST display collection pages at SEO-friendly URLs (e.g., `/collections/coffee-shop`)
- **FR-003**: System MUST support collection images for visual presentation
- **FR-004**: System MUST allow administrators to set SEO metadata (meta title, meta description) for each collection
- **FR-005**: System MUST distinguish between regular collections and sample pack collections
- **FR-006**: System MUST display sample pack collections on the samples page, not the collections index
- **FR-007**: System MUST allow administrators to order products within a collection
- **FR-008**: System MUST allow administrators to order collections relative to each other
- **FR-009**: System MUST provide an "Add All to Cart" action for sample packs that respects the existing 5-sample limit
- **FR-010**: System MUST only show active, catalog products on public collection pages
- **FR-011**: System MUST include structured data on collection pages for SEO
- **FR-012**: System MUST provide breadcrumb navigation on collection pages

### Key Entities

- **Collection**: A curated group of products with a name, slug, description, optional image, and SEO metadata. Has a flag indicating whether it's a sample pack. Has a position for ordering.
- **Collection Item**: A join record linking a collection to a product, with a position for ordering within the collection.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Marketing team can create a new collection and add products in under 5 minutes without developer assistance
- **SC-002**: Customers can find all relevant products for their business type on a single page
- **SC-003**: Sample pack "Add All" action completes in under 2 seconds
- **SC-004**: Collection pages load within standard page load time expectations
- **SC-005**: 100% of collection pages have valid structured data for search engines
- **SC-006**: Campaign links to collection pages (e.g., `/collections/coffee-shop`) work correctly as marketing landing destinations

## Assumptions

- The existing 5-sample limit per cart will be respected for sample packs
- Collections are separate from categories; a product still belongs to exactly one category but can be in many collections
- The admin interface will follow existing patterns used for categories and products
- Sample pack collections will leverage the existing samples flow and cart integration
- SEO patterns will match the existing category and product page implementations
