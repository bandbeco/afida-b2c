# Product Specifications Display — Design

**Date:** 2026-04-19
**Status:** Approved (brainstorming phase)

## Problem

Product dimensions, weight, volume, material, colour, size, and certifications are stored on the `products` table (populated by `lib/tasks/import_specs.rake` from CSV), but none of these values are shown anywhere on the product show page. Customers cannot see basic spec information when evaluating a product.

## Goal

Display a subset of product specifications on the product show page, structured so customers can scan dimensions and material attributes at a glance.

## Scope

### In scope

Display the following fields on `products#show`:

**Dimensions group** (all stored as integers):
- `length_in_mm` → label "Length", unit "mm"
- `width_in_mm` → label "Width", unit "mm"
- `height_in_mm` → label "Height", unit "mm"
- `depth_in_mm` → label "Depth", unit "mm"
- `diameter_in_mm` → label "Diameter", unit "mm"
- `weight_in_g` → label "Weight", unit "g"
- `volume_in_ml` → label "Volume", unit "ml"

**Materials group** (strings):
- `material` → label "Material"
- `colour` → label "Colour"
- `size` → label "Size"
- `certifications` → label "Certifications", split on `,` (the importer normalises `/` to `,` on write), rendered as DaisyUI badges

### Out of scope

- Case dimensions (`case_length_in_mm`, `case_width_in_mm`, `case_depth_in_mm`, `case_weight_in_g`)
- `brand` field
- Unit conversion (values render in the stored unit, no mm→cm or g→kg)
- Changes to the CSV importer or CSV format
- Database schema changes (uses existing columns)
- Admin UI for editing specs
- Any change to other pages (index, category, search, etc.)

## Behaviour

### Rendering rules

1. **Row hiding.** A spec row is omitted from its group when the underlying value is `nil`, blank, or (for numeric fields) zero. No "—" placeholders.
2. **Group hiding.** If every field in a group is blank/zero, that group's heading and list are not rendered.
3. **Section hiding.** If both groups are empty, the entire "Specifications" section (heading + container) is not rendered.
4. **Certifications parsing.** The `certifications` string is split on `,`, each resulting token is `strip`ped, blank tokens are rejected. The remaining tokens render as DaisyUI `badge` components. If the resulting list is empty, the certifications row is treated as empty (see row hiding). The importer rewrites `/` to `,` before storing, so the view always sees comma-separated values.

### Display format

- Dimension labels render as plain text (`"Length"`, etc.) with the value followed by a space and its unit symbol: e.g., `254 mm`, `450 g`, `200 ml`.
- Material labels render the raw string value. No casing normalisation.
- Certifications render as a list of `<span class="badge ...">` nodes inside the `<dd>`.

## Placement

The new "Specifications" section is inserted into `app/views/products/show.html.erb` below the existing "Product Details" prose block (currently around line 449), and above the "Related products" block (currently around line 467). It is full-width, matching the Product Details section's container.

## Implementation shape

### New `ProductSpecification` model

A plain Ruby value object at `app/models/product_specification.rb` — not an ActiveRecord class. Placed in `app/models/` to match the Rails autoload convention rather than introducing a new `app/presenters/` directory.

Public interface:

- `ProductSpecification.new(product)` — constructor takes a `Product`.
- `#dimensions` — returns an ordered array of `{ label:, value:, unit: }` hashes, filtered to exclude blank/zero values. Order matches the list in the Scope section (length, width, height, depth, diameter, weight, volume).
- `#materials` — returns an ordered array of `{ label:, value: }` hashes for `material`, `colour`, `size`, filtered to exclude blanks. The `certifications` field is exposed separately (see below) because it needs different rendering.
- `#certifications` — returns an array of strings (split on `/`, stripped, non-blank). Empty array if the source field is blank or contains only separators/whitespace.
- `#dimensions?`, `#materials?`, `#certifications?` — booleans indicating whether each group has any content.
- `#any?` — true if `dimensions? || materials? || certifications?`.

The view uses `#any?` to decide whether to render the whole section, and `#dimensions?` / `#materials?` (with `#certifications?` folded into the latter group's visibility) to decide which subgroups to render.

The object is purely presentational: no persistence, no validations, no callbacks.

### New partial

`app/views/products/_specifications.html.erb` receives a `ProductSpecification` as a local and renders the section. Two `<dl>` blocks inside a section wrapper. Tailwind + DaisyUI classes only. No inline styles. No `font-bold` / `font-semibold` classes (per project rules).

### Show view change

`app/views/products/show.html.erb` gains a single `render` call at the defined insertion point. The `ProductSpecification.new(@product)` can be built inline in the render call or via a small view helper — the spec writer's choice, as long as the model itself contains the logic.

### No controller changes

`ProductsController#show` already loads the necessary product. No new eager-loading needed because all spec fields are columns on `products`.

## Testing (TDD)

Project uses Minitest (`test/` directory). All test files follow that convention.

### `test/models/product_specification_test.rb`

Unit tests covering:

1. `#dimensions` returns an empty array when all dimension columns are nil.
2. `#dimensions` returns an empty array when all dimension columns are zero.
3. `#dimensions` excludes individual blank/zero fields and preserves order for partial data.
4. `#dimensions` returns every field for a fully populated product, in canonical order.
5. `#materials` behaves analogously — empty when all blank, omits individual blanks, preserves order.
6. `#certifications` returns `[]` for a nil or blank certifications string.
7. `#certifications` parses `"FSC / Compostable / BPI"` into `["FSC", "Compostable", "BPI"]`.
8. `#certifications` strips surrounding whitespace and ignores empty tokens (e.g., `"FSC //Compostable"` → `["FSC", "Compostable"]`).
9. `#any?` is false when dimensions, materials, and certifications are all empty.
10. `#any?` is true when any single field is present.
11. Group predicates (`#dimensions?`, `#materials?`, `#certifications?`) return correct booleans across the above scenarios.

### `test/system/product_specifications_test.rb` (or `test/integration/`)

Integration/system tests covering the rendered output:

1. Product with full specs — both groups render, all rows present, certifications render as badges.
2. Product with no spec data — "Specifications" heading does not appear on the page.
3. Product with only dimensions — Materials group absent, Dimensions group present.
4. Product with only materials — inverse of (3).
5. Product with partial dimensions (e.g., only length and weight) — only those two rows render, no empty rows.
6. Certifications rendering — each certification renders in its own `.badge` element, and the count matches the split.

Tests are written first (red), then implementation is added to make them pass (green).

## File changes summary

**New files:**
- `app/models/product_specification.rb`
- `app/views/products/_specifications.html.erb`
- `test/models/product_specification_test.rb`
- `test/system/product_specifications_test.rb` (exact location confirmed against existing test patterns at implementation time)

**Modified files:**
- `app/views/products/show.html.erb` — one `render` call inserted between the Product Details block and the Related products block.

## Constraints recorded from project rules

- TDD: tests written first.
- No inline styles.
- No `font-bold` or `font-semibold` classes.
- No em dashes in any output.
- Commit messages without Co-Authored-By lines.
