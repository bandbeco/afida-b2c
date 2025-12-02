# Implementation Plan: Pricing Display Consolidation

**Branch**: `008-pricing-display` | **Date**: 2025-11-26 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/008-pricing-display/spec.md`

## Summary

Consolidate pricing display logic for standard (pack-priced) and branded (unit-priced) products. Currently, order views show incorrect "£X.XX each" format for all items. The solution adds a `pac_size` column to `order_items`, updates OrderItem to store pack price (not unit price), adds model methods (`pack_priced?`, `pack_price`, `unit_price`) to both OrderItem and CartItem, and creates a centralized `PricingHelper#format_price_display` method used across all 4 touchpoints: order confirmation page, admin order views, PDF summaries, and cart.

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x
**Primary Dependencies**: Rails (ActiveRecord, ActionView helpers), Prawn (PDF generation)
**Storage**: PostgreSQL 14+ (existing `order_items` table, new `pac_size` column)
**Testing**: Minitest (Rails default), Capybara for system tests
**Target Platform**: Web application (Rails server)
**Project Type**: Existing Rails monolith
**Performance Goals**: No additional database queries; derived values only
**Constraints**: Must maintain backward compatibility for any existing orders (graceful fallback to unit pricing)
**Scale/Scope**: 4 view touchpoints, 2 models, 1 helper, 1 migration

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Design Check (Phase 0)

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First Development | PASS | Tests will be written before implementation for helper, model methods, and views |
| II. SEO & Structured Data | N/A | Internal order views, not public-facing pages |
| III. Performance & Scalability | PASS | No additional queries; `pac_size` stored on order_item avoids joins |
| IV. Security & Payment Integrity | PASS | Display-only change; no payment logic affected |
| V. Code Quality & Maintainability | PASS | Centralizes duplicated logic into single helper; follows DRY principle |

**Technology Constraints Check**:
- No client-side frameworks: PASS (server-side helper)
- No GraphQL: PASS (no API changes)
- Backend rendering: PASS (Rails view helpers)

### Post-Design Re-Check (Phase 1)

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First Development | PASS | Test files defined in project structure; TDD workflow documented in quickstart |
| II. SEO & Structured Data | N/A | No changes to public pages |
| III. Performance & Scalability | PASS | Single nullable integer column; no queries added; derived calculations only |
| IV. Security & Payment Integrity | PASS | Read-only display logic; payment flow unchanged |
| V. Code Quality & Maintainability | PASS | Helper pattern follows Rails conventions; duck typing enables CartItem/OrderItem reuse |

**Post-Design Verification**: All principles still pass. No complexity violations introduced.

## Project Structure

### Documentation (this feature)

```text
specs/008-pricing-display/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A - no API contracts)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
app/
├── helpers/
│   └── pricing_helper.rb          # NEW: Centralized pricing display logic
├── models/
│   ├── order_item.rb              # MODIFY: Add pack_priced?, pack_price, unit_price methods
│   └── cart_item.rb               # MODIFY: Add pack_priced? method for consistency
├── services/
│   └── order_pdf_generator.rb     # MODIFY: Use format_price_display helper
└── views/
    ├── orders/
    │   └── show.html.erb          # MODIFY: Use format_price_display helper
    ├── admin/orders/
    │   └── show.html.erb          # MODIFY: Use format_price_display helper
    └── cart_items/
        └── _cart_item.html.erb    # MODIFY: Refactor to use format_price_display helper

db/
└── migrate/
    └── XXXXXX_add_pac_size_to_order_items.rb  # NEW: Add pac_size column

test/
├── helpers/
│   └── pricing_helper_test.rb     # NEW: Unit tests for helper
├── models/
│   ├── order_item_test.rb         # MODIFY: Add tests for new methods
│   └── cart_item_test.rb          # MODIFY: Add tests for pack_priced?
└── system/
    └── order_pricing_display_test.rb  # NEW: End-to-end pricing display tests
```

**Structure Decision**: Existing Rails monolith structure. New helper added to `app/helpers/`, models modified in place, views updated to use centralized helper.

## Complexity Tracking

> No violations. Implementation follows existing Rails conventions and constitution principles.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |
