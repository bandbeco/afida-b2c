# Spec 2 — Generated Product SKUs

Date: 2026-06-08
Status: Draft (awaiting review)

Depends on: Spec 1 — Family SKU Codes + Data Hygiene
(`docs/superpowers/specs/2026-06-08-family-sku-codes-design.md`)

## Goal

Auto-generate a human-readable, stable, unique SKU from a product's structured
fields when none is provided, treating the result as an immutable identity key.

## Why SKU is not just `generated_title`

The original idea was to mirror `Product#generated_title`. The two share token
selection, but differ in one decisive way: `generated_title` is built to **change**
as attributes change (it is display text), whereas a SKU is an **identity key**.
It flows into `effective_sample_sku` (`"SAMPLE-#{sku}"`), historical order line
items, and admin search. If it mutated on every attribute edit it would silently
orphan those references.

Therefore: **generate once, then freeze.**

## Behaviour

- **Generate once, then freeze.** A `before_validation` callback fills `sku` only
  when it is blank and `name` is present, mirroring the existing `generate_slug`
  callback shape. Manual entry always wins; editing attributes later never
  recomputes the SKU.
- **Freeze is enforced, not incidental.** A persisted product's non-blank `sku`
  must not change. The callback's `sku.blank?` guard alone is not enough: if the
  field were cleared (admin blanks it, a bulk update nils it), the next
  validation would regenerate a different SKU from current attributes and orphan
  `SAMPLE-#{old_sku}` and historical line items. So the model also adds a
  validation forbidding a change to a persisted, previously-present `sku`:
  ```ruby
  validate :sku_is_immutable, on: :update
  def sku_is_immutable
    return unless sku_changed? && sku_was.present?
    errors.add(:sku, "cannot be changed once set")
  end
  ```
  (`attr_readonly :sku` is insufficient because it silently ignores the change
  rather than surfacing it; the validation makes accidental edits a visible
  error.)
- Existing products already have SKUs, so the generation callback never fires for
  them; no migration/backfill of existing SKUs is needed.
- `effective_sample_sku`, order line items, and admin search stay valid precisely
  because SKUs freeze.

## The three-tier recipe

```
Standalone (no family):       <NAME-ACRONYM>-<COLOUR?>-<SIZE?>
Single-name family:           <FAMILY-CODE>-<COLOUR?>-<SIZE?>
Multi-name family:            <FAMILY-CODE>-<NAME-TOKEN>-<COLOUR?>-<SIZE?>
```

A product is "multi-name family" when its family has more than one distinct
product `name` among its members.

### Tokens (all validated against the live catalogue)

- **Family code** — `family.sku_code` from Spec 1 (stored, curated, unique). No
  name-parsing for the 392 family products. When the family has no code yet,
  fall back to the standalone name-acronym path.

- **Name token / acronym** — derived from `name`. The operation order is
  significant and must be implemented exactly as listed:

  1. **Strip parenthetical clauses** (`Hot Cup Lid (Fits 79 Series)` drops the
     note).
  2. **Tokenize**: split on whitespace and punctuation, **including hyphens**, so
     `4-fold` -> `4`, `fold` and `62-Series` -> `62`, `Series`. Discard empty
     fragments. Do this on the raw words; do NOT drop stop-words yet.
  3. **Apply digit rules against raw adjacency** (before stop-word removal, so
     adjacency reflects the original name):
     - A pure-number word immediately followed by an alphabetic word that is NOT
       a stop-word is **glued** to that word's initial: `4 fold` -> `4F`,
       `2 ply` -> `2P`. So `4-fold 2-ply Dinner` -> `4F`, `2P`, plus `D` from
       Dinner -> `4F-2P-D`.
     - A pure-number word followed by `Series` (a stop-word) is **kept whole** as
       its own token: `89 Series` -> `89`; `62 Series Hot Cup Lid` -> `62` then
       `HCL` -> `62-HCL`. (Because the series exception is checked against raw
       adjacency, `62` does NOT glue to the later `Hot`; it is `62-HCL`, never
       `62H-CL`.)
     - A pure-number word followed by nothing / by another number / by a
       stop-word other than an alpha word is kept whole.
  4. **Drop stop-words** (`for the and with of in fits no series a to`) from the
     remaining alphabetic words.
  5. In a multi-name family, **subtract the family's common words** (see
     definition below) before forming initials, so the token carries only the
     distinguishing words: `Double Wall Coffee Cups` in the `Coffee Cups` family
     -> `DW`, not `DWCC`.
  6. **Build**: each remaining alphabetic word contributes its first letter,
     accumulated into runs; number tokens stand alone; join runs and number
     tokens with `-`. Upcase.

  **"Common words" definition (step 5):** the set of words (lowercased) in
  `family.name`, after the same parenthetical-strip + tokenize + stop-word-drop.
  A member-name word is subtracted if it appears in that set.

  **Glued number-tokens are exempt from subtraction.** Common-word subtraction
  (step 5) applies only to alphabetic words. A glued number-token from step 3
  (`4F`, `2P`) is never subtracted or re-split, so in the `Paper Napkins` family
  `4-fold 2-ply Dinner Napkins` keeps `4F`, `2P`, drops `Napkins`, and reduces
  `Dinner` to `D` -> `4F-2P-D`.

  **Empty-residual fallback:** if subtraction (or stop-word removal) leaves the
  name token empty, fall back to the full name acronym (steps 1-4, no
  subtraction). If that is also empty, omit the name token entirely so the SKU is
  `FAMILY-COLOUR-SIZE` with no stray `--`. Segments are joined such that no empty
  segment ever produces a double dash.

- **Colour** — strip non-alphanumerics, then take the first 3 chars, uppercased
  (so `Off-White` and `Off White` both -> `OFF`, never `OF `). **Included
  whenever present, omitted when blank.** Rationale: only 31% of products have a
  colour and it varies in just 33/117 families, but 41 (family, name, size)
  groups genuinely need it to stay distinct. "Include only when discriminating"
  cannot be computed reliably under generate-once (the first variant has no
  sibling yet), so the deterministic "include when present" rule is used. It
  avoids meaningless colour-clash suffixes at the cost of a redundant token in
  single-colour families.

- **Size** — the existing `size.presence || derived_size`. Take the primary
  value before any `/`, sanitize to alphanumerics, keep the unit:
  `12oz / 340ml` -> `12OZ`; `8 x 200mm` -> `8X200MM`. `derived_size` order is
  reused unchanged (volume -> linear LxWxH -> weight). Omitted when no size data.

- **Short-code guard (standalone only)** — if a standalone name acronym is <= 3
  chars AND the product has no colour and no size to lengthen it, expand the
  acronym to the first **3** letters of each (non-stop-word) name word (capped at
  the word's length), joined by `-`, instead of just the first letter:
  `Greaseproof Paper` -> `GRE-PAP`, not `GP`. Number tokens are unaffected.
  Prevents fragile 2-letter SKUs.

### Uniqueness

- Compute the candidate. If `Product.exists?(sku: candidate)`, append `-2`;
  re-check that, and if it also exists try `-3`, and so on (increment-and-recheck
  loop, so a pre-existing `-2` is skipped). The first free value wins.
- This in-process check handles the common case. It is not race-safe on its own:
  two concurrent inserts can both pass the check and pick the same suffix. The
  `products.sku` unique index converts that race into a
  `ActiveRecord::RecordNotUnique` on `save`.
- **Race handling.** A `Product.create`/`save` wrapper (a class method
  `Product.create_with_generated_sku` used by the admin controller and imports,
  or an overridden `save` that opts in) rescues `RecordNotUnique` once. The
  rescue must **reset `self.sku = nil` before retrying**, because otherwise the
  `before_validation` guard (`sku.blank?`) would see the colliding non-blank
  value and skip regeneration, re-saving the same SKU into the same failure.
  After resetting to nil and re-saving, `generate_sku` re-runs, `exists?` now
  sees the winning row, and the loser picks the next free suffix. A second
  consecutive `RecordNotUnique` is allowed to propagate (genuinely exceptional).
  This keeps a concurrent create from surfacing a 500 to the user. The
  immutability validation is `on: :update`, so resetting `sku` to nil during a
  create retry does not trip it.
- Because the recipe encodes the meaningful differentiators (family, name axis,
  colour, size), numeric suffixes are rare: a full-catalogue dry run produced a
  5.8% raw collision rate (39/672), and most of those are genuine data
  duplicates (see the recipe-collision audit below) rather than recipe failures.

### Recipe-collision audit (moved here from Spec 1)

Because detecting these collisions requires this recipe, a read-only rake task
(`sku:collision_audit`, throwaway data task) computes the candidate SKU for every
product and reports the groups that collide (the ~39 products, e.g. `PPL-1OZ` x3,
`CCL-WHI-12OZ` x2). Most are genuine data duplicates; the report lets a human fix
the underlying data before relying on the recipe, or knowingly accept the numeric
suffix. Output is to stdout, matching the project's rake-report pattern.

## Worked examples (from the live catalogue)

The "Product" column below is the human-readable display (the `generated_title`
style). The SKU is built from **structured fields**, not by parsing that display
string: e.g. for the Clamshell Box the raw `name` is `Clamshell Box`, with
`size = "9in"` and `colour = "White"` as separate columns, and the `89 Series` /
`16oz` / `Brown` parts of the cup come from the family code and the size/colour
columns. The name token never re-pulls size/colour that live in their own fields.

| Product | Family | SKU |
| --- | --- | --- |
| Single Wall Takeaway Hot Cup, 89 Series, 16oz Brown | single-name family | `SWTHC-89-BRO-16OZ` |
| Double Wall Coffee Cups, 12oz White | Coffee Cups (multi-name) | `CC-DW-WHI-12OZ` |
| Ripple Wall Coffee Cups, 12oz Kraft | Coffee Cups (multi-name) | `CC-RW-KRA-12OZ` |
| 4-fold 2-ply Dinner Napkins, 40x40cm Black | Paper Napkins (multi-name) | `PN-4F-2P-D-BLA-40X40CM` |
| 62-Series Hot Cup Lid | standalone | `62-HCL-65X15MM` |
| Greaseproof Paper | standalone | `GRE-PAP` |
| Clamshell Box, 9in White | standalone | `CB-WHI-9IN` |

## Architecture

- **`Product#generate_sku`** — thin `before_validation` callback target:
  ```ruby
  before_validation :generate_sku, if: -> { sku.blank? && name.present? }

  def generate_sku
    self.sku = Sku::Generator.new(self).call
  end
  ```
- **`Sku::Generator`** (PORO, `app/models/sku/generator.rb`) — public `#call`
  returns the final unique string. Private methods: `family_code`, `name_token`,
  `colour_token`, `size_token`, `acronym` (with digit-glue + stop-words),
  `short_code_guard`, `dedupe`. Reuses `Product#derived_size`. Reads only public
  attribute readers on `Product`; keeps `Product` from growing a fifth large
  method beside the SEO trio.

## Testing

This project uses **Minitest** (`test/`, no `spec/`). TDD is required for this
app code.

`Sku::Generator` test (`test/models/sku/generator_test.rb`), driven by the
worked examples and the rule edge cases:

- single-name family -> `FAMILY-COLOUR-SIZE` (`SWTHC-89-BRO-16OZ`)
- multi-name family with family-word subtraction (`CC-DW-WHI-12OZ`)
- digit-glue for fold/ply: `4-fold 2-ply Dinner Napkins` tokenizes to
  `4,fold,2,ply,Dinner,Napkins` then glues to `4F-2P-D...` (assert the full
  `PN-4F-2P-D-BLA-40X40CM`)
- series-number retention: `62-Series Hot Cup Lid` -> `62-HCL`, and a **negative
  assertion** that it is NOT `62H-CL` (guards the rule-ordering)
- colour omitted when blank; colour included when present; colour with
  punctuation/space (`Off-White`, `Off White`) -> `OFF`
- size fallback chain (free-text size, then volume, then linear LxWxH, then
  weight); a free-text size with repeated units (`8mm x 200mm`) sanitizes to the
  canonical `8MMX200MM` (no `/` present, take whole string, strip non-alphanumerics,
  upcase). Assert exactly this string.
- standalone short-code guard (`Greaseproof Paper` -> `GRE-PAP`)
- empty-residual fallback: a multi-name family member whose name is entirely
  family-common words falls back to the full acronym, and a name that reduces to
  nothing omits the token with no `--`
- family-code path does no name-parsing: a single-name family product whose name
  contains digits still yields `FAMILY-COLOUR-SIZE` with no name token leaking in
- collision -> `-2`, and `-3` when `-2` already exists (increment-and-recheck)
- family without `sku_code` -> standalone name path (graceful fallback)

`Product` model test:

- blank `sku` + `name` present -> generated on validation
- present `sku` -> left untouched (freeze) on create
- updating other attributes does not change a persisted `sku`
- attempting to change or clear a persisted `sku` fails the immutability
  validation (does not regenerate)
- concurrent-create race: a `RecordNotUnique` on first save is rescued and the
  retry picks the next suffix (can be tested by stubbing the first save to raise)

## Out of scope

- Backfilling/regenerating SKUs for existing products (they keep theirs).
- Any data cleanup of leaked-attribute names (Spec 1's defect report).
- A `variant_type` column (Spec 1 out-of-scope rationale).
