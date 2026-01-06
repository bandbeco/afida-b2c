# Feature Specification: Product Option Value Labels

**Feature Branch**: `001-option-value-labels`
**Created**: 2026-01-06
**Status**: Draft
**Input**: Replace JSONB option_values on product variants with a join table to separate stored values from display labels

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Display Human-Readable Option Labels (Priority: P1)

A customer browses the product catalog and views product variants. Instead of seeing raw machine values like "7in" or "cutlery-kit", they see properly formatted labels like "7 inches (30cm)" or "Cutlery Kit".

**Why this priority**: This is the core value proposition - improving the customer experience by displaying readable labels while maintaining stable stored values for system operations.

**Independent Test**: Can be fully tested by viewing any product page with variants and verifying that option labels display in human-readable format.

**Acceptance Scenarios**:

1. **Given** a product variant with size value "7in", **When** a customer views the product page, **Then** they see "7 inches (30cm)" displayed
2. **Given** a product variant with type value "cutlery-kit", **When** a customer views the variant options, **Then** they see "Cutlery Kit" displayed
3. **Given** a product variant with size value "8-12oz" where label matches value, **When** a customer views the product, **Then** they see "8-12oz" displayed unchanged

---

### User Story 2 - Variant Selector Works with Sparse Matrix (Priority: P1)

A customer uses the variant selector on a product page to choose options. When selecting one option (e.g., size "8oz"), only valid combinations are shown for other options (e.g., only colours that have 8oz variants). The existing sparse matrix filtering behavior is preserved.

**Why this priority**: This is critical functionality that must continue working - customers depend on it to find valid product combinations.

**Independent Test**: Can be fully tested by selecting variant options and verifying that only valid combinations remain available.

**Acceptance Scenarios**:

1. **Given** a product with variants for 8oz White and 12oz Black only, **When** customer selects "8oz" size, **Then** only "White" colour option is available
2. **Given** a product with multiple variant combinations, **When** customer selects any option, **Then** the selector filters to show only valid remaining options
3. **Given** a product with variants, **When** customer completes option selection, **Then** the correct variant is identified and can be added to cart

---

### User Story 3 - Admin Manages Option Labels (Priority: P2)

An admin user manages product option values through the admin interface. They can set both the stored value (machine-readable) and display label (human-readable) for each option value.

**Why this priority**: Required for ongoing maintenance, but existing seed data covers initial launch needs.

**Independent Test**: Can be fully tested by editing option values in admin and verifying changes appear on product pages.

**Acceptance Scenarios**:

1. **Given** an admin user editing product options, **When** they set label "7 inches (30cm)" for value "7in", **Then** all products using that option value display the new label
2. **Given** an option value with no explicit label set, **When** displayed to customers, **Then** the stored value is shown as fallback
3. **Given** an admin adding a new option value, **When** they enter an invalid or duplicate value, **Then** the system prevents the save with a clear error message

---

### User Story 4 - Data Integrity Enforcement (Priority: P2)

The system prevents invalid option value assignments. A variant cannot have two values for the same option type (e.g., both "8oz" and "12oz" for size), and option values must exist in the system before assignment.

**Why this priority**: Prevents data corruption that would be difficult to debug, especially important once admins manage data directly.

**Independent Test**: Can be fully tested by attempting to create invalid variant-option assignments and verifying they are rejected.

**Acceptance Scenarios**:

1. **Given** a variant with size "8oz" assigned, **When** attempting to assign size "12oz" to the same variant, **Then** the system rejects with an error
2. **Given** a non-existent option value "banana", **When** attempting to assign it to a variant, **Then** the system rejects with an error
3. **Given** valid option values exist, **When** assigning them to a variant, **Then** the assignment succeeds

---

### Edge Cases

- What happens when an option value is deleted that variants are using? System prevents deletion while variants reference it.
- How does the system handle option values with empty labels? Falls back to displaying the stored value.
- What happens if a product has no option assignments? Variants are displayed without option selectors.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST store product variant options as relationships to option value records, not as embedded JSON
- **FR-002**: System MUST display human-readable labels to customers while storing machine-readable values internally
- **FR-003**: System MUST enforce that each variant has at most one value per option type (e.g., one size, one colour)
- **FR-004**: System MUST validate that option values exist before allowing assignment to variants
- **FR-005**: System MUST provide backwards-compatible data structure to the variant selector (same JSON format for frontend)
- **FR-006**: System MUST fall back to displaying the stored value when no explicit label is set
- **FR-007**: Admins MUST be able to define both stored value and display label for each option value
- **FR-008**: System MUST maintain referential integrity - deleting an option value used by variants is prevented

### Key Entities

- **ProductOption**: Represents a type of option (size, colour, material). Has a name, display type (dropdown/radio/swatch), and sort position.
- **ProductOptionValue**: Represents a specific value within an option type. Has both a stored value (e.g., "7in") and display label (e.g., "7 inches (30cm)"). Belongs to one ProductOption.
- **VariantOptionValue**: Join entity linking a ProductVariant to a ProductOptionValue. Enforces one-value-per-option constraint. Includes denormalized reference to ProductOption for constraint enforcement.
- **ProductVariant**: Represents a purchasable variant of a product. Has many option values through VariantOptionValue.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of product option values display human-readable labels where defined, falling back to stored values otherwise
- **SC-002**: Variant selector filtering behavior is identical before and after - customers can select options and find valid combinations
- **SC-003**: Zero data integrity violations - no variant can have multiple values for the same option type
- **SC-004**: All existing products continue to function correctly after data refresh
- **SC-005**: Admins can update an option value label and see the change reflected across all products using that value within one page refresh

## Assumptions

- The site is pre-launch, so data can be dropped and re-seeded rather than requiring live data migration
- The existing ProductOption and ProductOptionValue tables remain structurally unchanged
- The variant selector frontend receives the same data structure and requires no JavaScript changes
- Option types are relatively stable (size, colour, material, type) and don't require dynamic creation by users
