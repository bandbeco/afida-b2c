# Implementation Plan: Stripe Subscription Checkout

**Branch**: `012-stripe-subscriptions` | **Date**: 2025-12-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/012-stripe-subscriptions/spec.md`

## Summary

Complete the Stripe subscription checkout flow enabling logged-in users to convert their cart into a recurring order. Core deliverables: cart UI toggle for subscription opt-in with frequency selector, `SubscriptionCheckoutsController` using Stripe's `mode: "subscription"`, webhook handler for automatic order creation on renewal and status synchronization. Technical approach uses existing Subscription model, extends cart views with Stimulus controller, and integrates Stripe Subscription API for recurring billing.

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x
**Primary Dependencies**: Rails 8 (ActiveRecord, ActionController, ActionView), Hotwire (Turbo + Stimulus), Stripe Ruby SDK, TailwindCSS 4, DaisyUI
**Storage**: PostgreSQL 14+ (existing `subscriptions`, `orders`, `order_items`, `carts`, `cart_items` tables)
**Testing**: Minitest (Rails default), Capybara + Selenium for system tests
**Target Platform**: Web application (responsive, desktop-first for B2B)
**Project Type**: Monolithic Rails web application
**Performance Goals**: Subscription checkout < 3s (includes Stripe API call), webhook processing < 1s
**Constraints**: Must integrate with existing Stripe Checkout patterns, products not in Stripe catalog (ad-hoc price creation), maintain existing one-time checkout flow unchanged
**Scale/Scope**: ~100 subscriptions/month initial, ~1000 subscription renewals/month at scale

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First Development | PASS | All components will have tests written first (service, controller, system tests) |
| II. SEO & Structured Data | N/A | Subscription pages are authenticated, not public-facing |
| III. Performance & Scalability | PASS | Eager loading for cart items, webhook idempotency for renewals |
| IV. Security & Payment Integrity | PASS | Stripe webhook signature verification, authentication required, idempotent order creation |
| V. Code Quality & Maintainability | PASS | Service object for Stripe logic, RuboCop compliance, clear separation of concerns |

**All gates PASS. Proceeding to Phase 0.**

## Project Structure

### Documentation (this feature)

```text
specs/012-stripe-subscriptions/
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
│   ├── subscription_checkouts_controller.rb  # NEW: subscription checkout flow
│   └── webhooks/
│       └── stripe_controller.rb              # MODIFY: add subscription handlers
├── services/
│   └── subscription_checkout_service.rb      # NEW: Stripe session creation logic
├── mailers/
│   └── subscription_mailer.rb                # NEW: renewal order notifications
├── views/
│   ├── cart_items/
│   │   ├── _index.html.erb                   # MODIFY: render subscription toggle
│   │   └── _subscription_toggle.html.erb     # NEW: subscription UI partial
│   └── subscription_mailer/
│       └── order_placed.html.erb             # NEW: email template
└── frontend/
    └── javascript/controllers/
        └── subscription_toggle_controller.js # MODIFY: implement toggle behavior

test/
├── controllers/
│   ├── subscription_checkouts_controller_test.rb  # NEW
│   └── webhooks/
│       └── stripe_controller_test.rb              # MODIFY: add subscription tests
├── services/
│   └── subscription_checkout_service_test.rb      # NEW
├── mailers/
│   └── subscription_mailer_test.rb                # NEW
└── system/
    └── subscription_checkout_test.rb              # NEW
```

**Structure Decision**: Standard Rails monolith structure. New controller for subscription checkouts (separate from existing `CheckoutsController` to maintain clear separation). Service object encapsulates Stripe interaction logic. Webhook controller extended for subscription events.

## Complexity Tracking

> No violations to justify. All work fits within existing Rails patterns and constitution constraints.
