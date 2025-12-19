# Feature Specification: Unified Variant Selector

**Feature Branch**: `015-variant-selector`
**Created**: 2025-12-18
**Status**: Draft
**Input**: User description: "Unify standard and consolidated product UI into a single variant selector component with accordion-style interface"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Select Product Variant with Multiple Options (Priority: P1)

A customer browsing products with multiple options (e.g., Eco-Friendly Straws with material, size, and colour choices) can select their preferred combination using a guided step-by-step interface that clearly shows available options and filters unavailable combinations.

**Why this priority**: This represents the core value proposition - unifying how customers select product variants across all non-branded products with a consistent, guided experience.

**Independent Test**: Can be fully tested by visiting any multi-option product page and selecting options. Delivers value immediately by providing a clearer purchase flow.

**Acceptance Scenarios**:

1. **Given** a product page for Eco-Friendly Straws, **When** I arrive on the page, **Then** I see the first option step (Material) expanded with available choices (Paper, Bamboo, etc.)

2. **Given** I have selected "Paper" for material, **When** the selection is made, **Then** the Material step collapses showing "✓ Select Material : Paper" and the next step (Size) auto-expands

3. **Given** I have selected "Paper" for material, **When** viewing the Size step, **Then** only sizes available in Paper are enabled; unavailable sizes appear greyed out

4. **Given** all options are selected, **When** viewing the selector, **Then** I see my complete configuration summarized in collapsed step headers and the Quantity step is enabled

---

### User Story 2 - Select Quantity with Volume Discount Tiers (Priority: P2)

A customer ready to purchase can see all available quantity tiers with clear pricing information including pack price, unit price, and savings percentage to make an informed bulk purchase decision.

**Why this priority**: Volume discount visibility directly impacts average order value and customer satisfaction when pricing tiers exist.

**Independent Test**: Can be tested on any product with pricing tiers configured by selecting a variant and viewing the quantity step.

**Acceptance Scenarios**:

1. **Given** I have selected a variant that has pricing tiers, **When** viewing the Quantity step, **Then** I see tier cards showing pack quantity, pack price, total price, unit breakdown, calculated unit price, and savings percentage

2. **Given** tier cards are displayed, **When** I select the "3 packs" tier, **Then** the card is visually highlighted as selected and the Add to Cart button shows the correct total

3. **Given** a variant without pricing tiers, **When** viewing the Quantity step, **Then** I see a dropdown selector with pack options and the variant's standard price

---

### User Story 3 - Purchase Single-Option Product (Priority: P3)

A customer buying a simple product with only one option (e.g., Pizza Boxes with just size choice) experiences a streamlined flow where the single option step is shown followed directly by quantity selection.

**Why this priority**: Simple products should feel simple - the unified selector must gracefully handle minimal-option products without feeling heavyweight.

**Independent Test**: Can be tested by visiting any single-option product like Kraft Pizza Boxes.

**Acceptance Scenarios**:

1. **Given** a product with only one option (Size), **When** I arrive on the page, **Then** I see only one option step (Size) followed by Quantity step - no unnecessary steps are shown

2. **Given** a quantity-only product (no variant options), **When** I arrive on the page, **Then** I see only the Quantity step - the selector adjusts to show only what's needed

---

### User Story 4 - Revise Previous Selection (Priority: P4)

A customer who has made selections can easily go back and change a previous choice without losing their entire configuration, enabling exploration of different combinations.

**Why this priority**: Flexibility in selection prevents frustration and supports comparison shopping.

**Independent Test**: Can be tested by selecting options, then clicking a collapsed step header to revise.

**Acceptance Scenarios**:

1. **Given** I have selected Material and Size, **When** I click the collapsed Material step header, **Then** the step expands allowing me to change my selection

2. **Given** I change Material from "Paper" to "Bamboo", **When** the change is made, **Then** subsequent selections (Size, Colour) are cleared if they're no longer valid for the new material

---

### Edge Cases

- What happens when a product has only one variant (no meaningful options)? → Show only Quantity step
- How does the system handle a sparse option matrix where some combinations don't exist? → Unavailable options are displayed but disabled (greyed out)
- What happens if a user directly links to a product page with URL parameters for pre-selection? → Selections are applied and validated on page load
- How does the selector behave when product images fail to load? → Graceful fallback to placeholder, selector remains functional

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display option steps in consistent priority order: material → type → size → colour
- **FR-002**: System MUST only show option steps for options that have multiple values across the product's variants
- **FR-003**: System MUST auto-collapse a step when the user makes a selection, showing the selected value in the header
- **FR-004**: System MUST auto-expand the next incomplete step after a selection is made
- **FR-005**: System MUST allow users to re-expand any collapsed step by clicking its header
- **FR-006**: System MUST filter subsequent option values based on previous selections, disabling unavailable combinations
- **FR-007**: System MUST auto-select an option value if only one valid choice remains after filtering
- **FR-008**: System MUST sort size values using natural sort (8oz before 12oz, 6x140mm before 8x200mm)
- **FR-009**: System MUST sort non-size option values alphabetically
- **FR-010**: System MUST display pricing tier cards when a variant has configured pricing tiers
- **FR-011**: System MUST display pack price, unit price, unit count, and savings percentage on each tier card
- **FR-012**: System MUST fall back to a quantity dropdown when no pricing tiers are configured
- **FR-013**: System MUST update the product image when a variant is selected (if variant has an image)
- **FR-014**: System MUST enable the Add to Cart button only when all required selections are complete
- **FR-015**: System MUST preserve existing product page elements: title, price range, description, badges, compatible lids section

### Key Entities

- **Product**: Parent container with title, descriptions, and category. Has many variants.
- **ProductVariant**: Specific purchasable item with SKU, price, stock, pack size, and option values. Option values stored as JSON (e.g., `{material: "Paper", size: "8oz"}`).
- **Pricing Tier**: Optional volume discount configuration per variant with quantity breakpoints and corresponding pack prices.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All non-branded products display using the unified variant selector (100% coverage)
- **SC-002**: Customers can complete variant selection and add to cart in under 30 seconds for typical products
- **SC-003**: Option filtering correctly disables 100% of invalid combinations (no broken add-to-cart attempts)
- **SC-004**: Product pages load with variant selector functional within 2 seconds on standard connections
- **SC-005**: The unified selector works correctly across desktop and mobile viewports
- **SC-006**: Zero increase in cart abandonment rate on product pages after rollout

## Assumptions

- Standard products will continue using pack-based pricing (pac_size > 1)
- The existing product page layout (image gallery, title, description, compatible lids section) is retained
- Branded products remain on their separate configurator (different pricing model)
- Quick-add modal retains its simpler inline interface (not accordion)
- Pricing tiers are optional and will be added to products over time by the business
- Option priority order (material → type → size → colour) covers all current and anticipated product option types

## Scope Boundaries

### In Scope

- Unified variant selector component for all non-branded products
- Accordion-style UI with auto-collapse behaviour
- Option filtering and validation
- Pricing tier display (when configured)
- Quantity dropdown fallback (when no tiers)
- Data migration from ProductOption tables to variant JSON
- Removal of legacy code and tables after migration

### Out of Scope

- Branded product configurator (stays separate)
- Compatible lids section (unchanged, remains below selector)
- Quick-add modal redesign (keeps simpler interface)
- Admin UI for managing pricing tiers (separate feature)
- Volume discount tier data entry (business decision)
