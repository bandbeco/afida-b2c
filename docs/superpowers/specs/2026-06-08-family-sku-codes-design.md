# Spec 1 — Family SKU Codes + Data Hygiene

Date: 2026-06-08
Status: Draft (awaiting review)

## Background

We want to auto-generate product SKUs from product details (Spec 2). The
investigation that led here found that the product `name` field is overloaded:
it carries facts that belong in structured fields (series number, wall type,
fold/ply, fitment notes, and sometimes leaked size/colour). Parsing those out
of prose at SKU-generation time is fragile.

The key insight is that the **product family layer already encodes most of that
structure**. Validated against the live catalogue (672 products):

- 119 families; 117 are healthy multi-product groups (only 2 singletons, 0 empty).
- 392 products belong to a family; 269 are genuine standalones; ~9 are stragglers.
- Within a family, products differ almost entirely by **size and colour**.
- 108 of 117 multi-product families share a single product `name`; 9 span
  multiple names. Of those 9, 5 are genuine variant axes (wall type, lid shape,
  handle type, item type, napkin fold/ply) and 4 are data-quality defects where
  size/colour/fitment leaked into a second name.

Spec 2's recipe composes a per-family code with the variant axes. For that to be
robust, the family code must be a **stored, curated, unique identifier on
`ProductFamily`**, not a value recomputed from the family name at runtime.

## Why store the code (not derive it at runtime)

Generating the code from `family.name` on demand fails for two reasons proven by
the data:

1. **Cross-family collisions.** Pure-initials codes clash: 16 codes collide
   across 33 of the 119 families. Examples: `CC` = Coffee Cups / Cup Carriers;
   `CS` = Coffee Stirrers / Cocktail Straw; `RFC` = Rectangular / Round Food
   Container; `RKB` = Rectangular / Round Kraft Bowls; `RP` = Rectangle / Round
   Plate. The Rectangular-vs-Round pattern has no automatic resolution (both
   start with R) — a human must choose `REC` vs `RND`. A two-family code clash
   cascades to every product in both families, which is worse than a
   product-level clash.

2. **Stability under generate-once-freeze.** Spec 2 freezes a product's SKU once
   assigned. If the family code were derived from the current name, renaming a
   family later would silently change the stem every new product would get,
   drifting from the frozen SKUs of existing siblings. A stored code is immune.

So the generator's role is to **propose**, and a human **curates and freezes**
the result. With only 119 families this is a one-time ~20-minute pass.

## Scope

### 1. `ProductFamily.sku_code` column

- Migration: `add_column :product_families, :sku_code, :string`.
- Unique index, allowing NULL, with an explicit name (Postgres; the prod adapter
  is `pg`):
  `add_index :product_families, :sku_code, unique: true, where: "sku_code IS NOT NULL", name: "index_product_families_on_sku_code"`.
- Model validation: `validates :sku_code, uniqueness: { case_sensitive: false }, allow_nil: true`.
- Codes are stored **uppercase**; a `before_validation` upcases `sku_code` when
  present, so `cc` and `CC` cannot both slip past the index.
- The code is nullable so a family can exist before curation; Spec 2 falls back
  to the name-based path when a product's family has no code yet.
- The migration only adds the column/index; the seed task (section 3) runs as a
  separate deploy step after the migration.

### 2. `Sku::FamilyCodeGenerator` (suggestion only)

A PORO that proposes a code from a family name. It is used to seed the column and
to suggest a default in the admin form, but is **never** the source of truth at
SKU-generation time.

Algorithm (matches the validated prototype):

- Strip a leading manufacturer prefix, case-insensitively. The known prefixes
  are `Vegware`, `Planetware`, `Edenware` (manufacturers, not identity; see
  project memory `catalog_supplier_vs_manufacturer`). Only a leading prefix is
  stripped, only one, and only when followed by more words.
- Strip parenthetical clauses.
- Tokenize: split on whitespace and punctuation (including hyphens, so
  `4-fold` -> `4`, `fold`); discard empty fragments.
- Drop stop-words (`for the and with of in fits no series a to`).
- Build the code: alphabetic word -> first letter, accumulated into a run; a
  word containing a digit is emitted whole as its own dash-delimited token,
  flushing the current letter run.
- **Upcase** the result.

Worked outputs (these are the expected test cases):

| Family name | Suggested code |
| --- | --- |
| `Coffee Cups` | `CC` |
| `coffee cups` (casing) | `CC` |
| `Single Wall Takeaway Hot Cup, 89 Series` | `SWTHC-89` |
| `Vegware Burger Box` | `BB` |
| `Rectangular Food Container` | `RFC` |
| `Food Bowl Lids For 500, 750 ( Diameter)` | `FBL-500-750` |
| name reducing to nothing after stop-words (e.g. `Series`) | `""` (empty; the
  seed task skips it and lists the family in the report for manual entry) |

Multiple digit-words are emitted in source order, each its own token
(`...500-750`). The generator does NOT attempt to resolve collisions or
guarantee uniqueness; that is the curation step (sections 3-4).

### 3. Seeding + clash report rake task

A rake task (`sku:seed_family_codes`, throwaway data task; TDD not required per
project convention) that:

- For every family without a `sku_code`, computes the suggested code.
- Determines which suggestions are **shared by two or more families** or already
  taken by an existing `sku_code`. A code in that set is written for **none** of
  the families that produced it (not first-wins); all of them are left NULL and
  listed in the report. This is deterministic regardless of iteration order.
- Writes the suggestion only for families whose code is unique and unclaimed,
  and whose code is non-empty.
- Prints a **clash report** listing each colliding code and the families sharing
  it, plus any family whose suggestion was empty, so a human can resolve them
  (e.g. `RECFC` vs `RNDFC`). Against the live catalogue this is 16 codes across
  33 families. The count is reproducible because the skip-all-on-clash rule does
  not depend on order.
- Supports `--dry-run` (or a `DRY_RUN=1` env flag) to print the report and the
  intended writes without persisting, so the clash list can be previewed.

The seed task is idempotent: it only ever fills NULL codes, never overwrites a
curated one.

### 4. Admin curation

There is currently **no** `ProductFamily` admin surface (families are only
referenced indirectly via the `product_family_id` param on the products
controller). The human-curation step needs one, so this spec adds a minimal one:

- `Admin::ProductFamiliesController` with `index`, `edit`, and `update` actions,
  plus the route. Follows the existing `Admin::ProductsController` patterns
  (auth, layout, strong params).
- **Index**: lists all families with their `sku_code`, product count, and a
  clash/blank status flag, so the curator can see at a glance which need
  attention (the 33 from the seed report).
- **Edit/update**: an editable `sku_code` field. When the stored code is blank,
  pre-fill the input with the `Sku::FamilyCodeGenerator` suggestion as a
  placeholder/default, but persist only what the human submits. The model upcases
  and uniqueness-validates on save, so a duplicate is rejected with a form error.
- This is the load-bearing surface for resolving the 16 clashing codes; without
  it the seed task's NULLs could only be filled via the Rails console.

### 5. Straggler report

A read-only rake task listing family-less products whose name-stems repeat
(~9 products across ~5 stems, e.g. `Birchwood Cutlery Kit`, `Oval Plate`), for a
human to group into families (or confirm standalone). No auto-grouping.

### 6. Defect report

A read-only rake task flagging products where structured facts appear to have
leaked into `name`, for manual fix in admin. No auto-parsing (the leaked text is
ambiguous, e.g. `Food Bowl Lids For 500, 750 ( Diameter)`). Scoped to what is
detectable from family/name data alone:

- The 4 defective multi-name families (Vented Lids, Gourmet Base, Food Bowl
  Lids, Printed Burger Wraps) where size/colour/fitment leaked into a name.

The complementary "recipe-collision audit" (the ~39 products that produce a
colliding SKU, e.g. `PPL-1OZ` x3, `CCL-WHI-12OZ` x2) requires Spec 2's
composition to detect, so it lives in **Spec 2**, not here. This keeps Spec 1
free of any dependency on Spec 2 (Spec 1 must land first).

## Out of scope

- A rigid `variant_type` column. The 5 genuine intra-family axes are each
  different (wall / lid-shape / handle / item / fold-ply), so a single column
  would be a junk drawer. Spec 2's name token carries the axis instead.
- Auto-parsing leaked attributes out of `name` (manual, via the report).
- Fitment as a column (it is a relationship; `product_compatible_lid` exists).

## Testing

This project uses **Minitest** (`test/`, no `spec/`). Tests below are Minitest
tests; TDD is required for the app code (the generator PORO and model validation).

- `Sku::FamilyCodeGenerator` test (`test/models/sku/family_code_generator_test.rb`):
  assert every row of the worked-output table above, plus:
  - case-insensitive manufacturer-prefix strip for all three of Vegware /
    Planetware / Edenware
  - parenthetical stripping
  - stop-word removal
  - multi-digit-word ordering (`...500-750`)
  - empty result when the name reduces to nothing after stop-words
- `ProductFamily` model test: `sku_code` uniqueness (case-insensitive), NULL
  allowed, and that a present `sku_code` is upcased on save.
- Rake tasks are throwaway data tasks; TDD not required per project convention.
  Reports print to stdout (consistent with the project's existing rake-report
  pattern). The seed task's report should be eyeballed against the known
  16-code / 33-family clash list once.

## Dependencies / sequencing

This spec must land before Spec 2, which reads the stored `sku_code`.
