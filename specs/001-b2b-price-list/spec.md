# Feature Specification: B2B Price List

**Feature Branch**: `001-b2b-price-list`
**Created**: 2025-12-12
**Status**: Draft
**Input**: User description: "B2B price list page with filterable table, add-to-cart functionality, and Excel/PDF export for business customers"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Complete Price List (Priority: P1)

A business owner visits the price list page to quickly scan all available products and their pricing without navigating through individual product pages.

**Why this priority**: This is the core value proposition - business owners want a no-nonsense way to see all pricing at a glance. Without this, the feature has no purpose.

**Independent Test**: Can be fully tested by visiting /price-list and verifying all standard products appear in a table format with pricing information.

**Acceptance Scenarios**:

1. **Given** I am on the website, **When** I click "Price List" in the navigation, **Then** I see a table showing all standard product variants with columns for Product, SKU, Size, Material, Pack Size, Price/Pack, and Price/Unit.
2. **Given** I am viewing the price list, **When** I look at a product row, **Then** I see the product name as a clickable link to its detail page.
3. **Given** I am viewing the price list on mobile, **When** the screen is narrow, **Then** I see a simplified table with essential columns (Product, Size, Price/Pack, Qty, Add) and can still use all features.

---

### User Story 2 - Filter Products (Priority: P1)

A procurement manager wants to narrow down the price list to find specific products by category, material, size, or search term.

**Why this priority**: Equally critical as viewing - a table of 100+ items is useless without filtering. This enables efficient product discovery.

**Independent Test**: Can be fully tested by applying filters and verifying only matching products appear in the table.

**Acceptance Scenarios**:

1. **Given** I am viewing the price list, **When** I select "Napkins" from the Category dropdown, **Then** only napkin products are displayed.
2. **Given** I am viewing the price list, **When** I select "Paper" from the Material dropdown, **Then** only paper products are displayed.
3. **Given** I am viewing the price list, **When** I select "12oz" from the Size dropdown, **Then** only 12oz products are displayed.
4. **Given** I am viewing the price list, **When** I type "cup" in the search box, **Then** only products with "cup" in the name, SKU, or variant name are displayed.
5. **Given** I have applied multiple filters, **When** I click "Clear", **Then** all filters are reset and all products are displayed again.
6. **Given** I have applied filters, **When** I view the result count, **Then** I see how many products match my current filters.

---

### User Story 3 - Add to Cart from Price List (Priority: P2)

A repeat customer wants to quickly add products to their cart directly from the price list without visiting individual product pages.

**Why this priority**: Enables the "rapid ordering interface" use case. Important for efficiency but the price list is still valuable as a reference tool even without this.

**Independent Test**: Can be fully tested by adding items from the price list and verifying they appear in the cart with correct quantities.

**Acceptance Scenarios**:

1. **Given** I am viewing the price list, **When** I select a quantity (1, 2, 3, 5, or 10) from the dropdown and click "Add", **Then** that quantity of packs is added to my cart.
2. **Given** I have added a product to cart, **When** the cart drawer opens, **Then** I see the item I just added with the correct quantity and price.
3. **Given** I have a product already in my cart, **When** I add the same product again from the price list, **Then** the quantity is incremented (not duplicated as a separate line item).
4. **Given** I am on mobile, **When** I add a product to cart, **Then** the cart drawer opens and I can continue shopping or proceed to checkout.

---

### User Story 4 - Export to Excel (Priority: P2)

A procurement team member wants to download the price list as an Excel file to share with their manager for approval or to compare with other suppliers.

**Why this priority**: Key B2B use case - procurement teams need shareable, offline-accessible pricing data. Tied with cart for second priority.

**Independent Test**: Can be fully tested by clicking Export Excel and opening the downloaded file in a spreadsheet application.

**Acceptance Scenarios**:

1. **Given** I am viewing the price list, **When** I click "Excel", **Then** an .xlsx file downloads to my device.
2. **Given** I have applied filters, **When** I click "Excel", **Then** the downloaded file contains only the filtered products (not the full catalog).
3. **Given** I open the downloaded file, **When** I review the contents, **Then** I see columns for Product, SKU, Size, Material, Pack Size, Price/Pack, and Price/Unit.
4. **Given** I download the file, **When** I check the filename, **Then** it includes the date and any applied filter (e.g., "afida-napkins-2025-12-12.xlsx").

---

### User Story 5 - Export to PDF (Priority: P3)

A business owner wants to print or share a PDF version of the price list for offline reference or to include in procurement documentation.

**Why this priority**: Useful for formal procurement processes but less common than Excel. Can be deferred if needed.

**Independent Test**: Can be fully tested by clicking Export PDF and viewing the downloaded file.

**Acceptance Scenarios**:

1. **Given** I am viewing the price list, **When** I click "PDF", **Then** a .pdf file downloads to my device.
2. **Given** I have applied filters, **When** I click "PDF", **Then** the downloaded file contains only the filtered products.
3. **Given** I open the downloaded PDF, **When** I review the contents, **Then** I see Afida branding, the generation date, and a formatted table with pricing data.
4. **Given** I print the PDF, **When** I view the printout, **Then** the content fits on A4 landscape pages and is readable.

---

### Edge Cases

- What happens when no products match the applied filters? → Display a "No products found" message with a link to clear filters.
- What happens when the user applies a filter and then searches? → Both filters apply (intersection), showing only products matching all criteria.
- What happens when a user tries to add a product that no longer exists? → Display an error message (handled by existing cart validation).
- What happens on slow connections during export? → Users should see the download start within a reasonable time; consider file size for large catalogs.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display a dedicated price list page accessible from the main navigation.
- **FR-002**: System MUST display all active standard product variants in a table format.
- **FR-003**: Table MUST show: Product name, SKU, Size, Material, Pack Size, Price per Pack, Price per Unit.
- **FR-004**: Product names MUST link to the full product detail page.
- **FR-005**: System MUST provide dropdown filters for Category, Material, and Size.
- **FR-006**: System MUST provide a text search field for product name, SKU, and variant name.
- **FR-007**: Filters MUST apply instantly without full page reload.
- **FR-008**: System MUST provide a "Clear" action to reset all filters.
- **FR-009**: Each table row MUST have a quantity dropdown with options: 1, 2, 3, 5, 10.
- **FR-010**: Each table row MUST have an "Add" button that adds the selected quantity to cart.
- **FR-011**: Adding to cart MUST open the cart drawer (consistent with site behavior).
- **FR-012**: Adding an existing item MUST increment quantity (not create duplicates).
- **FR-013**: System MUST provide an Excel export button that downloads an .xlsx file.
- **FR-014**: System MUST provide a PDF export button that downloads a .pdf file.
- **FR-015**: Exports MUST respect current filter state (export what is displayed).
- **FR-016**: Export filenames MUST include the date and any active filter category.
- **FR-017**: PDF MUST include Afida branding and fit on A4 landscape pages.
- **FR-018**: Page header MUST display "All prices exclude VAT. Free UK delivery on orders over £100."
- **FR-019**: Mobile view MUST show a simplified table with essential columns while maintaining functionality.

### Key Entities

- **ProductVariant**: The purchasable unit with SKU, price, pack size, and option values (size, material, colour).
- **Product**: Parent product that variants belong to; provides name and category.
- **Category**: Product grouping used for filtering (Cups & Lids, Napkins, etc.).
- **CartItem**: Represents items added to cart with quantity and price.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can find a specific product variant and add it to cart in under 30 seconds.
- **SC-002**: Users can export the full price list to Excel within 5 seconds of clicking the button.
- **SC-003**: Filters apply and update the table within 1 second of selection.
- **SC-004**: 100% of standard product variants are displayed in the price list (no missing items).
- **SC-005**: Export files open correctly in standard spreadsheet applications (Excel, Google Sheets) and PDF readers.
- **SC-006**: Mobile users can view and add products without horizontal scrolling on essential content.
- **SC-007**: The price list page is discoverable via navigation (not hidden behind multiple clicks).

## Scope & Boundaries

### In Scope

- Price list page for all standard products (not branded/customizable products)
- Filtering by category, material, size, and text search
- Add to cart functionality with quantity selection
- Excel and PDF export with filter respect
- Prominent navigation placement

### Out of Scope (v1)

- Customer-specific or wholesale pricing (one price list for everyone)
- Bulk quote request functionality (customers use email for large orders)
- Saved lists or reorder templates
- Price history or price drop notifications
- Integration with ERP or procurement systems

## Assumptions

- All pricing is public (no authentication required to view prices)
- VAT is excluded from displayed prices (consistent with site convention)
- Pack-based pricing model is used (quantity = number of packs)
- Existing cart infrastructure handles all validation and persistence
- Standard products (product_type: "standard") are the only items shown
