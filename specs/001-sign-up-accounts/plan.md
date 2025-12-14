# Implementation Plan: Sign-Up & Account Experience

**Branch**: `001-sign-up-accounts` | **Date**: 2025-12-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-sign-up-accounts/spec.md`

## Summary

Redesign the sign-up experience and account features to drive repeat purchases from B2B customers. Core deliverables: one-click reorder from order history, post-checkout guest-to-account conversion, enhanced sign-up page with value messaging, account navigation dropdown, and fixed-schedule recurring orders (subscriptions V1). Technical approach uses existing Rails 8 authentication, extends Order/User models, integrates Stripe Subscriptions for recurring billing, and follows Hotwire patterns for UI interactions.

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x
**Primary Dependencies**: Rails 8 (ActiveRecord, ActionController, ActionView), Hotwire (Turbo + Stimulus), Stripe Ruby SDK, TailwindCSS 4, DaisyUI
**Storage**: PostgreSQL 14+ (existing `users`, `orders`, `order_items` tables; new `subscriptions` table)
**Testing**: Minitest (Rails default), Capybara + Selenium for system tests
**Target Platform**: Web application (responsive, desktop-first for B2B)
**Project Type**: Monolithic Rails web application
**Performance Goals**: Page loads < 2s, reorder action < 500ms, subscription creation < 3s (includes Stripe API call)
**Constraints**: Must integrate with existing Stripe Checkout flow, maintain guest checkout capability, no client-side state frameworks
**Scale/Scope**: ~1000 orders/month, ~500 registered users within 6 months

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First Development | PASS | All features will have tests written first (models, controllers, system tests) |
| II. SEO & Structured Data | PASS | Account pages are authenticated, not public-facing. Sign-up page will have proper meta tags. |
| III. Performance & Scalability | PASS | Eager loading for order history, SQL-based reorder logic, Turbo for navigation |
| IV. Security & Payment Integrity | PASS | Stripe Subscriptions for recurring payments, no stored card data, CSRF on all forms |
| V. Code Quality & Maintainability | PASS | RuboCop compliance, clear service objects for subscription logic |

**All gates PASS. Proceeding to Phase 0.**

## Project Structure

### Documentation (this feature)

```text
specs/001-sign-up-accounts/
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
│   ├── registrations_controller.rb      # Enhanced with post-checkout conversion
│   ├── orders_controller.rb             # Add reorder action
│   ├── subscriptions_controller.rb      # NEW: subscription management
│   └── accounts_controller.rb           # NEW: account settings
├── models/
│   ├── user.rb                          # Existing
│   ├── order.rb                         # Add reorder logic
│   └── subscription.rb                  # NEW: recurring order model
├── services/
│   ├── reorder_service.rb               # NEW: handles reorder logic
│   └── subscription_service.rb          # NEW: Stripe subscription integration
├── views/
│   ├── registrations/
│   │   └── new.html.erb                 # Enhanced with value messaging
│   ├── orders/
│   │   ├── index.html.erb               # Add reorder buttons
│   │   └── confirmation.html.erb        # Add account conversion prompt
│   ├── subscriptions/
│   │   └── index.html.erb               # NEW: subscription management
│   └── accounts/
│       └── show.html.erb                # NEW: account settings
└── frontend/
    └── javascript/controllers/
        ├── account_dropdown_controller.js    # NEW: header dropdown
        └── subscription_toggle_controller.js # NEW: cart subscription UI

test/
├── models/
│   ├── subscription_test.rb             # NEW
│   └── order_test.rb                    # Extend with reorder tests
├── controllers/
│   ├── orders_controller_test.rb        # Extend with reorder action tests
│   ├── subscriptions_controller_test.rb # NEW
│   └── accounts_controller_test.rb      # NEW
├── services/
│   ├── reorder_service_test.rb          # NEW
│   └── subscription_service_test.rb     # NEW
└── system/
    ├── reorder_test.rb                  # NEW
    ├── account_conversion_test.rb       # NEW
    └── subscription_test.rb             # NEW
```

**Structure Decision**: Standard Rails monolith structure. New controllers for subscriptions and accounts. Service objects for complex business logic (reorder, Stripe subscription integration).

## Complexity Tracking

> No violations to justify. All work fits within existing Rails patterns and constitution constraints.
