# Implementation Plan: Variant-Level Sample Request System

**Branch**: `011-variant-samples` | **Date**: 2025-12-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/011-variant-samples/spec.md`

## Summary

Enable visitors to request up to 5 free product variant samples, browsing by category and checking out via Stripe with £7.50 flat shipping (or free when combined with paid products). The implementation extends existing ProductVariant, Cart, and Order models with sample-specific fields and logic, adds a new SamplesController with Turbo Frame-based category expansion, and modifies checkout shipping logic to handle samples-only vs mixed carts.

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x
**Primary Dependencies**: Rails 8 (ActiveRecord, ActionView), Hotwire (Turbo Frames + Stimulus), TailwindCSS 4, DaisyUI, Stripe Checkout
**Storage**: PostgreSQL 14+ (existing `products`, `product_variants`, `carts`, `cart_items`, `orders`, `order_items` tables)
**Testing**: Rails Minitest (unit, integration, system tests with Capybara + Selenium)
**Target Platform**: Web application (UK market)
**Project Type**: Web application (Rails monolith with Vite frontend)
**Performance Goals**: Sample page loads in <1s, add-to-cart via Turbo in <200ms
**Constraints**: UK-only shipping, max 5 samples per order, £7.50 flat shipping for samples-only
**Scale/Scope**: Existing e-commerce site, ~50-100 sample-eligible variants expected

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Design Check (Phase 0)

| Principle | Status | Evidence/Notes |
|-----------|--------|----------------|
| I. Test-First Development | ✅ PASS | Tasks will be structured with tests written before implementation |
| II. SEO & Structured Data | ✅ PASS | /samples page will include meta tags, canonical URL; no structured data needed (not product detail) |
| III. Performance & Scalability | ✅ PASS | Uses Turbo Frames for partial updates, SQL-based sample counting |
| IV. Security & Payment Integrity | ✅ PASS | Stripe Checkout handles payment; sample validation server-side; no new admin auth required (uses existing) |
| V. Code Quality & Maintainability | ✅ PASS | Follows Rails conventions, RuboCop compliance, reversible migrations |
| Technology Constraints | ✅ PASS | Uses Hotwire (no React/Redux), Rails conventions, PostgreSQL |

**Gate Result**: PASS - All constitution principles satisfied. No violations requiring justification.

### Post-Design Check (Phase 1)

| Principle | Status | Evidence/Notes |
|-----------|--------|----------------|
| I. Test-First Development | ✅ PASS | Test files specified in quickstart.md; TDD workflow defined |
| II. SEO & Structured Data | ✅ PASS | Meta tags for /samples page in index.html.erb; canonical URL via application layout |
| III. Performance & Scalability | ✅ PASS | Turbo Frames for lazy loading categories; SQL joins for sample counting (no N+1) |
| IV. Security & Payment Integrity | ✅ PASS | Server-side validation of sample eligibility and limits; Stripe handles payment |
| V. Code Quality & Maintainability | ✅ PASS | Reversible migration; follows existing patterns; no new abstractions |
| Technology Constraints | ✅ PASS | All patterns use Hotwire (Turbo + Stimulus); no client-side state management |

**Post-Design Gate Result**: PASS - Design artifacts comply with all constitution principles.

## Project Structure

### Documentation (this feature)

```text
specs/011-variant-samples/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
app/
├── controllers/
│   ├── samples_controller.rb          # NEW: Browse/select samples
│   ├── cart_items_controller.rb       # MODIFY: Handle sample additions
│   └── checkouts_controller.rb        # MODIFY: Shipping logic for samples
├── models/
│   ├── product_variant.rb             # MODIFY: Add sample_eligible, sample_sku
│   ├── cart.rb                        # MODIFY: Add sample tracking methods
│   └── order.rb                       # MODIFY: Add sample detection methods
├── views/
│   └── samples/                       # NEW: Samples browsing views
│       ├── index.html.erb
│       ├── _category_card.html.erb
│       ├── _category_variants.html.erb
│       ├── _variant_card.html.erb
│       └── _sample_counter.html.erb
├── frontend/javascript/controllers/
│   ├── category_expand_controller.js  # NEW: Category toggle
│   └── sample_counter_controller.js   # NEW: Counter visibility
└── views/admin/
    ├── product_variants/_form.html.erb  # MODIFY: Sample eligibility fields
    └── orders/                          # MODIFY: Sample badges/filters

db/migrate/
└── YYYYMMDDHHMMSS_add_sample_fields_to_product_variants.rb  # NEW

config/
└── routes.rb                          # MODIFY: Add /samples routes

test/
├── models/
│   ├── product_variant_test.rb        # MODIFY: Sample scope tests
│   ├── cart_test.rb                   # MODIFY: Sample tracking tests
│   └── order_test.rb                  # MODIFY: Sample detection tests
├── controllers/
│   ├── samples_controller_test.rb     # NEW
│   ├── cart_items_controller_test.rb  # MODIFY: Sample handling tests
│   └── checkouts_controller_test.rb   # MODIFY: Shipping logic tests
└── system/
    └── sample_request_flow_test.rb    # NEW: E2E sample flow tests
```

**Structure Decision**: Rails monolith following existing conventions. New `samples_controller.rb` and views added; existing models/controllers extended. No new architectural patterns introduced.

## Complexity Tracking

> No violations requiring justification. Feature follows existing patterns.

| Aspect | Complexity Level | Notes |
|--------|------------------|-------|
| Database changes | Low | 2 columns added to existing table |
| New routes | Low | 2 new routes for samples browsing |
| Model changes | Low | Scopes and helper methods only |
| Controller logic | Medium | Shipping branching logic in checkout |
| Frontend | Medium | Turbo Frame expansion pattern |
| Admin UI | Low | Form fields and badges/filters |
