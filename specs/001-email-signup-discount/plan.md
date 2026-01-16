# Implementation Plan: Email Signup Discount

**Branch**: `001-email-signup-discount` | **Date**: 2026-01-16 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-email-signup-discount/spec.md`

## Summary

Implement a cart page email signup form that offers 5% off the first order to new customers. The feature captures email addresses for marketing while incentivizing conversions. Technical approach uses a new `email_subscriptions` table for tracking, Rails session for discount state, Stripe coupon for checkout integration, and Turbo Streams for seamless form updates.

## Technical Context

**Language/Version**: Ruby 3.4.7 / Rails 8.1.1
**Primary Dependencies**: Hotwire (Turbo + Stimulus), Stripe Ruby SDK
**Storage**: PostgreSQL (new `email_subscriptions` table)
**Testing**: Minitest with fixtures, Capybara for system tests
**Target Platform**: Web application (Rails server)
**Project Type**: Web (Rails monolith with Vite frontend)
**Performance Goals**: Form submission and discount display < 500ms
**Constraints**: Must work with guest checkout, first-party session cookies only
**Scale/Scope**: Expected 100+ signups/month, single cart page placement

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Requirement | Status | Notes |
|-----------|-------------|--------|-------|
| I. Test-First Development | Tests written BEFORE implementation | ✅ WILL COMPLY | Model, controller, and system tests planned |
| I. Fixtures MUST Be Used | Use fixtures, not inline create! | ✅ WILL COMPLY | Will add `email_subscriptions.yml` fixture |
| II. SEO & Structured Data | N/A for this feature | ✅ N/A | Cart page is not indexed |
| III. Performance | Eager loading, no N+1 | ✅ WILL COMPLY | Simple queries, no associations |
| IV. Security | Input validation, no injection | ✅ WILL COMPLY | Email format validation, CSRF protection |
| V. Code Quality | RuboCop passing | ✅ WILL COMPLY | Standard Rails patterns |

**Gate Result**: ✅ PASS - No violations identified

## Project Structure

### Documentation (this feature)

```text
specs/001-email-signup-discount/
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
├── models/
│   └── email_subscription.rb           # NEW: Subscription model
├── controllers/
│   ├── email_subscriptions_controller.rb  # NEW: Handle signups
│   └── checkouts_controller.rb         # MODIFY: Apply coupon
└── views/
    ├── carts/
    │   └── show.html.erb               # MODIFY: Render form partial
    └── email_subscriptions/
        ├── _cart_signup_form.html.erb  # NEW: Form component
        ├── _success.html.erb           # NEW: Success state
        ├── _already_claimed.html.erb   # NEW: Already claimed state
        ├── _not_eligible.html.erb      # NEW: Not eligible state
        └── create.turbo_stream.erb     # NEW: Turbo response

app/frontend/
└── javascript/controllers/
    └── discount_signup_controller.js   # NEW: Form UX

db/migrate/
└── XXXXXX_create_email_subscriptions.rb  # NEW: Migration

test/
├── fixtures/
│   └── email_subscriptions.yml         # NEW: Test fixtures
├── models/
│   └── email_subscription_test.rb      # NEW: Model tests
├── controllers/
│   └── email_subscriptions_controller_test.rb  # NEW: Controller tests
└── system/
    └── email_signup_discount_test.rb   # NEW: System tests
```

**Structure Decision**: Standard Rails structure. New `EmailSubscription` model follows existing patterns (similar to `User`, `Order`). Controller follows existing patterns (similar to `CartsController`).

## Complexity Tracking

> No violations identified - section not required.
