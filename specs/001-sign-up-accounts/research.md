# Research: Sign-Up & Account Experience

**Feature Branch**: `001-sign-up-accounts`
**Date**: 2025-12-15

## Research Questions

### 1. Reorder Implementation Pattern

**Question**: How should the reorder functionality be implemented to handle unavailable products, quantity limits, and cart merging?

**Decision**: Service object pattern with atomic cart operations

**Rationale**:
- Encapsulates complex business logic (availability checks, quantity calculations, cart merging)
- Testable in isolation without controller concerns
- Follows existing codebase patterns (e.g., payment processing in controller delegates to Stripe)
- Returns structured result object for UI feedback

**Implementation Approach**:
```ruby
# ReorderService.call(order:, cart:) returns:
# { success: true, added_count: 5, skipped_items: [], cart: cart }
# { success: false, error: "No items available", skipped_items: [...] }
```

**Alternatives Considered**:
- Controller-only logic: Rejected - too complex, hard to test
- Order model method: Rejected - Order shouldn't know about Cart operations
- Concern/module: Rejected - service object is more explicit

---

### 2. Stripe Subscriptions Architecture

**Question**: How should recurring orders integrate with Stripe Checkout while preserving the existing one-time payment flow?

**Decision**: Stripe Checkout in `subscription` mode with separate webhook handlers

**Rationale**:
- Stripe Checkout in `subscription` mode handles recurring billing natively
- Separates one-time orders from subscription orders at the Stripe level
- Webhook `invoice.payment_succeeded` creates orders automatically
- Existing `CheckoutsController` remains focused on one-time payments
- New `SubscriptionCheckoutsController` handles subscription creation

**Key Stripe Concepts**:
- **Checkout Session** (`mode: 'subscription'`): Creates Stripe Customer + Subscription
- **Subscription**: Recurring billing schedule, generates Invoices
- **Invoice**: Each billing cycle generates an invoice → `invoice.payment_succeeded` webhook
- **Customer**: Required for subscriptions (Stripe creates automatically in Checkout)

**Implementation Pattern**:
1. Cart with subscription enabled → `SubscriptionCheckoutsController#create`
2. Stripe Checkout Session (subscription mode) created
3. User completes payment on Stripe
4. Webhook: `checkout.session.completed` → Create local `Subscription` record
5. Webhook: `invoice.payment_succeeded` → Create `Order` from subscription items

**Alternatives Considered**:
- Stripe Billing Portal: Rejected for V1 - adds complexity, not needed for fixed schedules
- In-house recurring job: Rejected - Stripe handles payment failures, retries, card updates
- Modify existing CheckoutsController: Rejected - keeps concerns separate, easier to maintain

---

### 3. Post-Checkout Account Conversion

**Question**: How to securely create accounts from checkout email and associate the order?

**Decision**: Dedicated endpoint with email verification bypass

**Rationale**:
- Email is already verified by Stripe (payment successful)
- Order is linked immediately to prevent orphaning
- User logs in automatically after account creation
- Existing registration flow preserved for direct sign-ups

**Security Considerations**:
- Only accessible from confirmation page (order ownership proven via session)
- Email must match order's email exactly
- Password requirements same as standard registration
- Rate limiting applied (3 attempts per hour per IP)

**Flow**:
1. Guest on confirmation page with `session[:recent_order_id]` set
2. Form submits password + confirmation to `PostCheckoutRegistrationsController#create`
3. Create User with order's email (mark as verified)
4. Update order's `user_id` to new user
5. Start session for new user
6. Redirect back to confirmation page (now logged in)

**Edge Cases**:
- Email already registered: Show message with login link
- Order already has user: Don't show conversion form
- Session expired: Redirect to login with message

**Alternatives Considered**:
- Magic link email: Rejected - adds friction, user is already on the page
- Require email verification: Rejected - Stripe already verified payment capability

---

### 4. Subscription Data Model

**Question**: What data needs to be stored locally vs. what comes from Stripe?

**Decision**: Store subscription reference and schedule locally; Stripe is source of truth for billing

**Local Storage (Subscription model)**:
- `stripe_subscription_id` - Link to Stripe subscription
- `stripe_customer_id` - Link to Stripe customer
- `user_id` - Owner of subscription
- `frequency` - Human-readable (weekly, biweekly, monthly)
- `status` - Local status (active, cancelled, paused)
- `next_billing_date` - Cached from Stripe for display
- `items_snapshot` - JSON of products/variants/quantities at creation time

**From Stripe (not duplicated)**:
- Payment method details
- Billing history
- Next payment amount
- Retry status on failures

**Rationale**:
- Stripe handles payment complexity (retries, card updates, failures)
- Local data enables fast queries for display (no API calls)
- Items snapshot preserves what was ordered (even if products change)
- Status sync via webhooks keeps local state current

**Alternatives Considered**:
- Store everything locally: Rejected - duplicates Stripe, risks inconsistency
- Query Stripe on every page load: Rejected - slow, rate limits, unnecessary

---

### 5. Account Navigation Pattern

**Question**: How should the account dropdown be implemented following Hotwire patterns?

**Decision**: DaisyUI dropdown with Stimulus controller for enhanced behavior

**Rationale**:
- DaisyUI provides accessible dropdown out of the box
- Stimulus controller adds keyboard navigation and click-outside-to-close
- No JavaScript framework needed (follows constitution constraint)
- Works with Turbo navigation (no full page reloads)

**Implementation**:
```html
<div data-controller="dropdown" class="dropdown dropdown-end">
  <button tabindex="0" class="btn">Account</button>
  <ul tabindex="0" class="dropdown-content menu">
    <li><a href="/orders">Order History</a></li>
    <li><a href="/subscriptions">Subscriptions</a></li>
    <li><a href="/account">Settings</a></li>
    <li><a href="/logout" data-turbo-method="delete">Log Out</a></li>
  </ul>
</div>
```

**Alternatives Considered**:
- Pure CSS dropdown (DaisyUI default): Acceptable for V1, Stimulus adds polish
- Custom React component: Rejected - violates constitution
- Server-rendered menu on click: Rejected - unnecessary round trip

---

### 6. Order History Performance

**Question**: How to efficiently load order history with item summaries?

**Decision**: Eager loading with limit on items displayed per order

**Pattern**:
```ruby
@orders = Current.user.orders
  .recent
  .includes(order_items: { product_variant: :product })
  .limit(20)
```

**Display**:
- Show first 3 items per order, then "+N more"
- Full items visible on individual order page
- Pagination for users with many orders

**Rationale**:
- Prevents N+1 queries
- Limits data transfer for large order histories
- Follows existing patterns in codebase (e.g., cart drawer)

**Alternatives Considered**:
- Load items via AJAX on expand: Rejected - adds complexity for marginal benefit
- Store item summary on Order: Rejected - denormalization, sync issues

---

## Dependencies

| Dependency | Version | Purpose | Already Installed |
|------------|---------|---------|-------------------|
| stripe | ~> 10.0 | Payment processing, subscriptions | Yes (Gemfile) |
| rails | 8.x | Framework | Yes |
| hotwire-rails | 8.x | Turbo + Stimulus | Yes |
| daisyui | 4.x | UI components | Yes |

No new dependencies required.

## Integration Points

### Existing Code to Modify

1. **`app/controllers/registrations_controller.rb`**
   - Preserve existing flow
   - Add context for value messaging in view

2. **`app/views/registrations/new.html.erb`**
   - Add tagline and benefits list
   - Keep form structure

3. **`app/controllers/orders_controller.rb`**
   - Add `reorder` action
   - Extend `index` with reorder buttons

4. **`app/views/orders/confirmation.html.erb`**
   - Add account conversion form for guests

5. **`app/views/layouts/application.html.erb`** (or header partial)
   - Add account dropdown for logged-in users

### New Code

1. **`app/controllers/subscriptions_controller.rb`** - Subscription management
2. **`app/controllers/subscription_checkouts_controller.rb`** - Subscription checkout flow
3. **`app/controllers/post_checkout_registrations_controller.rb`** - Guest conversion
4. **`app/controllers/accounts_controller.rb`** - Account settings
5. **`app/models/subscription.rb`** - Subscription model
6. **`app/services/reorder_service.rb`** - Reorder business logic
7. **`app/services/subscription_service.rb`** - Stripe subscription integration

### Webhooks

New webhook handlers needed for Stripe events:
- `checkout.session.completed` (subscription mode) - Create Subscription record
- `invoice.payment_succeeded` - Create Order from subscription
- `customer.subscription.updated` - Sync status changes
- `customer.subscription.deleted` - Mark subscription cancelled

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Stripe webhook failures | Low | High | Idempotent handlers, retry logic, alerting |
| Reorder with all unavailable items | Medium | Low | Clear error messaging, don't modify cart |
| Subscription payment failures | Medium | Medium | Stripe handles retries, email notifications |
| Race condition on account conversion | Low | Medium | Database-level uniqueness constraint on email |

## Next Steps

1. **Phase 1: Data Model** - Create Subscription model and migration
2. **Phase 1: Contracts** - Define API endpoints for new controllers
3. **Phase 1: Quickstart** - Developer setup guide for testing subscriptions
