# Research: Scheduled Reorder with Review

**Feature**: 014-scheduled-reorder
**Date**: 2025-12-16

## Research Topics

### 1. Stripe Setup Mode for Saving Payment Methods

**Decision**: Use Stripe Checkout Session in `mode: "setup"` to save customer payment methods.

**Rationale**:
- Stripe Checkout handles PCI compliance - no card details touch our servers
- Creates a `SetupIntent` which confirms the card is valid and ready for future charges
- Automatically attaches PaymentMethod to Customer
- Provides consistent UI that customers trust
- Reuses existing Stripe integration patterns in the codebase

**Alternatives Considered**:
- Stripe Elements with custom form: More control but more PCI scope
- Card on file during checkout: Adds complexity to checkout flow

**Implementation Notes**:
```ruby
Stripe::Checkout::Session.create(
  mode: "setup",
  customer: stripe_customer_id,
  payment_method_types: ["card"],
  success_url: reorder_schedule_setup_success_url + "?session_id={CHECKOUT_SESSION_ID}",
  cancel_url: reorder_schedule_setup_cancel_url
)
```

After success, retrieve the SetupIntent to get the PaymentMethod ID:
```ruby
session = Stripe::Checkout::Session.retrieve(session_id, expand: ['setup_intent'])
payment_method_id = session.setup_intent.payment_method
```

---

### 2. Off-Session Payments for One-Click Confirmation

**Decision**: Use Stripe PaymentIntent with `off_session: true` and `confirm: true` for one-click order confirmation.

**Rationale**:
- Customer has already authorized future payments during setup
- `off_session: true` tells Stripe the customer is not present
- `confirm: true` immediately attempts the charge
- Returns synchronously with success/failure for immediate feedback
- Stripe handles SCA exemptions for merchant-initiated transactions

**Alternatives Considered**:
- Invoice API: More overhead, designed for delayed payment
- Subscription mode: Unnecessary complexity for our use case

**Implementation Notes**:
```ruby
Stripe::PaymentIntent.create(
  amount: total_in_cents,
  currency: "gbp",
  customer: stripe_customer_id,
  payment_method: stripe_payment_method_id,
  off_session: true,
  confirm: true,
  description: "Reorder ##{pending_order.id}"
)
```

**Error Handling**:
- `Stripe::CardError`: Card declined, notify customer
- `Stripe::InvalidRequestError`: Configuration issue, log and alert
- Payment requires action: Rare for off-session, but send customer to Stripe-hosted page

---

### 3. Secure Email Links for One-Click Confirmation

**Decision**: Use Rails signed global IDs (SGIDs) for secure, expiring email links.

**Rationale**:
- Rails built-in feature, battle-tested
- Includes expiration (30 days default)
- Cryptographically signed, can't be forged
- Already used in codebase for order access tokens
- Single-use can be enforced by checking PendingOrder status

**Alternatives Considered**:
- Custom tokens with database lookup: More code to maintain
- JWT tokens: Overkill for simple use case
- Magic links with short codes: Less secure

**Implementation Notes**:
```ruby
# Generate link
token = pending_order.to_sgid(expires_in: 7.days, for: "pending_order_confirm").to_s
confirm_url = confirm_pending_order_url(token: token)

# Verify in controller
pending_order = GlobalID::Locator.locate_signed(params[:token], for: "pending_order_confirm")
raise ActiveRecord::RecordNotFound unless pending_order
```

---

### 4. Background Job Scheduling with Solid Queue

**Decision**: Use recurring Solid Queue jobs scheduled via `config/recurring.yml`.

**Rationale**:
- Solid Queue is already configured in the application
- Native Rails 8 background job solution
- `recurring.yml` provides cron-like scheduling without external dependencies
- Jobs run in separate process, won't block web requests

**Alternatives Considered**:
- Cron jobs: External dependency, harder to manage
- Sidekiq: Would require adding new dependency
- Clockwork: Additional gem dependency

**Implementation Notes**:

Add to `config/recurring.yml`:
```yaml
create_pending_orders:
  class: CreatePendingOrdersJob
  schedule: every day at 6am

expire_pending_orders:
  class: ExpirePendingOrdersJob
  schedule: every day at 6am
```

Job implementation:
```ruby
class CreatePendingOrdersJob < ApplicationJob
  queue_as :default

  def perform
    # Find schedules where next_scheduled_date is 3 days from now
    target_date = 3.days.from_now.to_date
    ReorderSchedule.active.where(next_scheduled_date: target_date).find_each do |schedule|
      CreatePendingOrderFromSchedule.call(schedule)
    end
  end
end
```

---

### 5. Price Updates Between Schedule and Confirmation

**Decision**: Always charge current prices at confirmation time. Display current prices in reminder email.

**Rationale**:
- Prices change over time (inflation, promotions, supplier costs)
- Customer sees exact amount they'll be charged in reminder email
- Avoids complex price locking and honoring stale prices
- Matches customer expectation from Amazon Subscribe & Save model
- `ReorderScheduleItem.price` stored for display reference only

**Alternatives Considered**:
- Lock prices at schedule creation: Complex, may lead to losses
- Notify on price changes: Additional complexity, most customers don't care

**Implementation Notes**:
- When creating PendingOrder, fetch current `ProductVariant.price` for each item
- Store in `pending_orders.items_snapshot` as JSONB
- Email template displays prices from snapshot
- Order creation uses snapshot prices (already current at that point)

---

### 6. Handling Unavailable Products

**Decision**: Exclude unavailable products from pending orders, notify customer in reminder email.

**Rationale**:
- Products may be discontinued, out of stock, or inactive
- Customer should still receive available items rather than blocking entire order
- Clear notification prevents confusion
- Matches `ReorderService` pattern already in codebase

**Alternatives Considered**:
- Block entire order: Poor UX for multi-item schedules
- Auto-substitute: Too complex, risky without customer approval

**Implementation Notes**:
```ruby
def available_items
  reorder_schedule_items.joins(:product_variant)
    .where(product_variants: { active: true })
    .joins("INNER JOIN products ON products.id = product_variants.product_id")
    .where(products: { active: true })
end

def unavailable_items
  reorder_schedule_items - available_items
end
```

Include unavailable items in email:
```erb
<% if @unavailable_items.any? %>
  <p>The following items are no longer available:</p>
  <ul>
    <% @unavailable_items.each do |item| %>
      <li><%= item.product_variant.display_name %></li>
    <% end %>
  </ul>
<% end %>
```

---

### 7. Stripe Customer Management

**Decision**: Reuse or create Stripe Customer on User model. Store `stripe_customer_id` on User.

**Rationale**:
- Stripe Customer can have multiple PaymentMethods attached
- User may have multiple ReorderSchedules, each with different PaymentMethod
- Central Customer record enables future features (payment method management, billing history)
- Pattern exists in subscription code (to be removed but pattern is sound)

**Alternatives Considered**:
- Store Stripe Customer per ReorderSchedule: Duplication, harder to manage
- No Stripe Customer (just PaymentMethod): Can't use off_session payments

**Implementation Notes**:
```ruby
# User model
def stripe_customer
  return Stripe::Customer.retrieve(stripe_customer_id) if stripe_customer_id.present?

  customer = Stripe::Customer.create(
    email: email_address,
    name: [first_name, last_name].compact.join(" ").presence,
    metadata: { user_id: id }
  )
  update!(stripe_customer_id: customer.id)
  customer
end
```

---

## Summary

All technical unknowns have been resolved:

| Topic | Decision |
|-------|----------|
| Save payment method | Stripe Checkout Session `mode: "setup"` |
| One-click payment | PaymentIntent with `off_session: true, confirm: true` |
| Secure email links | Rails signed global IDs (SGIDs) |
| Background scheduling | Solid Queue with `config/recurring.yml` |
| Price handling | Current prices at confirmation time |
| Unavailable products | Exclude and notify in reminder email |
| Stripe Customer | Store on User model, reuse across schedules |

No NEEDS CLARIFICATION items remain. Ready for Phase 1 design.
