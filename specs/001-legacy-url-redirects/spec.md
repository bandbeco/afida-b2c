# Feature Specification: Legacy URL Smart Redirects

**Feature Branch**: `001-legacy-url-redirects`
**Created**: 2025-11-13
**Status**: Draft
**Input**: User description: "Legacy URL Smart Redirects Implementation - Create a database-driven redirect system that maps 63 legacy product URLs from afida.com to the new consolidated product structure, intelligently extracting variant information (size, colour) from legacy URLs and converting them to query parameters."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Legacy URL Visitor Redirect (Priority: P1)

A user clicks on a legacy product URL (e.g., from a bookmark, search engine result, or external link pointing to the old afida.com structure) and needs to be seamlessly redirected to the correct product page on the new site with the appropriate variant pre-selected.

**Why this priority**: This is the core value proposition. Without this, users encounter 404 errors, lose trust, and we lose SEO ranking. This delivers immediate value by preserving all existing inbound links.

**Independent Test**: Can be fully tested by visiting any legacy URL pattern (e.g., `/product/12-310-x-310mm-pizza-box-kraft`) and verifying the user lands on the correct new product page with the correct variant selected.

**Acceptance Scenarios**:

1. **Given** a user has a link to `/product/12-310-x-310mm-pizza-box-kraft`, **When** they visit this URL, **Then** they are redirected to `/products/pizza-box-kraft?size=12"` with HTTP 301 status
2. **Given** a user has a link to `/product/8oz-227ml-single-wall-paper-hot-cup-white`, **When** they visit this URL, **Then** they are redirected to `/products/single-wall-paper-hot-cup?size=8oz&colour=White` with HTTP 301 status
3. **Given** a user visits a legacy URL with multiple variant parameters, **When** the redirect occurs, **Then** all extracted parameters are included in the query string and the correct variant is displayed on the product page
4. **Given** a search engine crawler visits a legacy URL, **When** the redirect occurs, **Then** the 301 status code signals to update their index with the new URL

---

### User Story 2 - Unmapped URL Fallback (Priority: P2)

A user visits a legacy URL that has no mapping in the redirect database and needs a graceful fallback experience rather than seeing a generic error page.

**Why this priority**: While P1 covers the 63 known URLs, there may be other legacy URLs we haven't identified. This prevents a poor user experience for edge cases.

**Independent Test**: Can be tested independently by visiting a legacy URL pattern that doesn't exist in the redirect database (e.g., `/product/unknown-product-xyz`) and verifying the user sees an appropriate fallback.

**Acceptance Scenarios**:

1. **Given** a user visits `/product/unknown-product-xyz` which has no redirect mapping, **When** the system processes the request, **Then** the user sees a 404 page with helpful search functionality or category navigation
2. **Given** a legacy URL contains partial information about a product category, **When** no exact mapping exists, **Then** the user is redirected to the relevant category page if identifiable

---

### User Story 3 - Administrator Analytics & Management (Priority: P3)

An administrator needs to view which legacy URLs are being accessed, identify unmapped URLs that need attention, and manage redirect mappings to ensure optimal user experience.

**Why this priority**: This enables data-driven decisions about which redirects to add or modify, but isn't essential for the initial launch since the 63 URLs are pre-mapped.

**Independent Test**: Can be tested by accessing an admin interface showing redirect statistics, adding a test redirect mapping, and verifying it works immediately.

**Acceptance Scenarios**:

1. **Given** an administrator accesses the redirect management interface, **When** they view the redirect list, **Then** they see all 63+ mappings with hit counts sorted by usage
2. **Given** an administrator identifies a missing redirect from analytics, **When** they add a new mapping, **Then** the redirect becomes active immediately without requiring deployment
3. **Given** an administrator wants to test a redirect, **When** they use the test functionality, **Then** they can verify the redirect behavior before making it live
4. **Given** an administrator needs to temporarily disable a redirect, **When** they mark it as inactive, **Then** requests to that legacy URL fall through to normal routing

---

### Edge Cases

- What happens when a legacy URL maps to a product that no longer exists on the new site?
- How does the system handle case sensitivity in legacy URLs (e.g., `/product/kraft-box` vs `/product/Kraft-Box`)?
- What if a legacy URL contains size/colour information that doesn't match any current product variant?
- How does the system handle duplicate mappings (e.g., multiple STRAWS entries with slightly different URLs)?
- What if the size format in the legacy URL (e.g., "12oz") differs from the current product's size format (e.g., "340ml")?
- How does the system handle URLs with trailing slashes or query parameters already present?
- What happens if two legacy URLs map to the same new product+variant combination?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST redirect requests matching `/product/*` pattern by looking up the path in a redirect mapping database
- **FR-002**: System MUST issue HTTP 301 (Permanent Redirect) status codes for all successful redirects to signal search engines to update their indexes
- **FR-003**: System MUST extract variant parameters (size, colour) from legacy URL text and append them as query parameters to the new URL
- **FR-004**: System MUST increment a usage counter each time a redirect is followed to enable analytics
- **FR-005**: System MUST support enabling/disabling individual redirects without removing the mapping
- **FR-006**: System MUST store 63 initial redirect mappings from the legacy afida.com product URLs
- **FR-007**: System MUST normalize extracted parameters to match the current product's variant option format (e.g., "kraft" → "Kraft", "12oz" → current size format)
- **FR-008**: System MUST handle URLs with or without trailing slashes consistently
- **FR-009**: System MUST preserve any existing query parameters when redirecting (e.g., `/product/foo?utm_source=google` → `/products/bar?size=12&utm_source=google`)
- **FR-010**: System MUST fall through to normal routing (resulting in 404) when no redirect mapping matches
- **FR-011**: For duplicate products, system MUST redirect to the generic product page without variant parameters to let users select their option
- **FR-012**: For products that no longer exist, system MUST redirect to the category page or search page as a fallback
- **FR-013**: System MUST be case-insensitive when matching legacy URL paths
- **FR-014**: Administrators MUST be able to view all redirect mappings with their usage statistics
- **FR-015**: Administrators MUST be able to create new redirect mappings
- **FR-016**: Administrators MUST be able to edit existing redirect mappings
- **FR-017**: Administrators MUST be able to test a redirect before activating it
- **FR-018**: Administrators MUST be able to bulk import redirects from a data file
- **FR-019**: System MUST log warnings when encountering unmapped legacy URLs for future mapping consideration

### Key Entities

- **LegacyRedirect**: Represents a mapping from an old URL to a new product page
  - Legacy path (the old URL path, e.g., `/product/12-310-x-310mm-pizza-box-kraft`)
  - Target slug (the new product slug, e.g., `pizza-box-kraft`)
  - Variant parameters (extracted size/colour information as structured data, e.g., `{size: "12\"", colour: "Kraft"}`)
  - Hit count (number of times this redirect has been used)
  - Active status (whether this redirect is currently enabled)
  - Timestamps (when created/updated)

- **RedirectMapping**: The actual URL mapping data structure
  - Source URL pattern
  - Destination URL template
  - Parameter extraction rules
  - Fallback behavior

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 63 legacy product URLs redirect users to the correct product page within 500ms
- **SC-002**: Search engines update their indexes to reflect new URLs within 30 days of 301 redirects being active
- **SC-003**: Users clicking legacy URLs successfully complete their intended action (view product, add to cart) 95% of the time
- **SC-004**: Zero increase in customer support tickets related to broken product links after launch
- **SC-005**: 100% of legacy URLs with variant information correctly pre-select the matching product variant
- **SC-006**: Administrators can identify and add new redirect mappings in under 5 minutes per URL
- **SC-007**: The redirect system processes requests with negligible performance impact (under 10ms overhead per request)

## Assumptions

- The 63 legacy URLs are documented in a `results.json` file available to the development team
- All legacy URLs follow a consistent pattern: `/product/[identifier-with-size-and-colour]`
- Current product slugs and variant option values are accessible via the existing database
- Size and colour information can be reliably extracted from legacy URL text using pattern matching
- The website uses standard SEO practices and search engines will respect 301 redirects
- Legacy URLs are primarily accessed by users, not by automated systems that might be affected by redirects

## Out of Scope

- Redirecting non-product URLs (e.g., old category pages, blog posts)
- Automatic discovery of unmapped legacy URLs (will rely on manual identification)
- Redirect chaining (legacy → intermediate → final URL)
- Custom redirect rules based on user location, device, or other contextual factors
- Reversing redirects or providing bidirectional URL mapping
