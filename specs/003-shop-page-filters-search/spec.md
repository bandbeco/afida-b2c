# Feature Specification: Shop Page - Product Listing with Filters and Search

**Feature Branch**: `003-shop-page-filters-search`
**Created**: 2025-01-14
**Status**: Draft
**Input**: User description: "I want to have the /shop page show ALL products, with some useful filters, and search functionality."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Browse All Products with Visual Grid (Priority: P1)

As a customer visiting the shop page, I want to see all available products in a visual grid layout so I can browse the entire catalog and find what I need.

**Why this priority**: This is the foundation of the feature - without a product listing, there's nothing to filter or search. Currently, the /shop page only shows categories, not products.

**Independent Test**: Can be fully tested by visiting /shop and verifying all active products are displayed in a grid with photos, names, and prices. Delivers immediate value by exposing the full catalog.

**Acceptance Scenarios**:

1. **Given** I am on the /shop page, **When** the page loads, **Then** I see all active products displayed in a grid layout
2. **Given** products are displayed, **When** I view a product card, **Then** I see the product photo, name, price range, and category
3. **Given** a product has multiple variants, **When** displayed on the grid, **Then** the price range shows "From £X.XX - £Y.YY"
4. **Given** a product has a single variant, **When** displayed on the grid, **Then** the price shows "£X.XX"
5. **Given** I am viewing the product grid, **When** I click on a product, **Then** I am taken to the product detail page

---

### User Story 2 - Filter Products by Category (Priority: P2)

As a customer browsing products, I want to filter by category so I can focus on specific product types (e.g., pizza boxes, cups, napkins).

**Why this priority**: Category filtering is the most common way customers navigate product catalogs. It reduces cognitive load and helps customers find relevant products quickly.

**Independent Test**: Can be fully tested by selecting different categories and verifying only products from those categories are shown. Works independently of search.

**Acceptance Scenarios**:

1. **Given** I am on the /shop page, **When** the page loads, **Then** I see a list of all categories with product counts
2. **Given** I see category filters, **When** I click on a category (e.g., "Cups"), **Then** only products from that category are displayed
3. **Given** I have selected a category, **When** I select a different category, **Then** the previous filter is replaced
4. **Given** I have selected a category, **When** I click "All Products" or clear filter, **Then** all products are shown again
5. **Given** a category filter is active, **When** the page updates, **Then** the URL reflects the filter (e.g., /shop?category=cups)
6. **Given** I visit a URL with a category filter, **When** the page loads, **Then** the filter is applied automatically

---

### User Story 3 - Search Products by Name/SKU (Priority: P2)

As a customer, I want to search for products by name or SKU so I can quickly find specific items without browsing the entire catalog.

**Why this priority**: Search is essential for returning customers who know what they want. Equally important as category filtering, but different use case.

**Independent Test**: Can be fully tested by entering search terms and verifying matching products are shown. Works independently of category filters.

**Acceptance Scenarios**:

1. **Given** I am on the /shop page, **When** I enter a search term (e.g., "pizza"), **Then** I see only products matching that term in name or SKU
2. **Given** I have entered a search term, **When** there are no matches, **Then** I see "No products found" message with a clear filter option
3. **Given** I have entered a search term, **When** I clear the search, **Then** all products are shown again
4. **Given** a search is active, **When** the page updates, **Then** the URL reflects the search (e.g., /shop?q=pizza)
5. **Given** I visit a URL with a search query, **When** the page loads, **Then** the search is applied automatically
6. **Given** I am searching, **When** I type, **Then** the search updates after a brief delay (debounced)

---

### User Story 4 - Combine Filters and Search (Priority: P3)

As a customer, I want to combine category filters and search together so I can narrow down results even further (e.g., search "8oz" within "Cups" category).

**Why this priority**: Power users benefit from combining filters, but it's not critical for basic functionality. Most users will use one or the other.

**Independent Test**: Can be fully tested by selecting a category and entering a search term, verifying only products matching both criteria are shown.

**Acceptance Scenarios**:

1. **Given** I have selected a category, **When** I enter a search term, **Then** I see only products that match both the category and the search
2. **Given** I have both filters active, **When** I clear one filter, **Then** the other filter remains active
3. **Given** I have both filters active, **When** I clear all filters, **Then** all products are shown
4. **Given** I have combined filters, **When** the page updates, **Then** the URL reflects both filters (e.g., /shop?category=cups&q=8oz)

---

### User Story 5 - Sort Products (Priority: P3)

As a customer, I want to sort products by different criteria (price, name, newest) so I can find products that match my shopping preferences.

**Why this priority**: Sorting is useful but not essential for MVP. Many customers browse visually without sorting.

**Independent Test**: Can be fully tested by selecting different sort options and verifying products are reordered correctly.

**Acceptance Scenarios**:

1. **Given** I am viewing products, **When** I select "Price: Low to High", **Then** products are sorted by minimum variant price ascending
2. **Given** I am viewing products, **When** I select "Price: High to Low", **Then** products are sorted by minimum variant price descending
3. **Given** I am viewing products, **When** I select "Name: A-Z", **Then** products are sorted alphabetically
4. **Given** I am viewing products, **When** I select "Newest First", **Then** products are sorted by creation date descending
5. **Given** a sort is active, **When** the page updates, **Then** the URL reflects the sort (e.g., /shop?sort=price_asc)

---

### Edge Cases

- What happens when there are 100+ products? (Pagination or infinite scroll needed)
- How does search handle special characters or SKU formats (e.g., "8 oz" vs "8oz")?
- What if a category has no active products?
- How do filters behave on mobile devices (sidebar vs drawer)?
- What if JavaScript is disabled? (Should degrade gracefully with form submission)
- How does the page handle concurrent filter changes (e.g., rapid clicking)?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display all active products on /shop page in a grid layout
- **FR-002**: System MUST show product photo (using primary_photo helper), name, category, and price range for each product
- **FR-003**: System MUST provide category filter checkboxes/links with product counts
- **FR-004**: System MUST provide search input that filters by product name and SKU
- **FR-005**: System MUST support combining category filter and search simultaneously
- **FR-006**: System MUST persist filters in URL query parameters (category, q, sort)
- **FR-007**: System MUST apply filters from URL on page load (for bookmarking/sharing)
- **FR-008**: System MUST debounce search input to avoid excessive requests
- **FR-009**: System MUST use Turbo Frames for filter updates (avoid full page reloads)
- **FR-010**: System MUST sort products by: price (asc/desc), name (a-z), newest first
- **FR-011**: System MUST show "No products found" message when filters produce empty results
- **FR-012**: System MUST maintain existing SEO meta tags and canonical URLs
- **FR-013**: System MUST implement pagination when product count exceeds 24 items
- **FR-014**: System MUST eager load necessary associations to prevent N+1 queries
- **FR-015**: System MUST work without JavaScript (form submission fallback for filters)

### Key Entities *(include if feature involves data)*

- **Product**: Already exists - represents catalog items with variants, photos, category
- **Category**: Already exists - used for category filtering with product count
- **ProductVariant**: Already exists - provides pricing information for products
- **No new entities required** - this feature uses existing models

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All active products (50+) are displayed on /shop page within 2 seconds of page load
- **SC-002**: Category filter reduces displayed products to only those in selected category
- **SC-003**: Search functionality returns relevant results within 500ms of input
- **SC-004**: Combined filters (category + search) work correctly and return accurate results
- **SC-005**: URL parameters persist filters, allowing bookmarking and sharing of filtered views
- **SC-006**: Page maintains Lighthouse performance score above 90
- **SC-007**: No N+1 queries introduced (verified with Bullet gem in development)
- **SC-008**: Filter updates use Turbo Frames without full page reloads
- **SC-009**: Mobile users can access and use all filters (responsive design)
- **SC-010**: 90% of users successfully find products using either category or search on first attempt
