# Implementation Plan: Scheduled Reorder with Review

**Branch**: `014-scheduled-reorder` | **Date**: 2025-12-16 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/014-scheduled-reorder/spec.md`

## Summary

Implement a "Scheduled Reorder with Review" system that allows customers to set up recurring orders from past orders, receive reminder emails before delivery, and confirm with one click or edit before confirming. This replaces the Stripe subscription approach with a simpler model using one-time charges against saved payment methods.

**Technical approach**:
- New models: `ReorderSchedule`, `ReorderScheduleItem`, `PendingOrder`
- Stripe Setup Mode for saving payment methods
- Stripe PaymentIntent with `off_session: true` for one-click confirmation
- Solid Queue background jobs for creating pending orders and expiration
- Secure email links with signed tokens for one-click confirmation

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x
**Primary Dependencies**: Rails 8, Hotwire (Turbo + Stimulus), Stripe Ruby SDK, TailwindCSS 4, DaisyUI
**Storage**: PostgreSQL 14+ (3 new tables: `reorder_schedules`, `reorder_schedule_items`, `pending_orders`)
**Testing**: Rails Test (Minitest), Capybara + Selenium for system tests
**Target Platform**: Web application (responsive)
**Project Type**: Monolithic Rails application
**Performance Goals**: One-click confirmation < 10 seconds, reminder emails sent within 1 hour of deadline
**Constraints**: UK market only, GBP currency, 20% VAT
**Scale/Scope**: 100s of schedules initially, ~1000s long-term

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First Development | ✅ Pass | Tasks will be ordered test-first per TDD requirement |
| II. SEO & Structured Data | ✅ N/A | Internal user account feature, no public-facing pages |
| III. Performance & Scalability | ✅ Pass | Uses SQL-based calculations, background jobs for async |
| IV. Security & Payment Integrity | ✅ Pass | Signed tokens for email links, off_session payment with saved method |
| V. Code Quality & Maintainability | ✅ Pass | Service objects for complex logic, follows existing patterns |

**Technology Constraints Check:**
- ✅ No client-side state management - using Hotwire patterns
- ✅ No GraphQL - REST/Rails conventions
- ✅ ActiveRecord ORM only
- ✅ PostgreSQL for primary data
- ✅ Backend rendering for all views

## Project Structure

### Documentation (this feature)

```text
specs/014-scheduled-reorder/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── api-endpoints.md
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
app/
├── models/
│   ├── reorder_schedule.rb          # New
│   ├── reorder_schedule_item.rb     # New
│   └── pending_order.rb             # New
├── controllers/
│   ├── reorder_schedules_controller.rb    # New
│   └── pending_orders_controller.rb       # New
├── services/
│   ├── reorder_schedule_setup_service.rb  # New
│   └── pending_order_confirmation_service.rb  # New
├── mailers/
│   └── reorder_mailer.rb            # New
├── jobs/
│   ├── create_pending_orders_job.rb # New
│   └── expire_pending_orders_job.rb # New
└── views/
    ├── reorder_schedules/           # New
    │   ├── index.html.erb
    │   ├── show.html.erb
    │   ├── new.html.erb
    │   └── edit.html.erb
    ├── pending_orders/              # New
    │   └── edit.html.erb
    └── reorder_mailer/              # New
        ├── order_ready.html.erb
        ├── order_expired.html.erb
        └── payment_failed.html.erb

test/
├── models/
│   ├── reorder_schedule_test.rb
│   ├── reorder_schedule_item_test.rb
│   └── pending_order_test.rb
├── controllers/
│   ├── reorder_schedules_controller_test.rb
│   └── pending_orders_controller_test.rb
├── services/
│   ├── reorder_schedule_setup_service_test.rb
│   └── pending_order_confirmation_service_test.rb
├── mailers/
│   └── reorder_mailer_test.rb
├── jobs/
│   ├── create_pending_orders_job_test.rb
│   └── expire_pending_orders_job_test.rb
└── system/
    ├── reorder_schedule_setup_test.rb
    ├── pending_order_confirmation_test.rb
    └── reorder_schedule_management_test.rb

db/migrate/
├── YYYYMMDDHHMMSS_create_reorder_schedules.rb
├── YYYYMMDDHHMMSS_create_reorder_schedule_items.rb
├── YYYYMMDDHHMMSS_create_pending_orders.rb
├── YYYYMMDDHHMMSS_add_stripe_fields_to_users.rb
└── YYYYMMDDHHMMSS_add_reorder_schedule_to_orders.rb
```

**Structure Decision**: Follows existing Rails monolith patterns. New models in `app/models/`, service objects for complex operations, background jobs for scheduled tasks.

## Complexity Tracking

> No violations requiring justification. Design follows constitution principles.
