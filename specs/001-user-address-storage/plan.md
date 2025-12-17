# Implementation Plan: User Address Storage

**Branch**: `001-user-address-storage` | **Date**: 2025-12-17 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-user-address-storage/spec.md`

## Summary

Enable logged-in users to save multiple delivery addresses with CRUD management in account settings, pre-checkout address selection via modal, and post-checkout address save prompt. Selected addresses prefill Stripe Checkout for faster repeat purchases.

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x
**Primary Dependencies**: Rails 8 (ActiveRecord, ActionController, ActionView), Hotwire (Turbo + Stimulus), TailwindCSS 4, DaisyUI, Stripe Ruby SDK
**Storage**: PostgreSQL 14+ (new `addresses` table)
**Testing**: Minitest (model, controller, integration, system tests)
**Target Platform**: Web application (server-rendered with Hotwire enhancements)
**Project Type**: Web application (Rails monolith)
**Performance Goals**: Address selection modal appears within 500ms of checkout click
**Constraints**: UK addresses only (GB country code hardcoded), user-scoped access only
**Scale/Scope**: Existing user base, multiple addresses per user (no hard limit)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Test-First Development | PASS | Tasks will include tests BEFORE implementation for Address model, controller, and system tests |
| II. SEO & Structured Data | N/A | Internal account feature, not public-facing |
| III. Performance & Scalability | PASS | Eager loading for user.addresses, SQL-based address lookups |
| IV. Security & Payment Integrity | PASS | User-scoped address access (FR-014), no cross-user access, existing authentication required |
| V. Code Quality & Maintainability | PASS | Standard Rails patterns, RuboCop compliance, explicit scopes |

**Technology Standards Compliance**:
- Backend: Rails 8.x with PostgreSQL ✓
- Frontend: Vite + Hotwire (Turbo + Stimulus) ✓
- Styling: TailwindCSS 4 + DaisyUI ✓
- Payment: Stripe Checkout integration ✓
- NO client-side state frameworks ✓ (using Stimulus for modal)

**Gate Status**: PASS - No violations

## Project Structure

### Documentation (this feature)

```text
specs/001-user-address-storage/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
app/
├── models/
│   └── address.rb                          # NEW: Address model
├── controllers/
│   └── account/
│       └── addresses_controller.rb         # NEW: CRUD + set_default + create_from_order
├── views/
│   └── account/
│       └── addresses/
│           ├── index.html.erb              # NEW: Address list
│           ├── _address.html.erb           # NEW: Address card partial
│           ├── _form.html.erb              # NEW: Add/Edit form partial
│           └── new.html.erb                # NEW: New address page
│   └── carts/
│       └── _checkout_address_modal.html.erb # NEW: Pre-checkout modal
│   └── orders/
│       └── _save_address_prompt.html.erb   # NEW: Post-checkout prompt
├── frontend/
│   └── javascript/
│       └── controllers/
│           └── checkout_address_controller.js  # NEW: Modal interaction

db/
└── migrate/
    └── YYYYMMDDHHMMSS_create_addresses.rb  # NEW: Migration

test/
├── models/
│   └── address_test.rb                     # NEW: Model tests
├── controllers/
│   └── account/
│       └── addresses_controller_test.rb    # NEW: Controller tests
├── integration/
│   └── checkout_address_prefill_test.rb    # NEW: Stripe prefill tests
└── system/
    └── address_management_test.rb          # NEW: E2E tests
```

**Structure Decision**: Rails monolith with account namespace for address management. New `addresses` table with standard CRUD controller. Stimulus controller for modal interaction. All views server-rendered with Turbo enhancements.

## Complexity Tracking

> No constitution violations - table not needed.
