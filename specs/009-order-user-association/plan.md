# Implementation Plan: Order User Association

**Branch**: `009-order-user-association` | **Date**: 2025-11-26 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/009-order-user-association/spec.md`

## Summary

Implement authorization controls for order viewing to ensure users can only access their own orders. The order-user association at checkout and order history listing already exist - this feature focuses on adding the missing authorization layer to prevent unauthorized access to order details.

**Key Gap Identified**: The `OrdersController#show` action currently allows any authenticated user to view any order by ID - a security vulnerability that must be fixed.

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x
**Primary Dependencies**: Rails 8 (ActiveRecord, ActionController), Hotwire (Turbo + Stimulus)
**Storage**: PostgreSQL 14+ (existing `orders` table with `user_id` column)
**Testing**: Rails Minitest (models, controllers, integration, system tests)
**Target Platform**: Web application (Linux server production, macOS development)
**Project Type**: Web (Rails monolith with Vite frontend)
**Performance Goals**: Order history page loads within 2 seconds (SC-002)
**Constraints**: Must maintain guest checkout functionality (orders without user association)
**Scale/Scope**: Standard e-commerce order volumes

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First Development | ✅ PASS | Tests will be written first for authorization logic |
| II. SEO & Structured Data | ✅ N/A | Order pages are authenticated, not public/indexable |
| III. Performance & Scalability | ✅ PASS | Uses existing eager loading; no N+1 queries introduced |
| IV. Security & Payment Integrity | ✅ PASS | This feature FIXES a security gap (unauthorized order access) |
| V. Code Quality & Maintainability | ✅ PASS | Simple authorization pattern, RuboCop compliant |

**Technology Constraints Check**:
- ✅ No client-side state management (uses Hotwire patterns)
- ✅ No GraphQL (REST/Rails conventions)
- ✅ Backend rendering for order pages

## Project Structure

### Documentation (this feature)

```text
specs/009-order-user-association/
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
├── controllers/
│   └── orders_controller.rb    # Add authorization to show action
├── models/
│   └── order.rb                # Existing (no changes needed)
└── views/
    └── orders/
        ├── index.html.erb      # Existing (already has empty state)
        └── show.html.erb       # Existing (no changes needed)

test/
├── controllers/
│   └── orders_controller_test.rb    # Add authorization tests
├── integration/
│   └── order_authorization_test.rb  # New integration tests
└── system/
    └── order_history_test.rb        # New system tests
```

**Structure Decision**: Uses existing Rails conventions. No new directories or architectural changes required.

## Complexity Tracking

> No violations - feature is straightforward authorization implementation.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |

## Implementation Analysis

### Current State (from codebase analysis)

1. **Order-User Association** ✅ ALREADY WORKS
   - `Order belongs_to :user, optional: true` (app/models/order.rb:2)
   - `User has_many :orders` (app/models/user.rb:10)
   - Checkout passes `client_reference_id` to Stripe (checkouts_controller.rb:54)
   - Order creation uses user from Stripe session (checkouts_controller.rb:150-154)

2. **Order Index** ✅ ALREADY WORKS
   - Scoped to current user: `Current.user.orders.recent` (orders_controller.rb:10)
   - Empty state handling exists in view (orders/index.html.erb:78-89)

3. **Order Show** ❌ SECURITY GAP
   - Fetches ANY order by ID: `Order.find(params[:id])` (orders_controller.rb:16)
   - No authorization check - any logged-in user can view any order
   - This violates FR-003 and creates a security vulnerability

### Required Changes

1. **Add authorization to `set_order`** in OrdersController
   - Scope order lookup to current user's orders
   - Handle unauthorized access gracefully (redirect with message)

2. **Add tests** for authorization scenarios
   - User viewing own order (allowed)
   - User viewing another user's order (denied)
   - Guest user viewing order page (redirected to login)
   - Guest orders (orders without user_id) - determine access policy

### Design Decision: Guest Order Access

Guest orders (orders with `user_id: nil`) need a policy decision:

**Option A**: Only accessible via order confirmation page (current behavior after checkout)
- Guest orders cannot be viewed later (no account to log into)
- Simple to implement - no special handling needed

**Option B**: Allow access via order number + email verification
- More user-friendly but adds complexity
- Out of scope per spec assumptions

**Decision**: Option A - Guest orders remain view-only at checkout confirmation. This aligns with the spec's assumption that "Guest checkout functionality should continue to work" without requiring new features.
