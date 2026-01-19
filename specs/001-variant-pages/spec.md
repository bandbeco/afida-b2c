# Feature Specification: Variant-Level Product Pages

**Feature Branch**: `001-variant-pages`
**Created**: 2026-01-10
**Status**: Draft
**Input**: Replace consolidated product pages with individual pages per SKU for better SEO and simpler purchasing UX

## Overview

Transform the product browsing and purchasing experience by giving each product variant (SKU) its own dedicated page. This replaces the current consolidated product pages that use a multi-step variant selector, providing a simpler, faster purchasing flow that aligns with industry standards and improves search engine discoverability.

### Background

Currently, products like "Coffee Cups" have a single page with a guided selector to choose wall-type, size, and colour. While elegant for complex configurations, this approach:
- Reduces SEO surface area (fewer indexable URLs)
- Adds friction for customers who know what they want
- Doesn't match competitor patterns
- Over-engineers simple purchases (most products have 1-5 variants)

### Scope

**In Scope:**
- Individual pages for each product variant (~85 SKUs)
- Simple variant page layout (photo, price, quantity, add to cart)
- Updated shop page showing all variants as cards
- Updated category pages showing variant cards
- Header search functionality
- Shop page filtering by category, size, colour, material
- "See also" section linking related variants

**Out of Scope:**
- Branded product configurator (remains unchanged)
- Advanced search engine (Meilisearch/Algolia)
- Admin interface changes (beyond preview links)
- Changes to cart/checkout flow

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Direct Purchase (Priority: P1)

A customer knows exactly what product they need (e.g., "8oz white coffee cups") and wants to find and purchase it quickly without navigating through selection steps.

**Why this priority**: This is the primary use case. Most B2B packaging supply customers know what they need and want fast access. Removing friction from the purchase path directly impacts conversion.

**Independent Test**: Can be fully tested by navigating to a variant URL, selecting quantity, and adding to cart. Delivers immediate purchasing capability.

**Acceptance Scenarios**:

1. **Given** a customer on the 8oz Single Wall White Coffee Cup page, **When** they select quantity 2 and click "Add to Cart", **Then** 2 packs are added to their cart and the cart drawer opens.

2. **Given** a customer on any variant page, **When** the page loads, **Then** they see the product photo, name, price per pack, pack size, and an add to cart button within 2 seconds.

3. **Given** a customer on a variant page, **When** they view the price, **Then** they see both the pack price and unit count (e.g., "£36.05 / pack (1,000 units)").

---

### User Story 2 - Browse All Products (Priority: P1)

A customer wants to see the full product range at a glance on the shop page, with each variant visible as a separate card.

**Why this priority**: Business owners specifically requested "everything laid out without clicking". This addresses their core concern about discoverability.

**Independent Test**: Can be tested by visiting /shop and verifying all ~85 variants appear as individual cards with photos and prices.

**Acceptance Scenarios**:

1. **Given** a customer on the shop page, **When** the page loads, **Then** they see individual cards for every variant with photo, name, and price.

2. **Given** a customer on the shop page with 85+ products, **When** they scroll, **Then** all variants are accessible without pagination (or with clear pagination if needed for performance).

3. **Given** a customer viewing variant cards, **When** they click a card, **Then** they navigate to that variant's dedicated page.

---

### User Story 3 - Search for Products (Priority: P2)

A customer wants to quickly find specific products by typing search terms like "8oz cup" or "kraft napkin" without browsing through categories.

**Why this priority**: Search is essential for customers who know what they want but don't know where to find it. Header search provides fast access from any page.

**Independent Test**: Can be tested by typing a search query and verifying relevant results appear.

**Acceptance Scenarios**:

1. **Given** a customer on any page, **When** they type "8oz cup" in the header search, **Then** they see matching variants (8oz coffee cups, soup containers, ice cream cups) in a dropdown within 500ms.

2. **Given** a customer searching for "kraft", **When** results appear, **Then** all kraft/brown coloured products are shown.

3. **Given** a customer searching for a SKU "8WSW", **When** results appear, **Then** the exact matching variant is shown first.

4. **Given** a customer viewing search results dropdown, **When** they click "View all results", **Then** they navigate to /shop?q=their-query with full results and filters.

---

### User Story 4 - Filter Products (Priority: P2)

A customer wants to narrow down the shop page to see only products matching specific criteria (category, size, colour, material).

**Why this priority**: With 85+ variants, filtering helps customers who are exploring but have some criteria in mind.

**Independent Test**: Can be tested by selecting filters and verifying the product grid updates to show only matching items.

**Acceptance Scenarios**:

1. **Given** a customer on the shop page, **When** they select "Cups" from the category filter, **Then** only cup variants are displayed.

2. **Given** a customer with "Cups" filter active, **When** they also select "8oz" from the size filter, **Then** only 8oz cup variants are displayed.

3. **Given** a customer with active filters, **When** they view the URL, **Then** the URL reflects their filter selections (e.g., /shop?category=cups&size=8oz).

4. **Given** a customer with filters applied, **When** they share or bookmark the URL and return later, **Then** the same filters are pre-applied.

---

### User Story 5 - Discover Related Variants (Priority: P3)

A customer viewing a variant page wants to easily discover other related variants (different sizes, colours) without going back to search or category pages.

**Why this priority**: Cross-selling related variants increases order value and helps customers discover the full range.

**Independent Test**: Can be tested by viewing a variant page and verifying related variants appear in "See also" section.

**Acceptance Scenarios**:

1. **Given** a customer on the 8oz Single Wall White Coffee Cup page, **When** they scroll to "See also", **Then** they see other coffee cup variants (12oz, 16oz, double wall, etc.).

2. **Given** a customer viewing "See also" variants, **When** they click one, **Then** they navigate to that variant's page.

3. **Given** a product with only one variant, **When** viewing its page, **Then** the "See also" section is hidden or shows category-related products.

---

### Edge Cases

- What happens when a variant has no photo? Display a category-appropriate placeholder image.
- What happens when a variant is out of stock? Show the page with "Out of Stock" badge and disabled add to cart button.
- What happens when search returns no results? Show "No products found. Try different search terms." with suggestions.
- What happens when all filters result in zero products? Show "No products match your filters" with a "Clear filters" button.
- How does the system handle variant slugs with special characters? Slugs are URL-safe (lowercase, hyphens, no special characters).
- What happens to existing bookmarks/links to consolidated product pages? Return 404 (site is not live yet, no legacy URLs to support).

## Requirements *(mandatory)*

### Functional Requirements

**Variant Pages:**
- **FR-001**: System MUST provide a unique URL for each product variant using the pattern `/products/:variant-slug`
- **FR-002**: System MUST generate URL-safe slugs from variant name and product name (e.g., "8oz-single-wall-white-coffee-cup")
- **FR-003**: Variant page MUST display: product photo, variant name, price per pack, pack size in units, SKU, short description
- **FR-004**: Variant page MUST provide quantity selection (dropdown or buttons) and "Add to Cart" functionality
- **FR-005**: Variant page MUST include "See also" section showing other variants from the same product family
- **FR-006**: Variant page MUST include breadcrumb navigation: Home > Category > Variant Name

**Shop Page:**
- **FR-007**: Shop page MUST display all active variants as individual cards
- **FR-008**: Each variant card MUST show: photo, variant name, price per pack
- **FR-009**: Clicking a variant card MUST navigate to that variant's page
- **FR-010**: Shop page MUST provide filter controls for: category, size, colour, material
- **FR-011**: Filters MUST update URL parameters for bookmarkability
- **FR-012**: Filters MUST update results without full page reload

**Category Pages:**
- **FR-013**: Category pages MUST display variant cards for all variants in that category
- **FR-014**: Category page layout MUST match shop page card design

**Search:**
- **FR-015**: Header MUST include a search input accessible from all pages
- **FR-016**: Search MUST query: variant name, SKU, product name, category name
- **FR-017**: Search MUST display results in a dropdown as user types
- **FR-018**: Search dropdown MUST link to individual variant pages
- **FR-019**: Search MUST provide "View all results" link to /shop with search query

**SEO:**
- **FR-020**: Each variant page MUST have unique title tag (variant name + "| Afida")
- **FR-021**: Each variant page MUST have unique meta description
- **FR-022**: Each variant page MUST include Product structured data (JSON-LD) with single Offer
- **FR-023**: Sitemap MUST include all variant URLs

### Key Entities

- **ProductVariant**: Gains `slug` attribute for URL generation. Becomes the primary browsable/purchasable entity. Retains relationship to Product for grouping.
- **Product**: Continues as a grouping mechanism for related variants. Used for "See also" relationships and Google Shopping item_group_id.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Each of the ~85 product variants has its own indexable URL
- **SC-002**: Customers can find and add a product to cart in under 30 seconds from the shop page
- **SC-003**: Shop page loads and displays all variant cards within 2 seconds
- **SC-004**: Search returns relevant results within 500ms of user stopping typing
- **SC-005**: All variant pages include valid Product structured data (verifiable via Google Rich Results Test)
- **SC-006**: Filters correctly narrow results (100% accuracy - no false positives or missing results)
- **SC-007**: "See also" section displays at least 3 related variants for products with multiple variants

## Assumptions

- Site is not yet live, so no legacy URL redirects are needed
- ~85 variants is the current scale; design should work up to ~500 variants without major changes
- Postgres full-text search is sufficient for current scale (upgrade path to Meilisearch exists if needed)
- Branded product configurator remains unchanged and separate from this work
- Filter values (size, colour, material) can be extracted from existing variant option values
- Product photos already exist for most variants; placeholder strategy covers gaps
