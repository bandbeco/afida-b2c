# Implementation Plan: Unified Variant Selector

**Branch**: `015-variant-selector` | **Date**: 2025-12-18 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/015-variant-selector/spec.md`

## Summary

Unify the standard product UI and consolidated product configurator into a single variant selector component. Replace three separate Stimulus controllers with one unified `variant_selector_controller.js`, migrate option data from ProductOption tables to variant `option_values` JSON, and implement an accordion-style UI with auto-collapse behavior and support for volume pricing tiers.

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x, JavaScript ES6+ (Stimulus)
**Primary Dependencies**: Rails 8 (ActiveRecord, ActionView), Vite Rails, Stimulus, TailwindCSS 4, DaisyUI
**Storage**: PostgreSQL 14+ (existing `products`, `product_variants` tables; new `pricing_tiers` JSONB column)
**Testing**: Rails Minitest, Capybara + Selenium for system tests
**Target Platform**: Web (desktop + mobile responsive)
**Project Type**: Web application (Rails monolith with Vite frontend)
**Performance Goals**: Product page load <2s, variant selector interaction <100ms response
**Constraints**: Must preserve existing product page layout, backward compatible cart flow
**Scale/Scope**: ~27 active products, ~100 variants, all non-branded products

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First Development | ✅ PASS | Tests written before implementation; fixtures used |
| II. SEO & Structured Data | ✅ PASS | No SEO changes needed; product pages retain existing SEO |
| III. Performance & Scalability | ✅ PASS | Single controller reduces JS bundle; eager loading maintained |
| IV. Security & Payment Integrity | ✅ PASS | No payment flow changes; cart addition unchanged |
| V. Code Quality & Maintainability | ✅ PASS | Eliminates duplicate code (3→1 controllers); RuboCop compliance |
| Technology Constraints | ✅ PASS | Using Hotwire/Stimulus patterns; no external state management |

**Gate Status**: PASSED - No violations requiring justification.

## Project Structure

### Documentation (this feature)

```text
specs/015-variant-selector/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A - no new API endpoints)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
app/
├── models/
│   ├── product.rb                    # Add extract_options_from_variants, variants_for_selector
│   └── product_variant.rb            # Add pricing_tiers column
├── controllers/
│   └── products_controller.rb        # Simplify show action (remove branching)
├── views/products/
│   ├── show.html.erb                 # Update to use _variant_selector
│   └── _variant_selector.html.erb    # NEW: unified partial
├── helpers/
│   └── variant_selector_helper.rb    # NEW: natural sort, option extraction helpers
└── frontend/
    └── javascript/controllers/
        └── variant_selector_controller.js  # NEW: unified Stimulus controller

db/migrate/
└── YYYYMMDDHHMMSS_add_pricing_tiers_to_product_variants.rb

lib/tasks/
└── product_options.rake              # Migration rake task

test/
├── models/
│   └── product_variant_test.rb       # Pricing tiers tests
├── controllers/
│   └── products_controller_test.rb   # Show action tests
├── helpers/
│   └── variant_selector_helper_test.rb
├── system/
│   └── variant_selector_test.rb      # Full UI flow tests
└── fixtures/
    └── product_variants.yml          # Add pricing_tiers fixture data
```

**Files to Remove (Phase 3 - after migration verified):**
- `app/frontend/javascript/controllers/product_options_controller.js`
- `app/frontend/javascript/controllers/product_configurator_controller.js`
- `app/views/products/_standard_product.html.erb`
- `app/views/products/_consolidated_product.html.erb`
- `app/views/products/_configurator.html.erb`
- `app/models/product_option.rb`
- `app/models/product_option_value.rb`
- `app/models/product_option_assignment.rb`
- Related database tables (via migration)

**Structure Decision**: Rails monolith with Vite frontend. New files follow existing conventions. Feature adds one new Stimulus controller and one new partial, replacing three controllers and five partials.

## Complexity Tracking

> No violations requiring justification - Constitution Check passed.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none) | - | - |
