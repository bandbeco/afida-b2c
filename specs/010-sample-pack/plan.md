# Implementation Plan: Sample Pack

**Branch**: `010-sample-pack` | **Date**: 2025-11-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/010-sample-pack/spec.md`
**Design**: [docs/plans/2025-11-30-sample-pack-design.md](../../docs/plans/2025-11-30-sample-pack-design.md)

## Summary

Enable site visitors to request a free sample pack of eco-friendly products, paying only for shipping. The sample pack is implemented as a regular £0.00 Product that integrates with the existing cart and checkout flow. Key additions include model methods for identification (`sample_pack?`), a `shoppable` scope for exclusion from listings, cart validation limiting to 1 per order, and UI modifications for price display and quantity hiding.

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x
**Primary Dependencies**: Rails 8 (ActiveRecord, ActionController, ActionView), Hotwire (Turbo + Stimulus), TailwindCSS 4, DaisyUI
**Storage**: PostgreSQL 14+ (existing `products`, `product_variants`, `carts`, `cart_items` tables — no schema changes)
**Testing**: Rails Minitest (models, controllers, system tests)
**Target Platform**: Web application (Heroku/Kamal deployment)
**Project Type**: Web (Rails monolith)
**Performance Goals**: No degradation to existing cart/checkout performance
**Constraints**: Must integrate with existing Stripe Checkout flow unchanged
**Scale/Scope**: Single product addition, ~10 files modified

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First Development | ✅ PASS | Tests will be written first for model methods, scopes, cart validation, and UI |
| II. SEO & Structured Data | ✅ PASS | Samples landing page has meta tags; product page uses existing SEO infrastructure |
| III. Performance & Scalability | ✅ PASS | `has_sample_pack?` uses efficient `exists?` query; no N+1 concerns |
| IV. Security & Payment Integrity | ✅ PASS | No payment changes; existing Stripe Checkout flow unchanged |
| V. Code Quality & Maintainability | ✅ PASS | Uses existing patterns (scopes, model methods); RuboCop compliance required |

**Constitution Check Result**: ✅ ALL GATES PASS — No violations requiring justification.

## Project Structure

### Documentation (this feature)

```text
specs/010-sample-pack/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (minimal — no new API endpoints)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
app/
├── models/
│   ├── product.rb           # Add SAMPLE_PACK_SLUG constant, sample_pack? method, shoppable scope
│   └── cart.rb              # Add has_sample_pack? method, sample_pack_quantity_limit validation
├── controllers/
│   ├── cart_items_controller.rb  # Add sample pack check before add-to-cart
│   ├── pages_controller.rb       # Update samples action to load sample pack
│   └── products_controller.rb    # Update to use shoppable scope (if not already)
├── views/
│   ├── pages/
│   │   └── samples.html.erb      # Redesign as marketing landing page
│   ├── products/
│   │   └── _standard_product.html.erb  # Conditionally hide quantity, show "Free" price
│   └── carts/
│       └── _cart_item.html.erb   # Show "Free" for sample pack items
└── helpers/
    └── pricing_helper.rb         # Optional: Add sample pack price formatting

test/
├── models/
│   ├── product_test.rb           # Test sample_pack? method and shoppable scope
│   └── cart_test.rb              # Test has_sample_pack? and validation
├── controllers/
│   └── cart_items_controller_test.rb  # Test "already in cart" redirect
└── system/
    ├── sample_pack_test.rb       # End-to-end add-to-cart from landing page
    └── sample_pack_product_page_test.rb  # Product page quantity hidden, price display
```

**Structure Decision**: Standard Rails MVC structure. No new directories or architectural changes. All modifications are additive to existing files.

## Complexity Tracking

> No violations requiring justification. Feature follows existing patterns with minimal additions.

| Aspect | Complexity | Justification |
|--------|-----------|---------------|
| Model changes | Low | 2 methods + 1 scope added to existing models |
| Controller changes | Low | Guard clause in 1 action, load product in another |
| View changes | Low | Conditional rendering based on `sample_pack?` |
| Testing | Medium | Unit + controller + system tests required (TDD mandated) |
| Data model | None | No migrations — uses existing schema |
