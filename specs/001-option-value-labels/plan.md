# Implementation Plan: Product Option Value Labels

**Branch**: `001-option-value-labels` | **Date**: 2026-01-06 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-option-value-labels/spec.md`

## Summary

Replace the JSONB `option_values` column on `product_variants` with a proper join table (`variant_option_values`) that links variants to `ProductOptionValue` records. This enables clean separation of stored values (machine-readable, e.g., "7in") from display labels (human-readable, e.g., "7 inches (30cm)") while maintaining backwards compatibility with the variant selector frontend.

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x
**Primary Dependencies**: Rails ActiveRecord, PostgreSQL, Hotwire (Turbo + Stimulus), TailwindCSS 4, DaisyUI
**Storage**: PostgreSQL 14+ (new `variant_option_values` join table)
**Testing**: Rails Minitest with fixtures
**Target Platform**: Web application (Linux server deployment)
**Project Type**: Web (monolithic Rails app with Vite frontend)
**Performance Goals**: No N+1 queries on product pages; variant selector response identical to current
**Constraints**: Pre-launch site - data can be re-seeded; variant selector JS receives unchanged data structure
**Scale/Scope**: ~50 products with ~200 variants; existing option values in seed data

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First Development | ✅ PASS | Tests will be written first for new model, updated model methods, and views |
| I. Fixtures MUST Be Used | ✅ PASS | Fixtures will be created for VariantOptionValue; existing fixtures updated |
| II. SEO & Structured Data | ✅ N/A | Internal data change; no public URL or structured data impact |
| III. Performance & Scalability | ✅ PASS | Eager loading with `includes()` prevents N+1; SQL-based joins |
| IV. Security & Payment Integrity | ✅ N/A | No security-sensitive changes; data integrity enforced via FK constraints |
| V. Code Quality & Maintainability | ✅ PASS | Single responsibility; reversible migrations; clear naming |
| Technology Constraints | ✅ PASS | Uses Rails/ActiveRecord patterns; no new frameworks introduced |

**Gate Result**: PASS - No violations. Proceed to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/001-option-value-labels/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A - no API changes)
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
app/
├── models/
│   ├── variant_option_value.rb      # NEW: Join table model
│   ├── product_variant.rb           # UPDATE: Add associations, option_values_hash, option_labels_hash
│   ├── product.rb                   # UPDATE: Replace extract_options_from_variants with available_options
│   └── product_option_value.rb      # UNCHANGED
├── helpers/
│   └── products_helper.rb           # UPDATE: Remove option_value_label method
└── views/
    └── [various]                    # UPDATE: Use option_labels_hash instead of option_values

db/
├── migrate/
│   ├── YYYYMMDD_create_variant_option_values.rb  # NEW
│   └── YYYYMMDD_remove_option_values_from_product_variants.rb  # NEW
└── seeds/
    └── products_from_csv.rb         # UPDATE: Use join table assignment

test/
├── models/
│   ├── variant_option_value_test.rb # NEW
│   └── product_variant_test.rb      # UPDATE: Test new methods
├── fixtures/
│   └── variant_option_values.yml    # NEW
└── system/
    └── variant_selector_test.rb     # UPDATE: Verify unchanged behavior
```

**Structure Decision**: Standard Rails monolith structure with new model in `app/models/`, migration in `db/migrate/`, tests following existing patterns.

## Post-Design Constitution Check

*Re-evaluated after Phase 1 design completion.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First Development | ✅ PASS | data-model.md defines testable entities; quickstart.md includes test commands |
| I. Fixtures MUST Be Used | ✅ PASS | data-model.md notes fixtures; no inline `create!` in design |
| II. SEO & Structured Data | ✅ N/A | No public-facing URL or schema.org changes |
| III. Performance & Scalability | ✅ PASS | research.md documents eager loading patterns; N+1 prevention |
| IV. Security & Payment Integrity | ✅ N/A | FK constraints provide data integrity; no payment flow changes |
| V. Code Quality & Maintainability | ✅ PASS | Clean separation; reversible migrations; single responsibility |
| Technology Constraints | ✅ PASS | Pure Rails/ActiveRecord; no new dependencies |

**Post-Design Gate Result**: PASS - Design aligns with all constitution principles.

## Complexity Tracking

> No violations - table not needed.
