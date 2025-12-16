# Scheduled Reorder with Review: Implementation Design

**Date**: 2025-12-16
**Status**: Approved
**Replaces**: Stripe Subscriptions approach (branch `012-stripe-subscriptions`, never merged)

## Summary

A "Scheduled Reorder with Review" system that allows customers to set up recurring orders with one-click confirmation or easy editing before each delivery. This replaces the original Stripe subscription approach based on actual customer behavior: most clients reorder similar baskets but want the ability to tweak quantities before each order.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Billing model | One-time charges with saved payment method | Simpler than Stripe subscriptions, no webhook sync needed |
| Customer control | Review before each order | Matches behavior - customers want starting point, not autopilot |
| Confirmation UX | One-click from email | Autopilot customers get near-instant experience |
| Edit capability | Full flexibility | Tweakers can adjust quantities, add/remove items |
| Reminder timing | 3 days before delivery | Enough time to review and edit |

## Data Model

### ReorderSchedule

Represents a customer's recurring order setup.

```ruby
# db/migrate/xxx_create_reorder_schedules.rb
create_table :reorder_schedules do |t|
  t.references :user, null: false, foreign_key: true
  t.integer :frequency, null: false  # enum: weekly, every_two_weeks, monthly, every_3_months
  t.integer :status, null: false, default: 0  # enum: active, paused, cancelled
  t.date :next_scheduled_date, null: false
  t.string :stripe_payment_method_id, null: false
  t.timestamps
end
```

### ReorderScheduleItem

Products in the schedule.

```ruby
# db/migrate/xxx_create_reorder_schedule_items.rb
create_table :reorder_schedule_items do |t|
  t.references :reorder_schedule, null: false, foreign_key: true
  t.references :product_variant, null: false, foreign_key: true
  t.integer :quantity, null: false
  t.decimal :price, precision: 10, scale: 2, null: false  # price at time of adding (display only)
  t.timestamps
end
```

### PendingOrder

Draft order awaiting confirmation.

```ruby
# db/migrate/xxx_create_pending_orders.rb
create_table :pending_orders do |t|
  t.references :reorder_schedule, null: false, foreign_key: true
  t.references :order, foreign_key: true  # set when confirmed
  t.integer :status, null: false, default: 0  # enum: pending, confirmed, expired
  t.jsonb :items_snapshot, null: false  # products, quantities, current prices
  t.date :scheduled_for, null: false
  t.datetime :confirmed_at
  t.datetime :expired_at
  t.timestamps
end
```

### User additions

```ruby
# Add to users table if not present
add_column :users, :stripe_customer_id, :string
add_column :users, :stripe_payment_method_id, :string  # default payment method
```

### Order addition

```ruby
# Link orders to their reorder schedule
add_reference :orders, :reorder_schedule, foreign_key: true
```

## User Flows

### Setting Up a Reorder Schedule

**Entry point 1: After checkout**
```
1. Customer completes regular checkout
2. Order confirmation shows: "Want this delivered regularly?"
3. Customer clicks "Set up reorder schedule"
4. Selects frequency (weekly / 2 weeks / monthly / 3 months)
5. Saves payment method (Stripe Checkout setup mode)
6. Schedule created from order items
7. Confirmation: "You'll get a reminder email before each order"
```

**Entry point 2: From past order**
```
1. Customer visits "My Orders" → clicks past order
2. Clicks "Schedule this order"
3. Same flow as above
```

### The Reorder Cycle

```
Day -3:  CreatePendingOrdersJob runs
         → Creates PendingOrder from schedule items (at current prices)
         → Sends reminder email

Email contains:
┌────────────────────────────────────────┐
│ Your monthly order is ready            │
│                                        │
│ 2x Kraft Napkins             £16.00    │
│ 1x Paper Cups 8oz            £24.00    │
│ ───────────────────────────────────    │
│ Subtotal                     £40.00    │
│                                        │
│ [  Confirm Order  ]  [  Edit Order  ]  │
└────────────────────────────────────────┘

Customer clicks "Confirm Order":
  → Charges saved payment method (Stripe PaymentIntent, off_session)
  → Creates real Order + OrderItems
  → Marks PendingOrder as confirmed
  → Sends order confirmation email
  → Advances schedule to next date

Customer clicks "Edit Order":
  → Goes to PendingOrder edit page
  → Adjusts quantities, adds/removes items
  → Clicks "Place Order"
  → Same result as confirm
```

### Managing Schedules

**Customer's "My Reorder Schedules" page:**

```
┌─────────────────────────────────────────────────────────┐
│ My Reorder Schedules                                    │
├─────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Monthly Delivery                        ● Active    │ │
│ │ Next order: January 15, 2026                        │ │
│ │                                                     │ │
│ │ 2x Kraft Napkins                         £16.00    │ │
│ │ 1x Paper Cups 8oz                        £24.00    │ │
│ │                                                     │ │
│ │ [Edit Items]  [Change Frequency]  [Pause]  [Cancel] │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**Available actions:**

| Action | What happens |
|--------|--------------|
| Edit Items | Add/remove products, change quantities |
| Change Frequency | Weekly / 2 weeks / monthly / 3 months |
| Pause | Stops generating PendingOrders until resumed |
| Cancel | Permanently deactivates schedule |
| Skip Next | Skips one cycle, resumes after |

## Background Jobs

| Job | Schedule | Purpose |
|-----|----------|---------|
| `CreatePendingOrdersJob` | Daily 6am | Find schedules where `next_scheduled_date` is 3 days away, create PendingOrder, send reminder email |
| `ExpirePendingOrdersJob` | Daily 6am | Mark unconfirmed PendingOrders as expired after delivery date, notify customer |

**PendingOrder lifecycle:**
```
pending → confirmed → (becomes real Order)
    ↓
  expired (customer didn't act)
```

**When PendingOrder expires:**
- Email: "Your scheduled order wasn't confirmed - we'll try again next cycle"
- Schedule remains active
- Next cycle proceeds normally

## Payment Handling

### Saving Payment Method

When customer sets up first reorder schedule:
```ruby
# Create Stripe Checkout Session in setup mode
Stripe::Checkout::Session.create(
  mode: "setup",
  customer: user.stripe_customer_id,
  payment_method_types: ["card"],
  success_url: success_url,
  cancel_url: cancel_url
)
```

### One-Click Confirm

```ruby
Stripe::PaymentIntent.create(
  amount: pending_order.total_in_cents,
  currency: "gbp",
  customer: user.stripe_customer_id,
  payment_method: reorder_schedule.stripe_payment_method_id,
  off_session: true,
  confirm: true
)
```

### Payment Failures

| Scenario | Response |
|----------|----------|
| Card declined | Email: "Payment failed - update your card" |
| Card expired | Same, with link to update payment method |
| Insufficient funds | Retry once after 24 hours, then notify |

Customer updates payment method → can retry confirmation manually.

## File Structure

### New Files

```
app/models/reorder_schedule.rb
app/models/reorder_schedule_item.rb
app/models/pending_order.rb
app/controllers/reorder_schedules_controller.rb
app/controllers/pending_orders_controller.rb
app/services/pending_order_confirmation_service.rb
app/services/reorder_schedule_setup_service.rb
app/mailers/reorder_mailer.rb
app/jobs/create_pending_orders_job.rb
app/jobs/expire_pending_orders_job.rb
app/views/reorder_schedules/index.html.erb
app/views/reorder_schedules/show.html.erb
app/views/reorder_schedules/edit.html.erb
app/views/pending_orders/edit.html.erb
app/views/reorder_mailer/order_ready.html.erb
app/views/reorder_mailer/order_expired.html.erb
app/views/reorder_mailer/payment_failed.html.erb
```

### Modified Files

```
app/models/user.rb                    # Add stripe_customer_id, stripe_payment_method_id
app/models/order.rb                   # Add reorder_schedule_id reference
app/views/orders/show.html.erb        # Add "Schedule this order" button
config/routes.rb                      # Add reorder_schedules, pending_orders routes
```

## Comparison to Subscription Approach

| Aspect | Stripe Subscriptions | Scheduled Reorder |
|--------|---------------------|-------------------|
| Billing | Automatic via Stripe | One-time charges with saved card |
| Customer control | Limited (cancel/pause) | Full (edit every order) |
| Webhook complexity | High (sync status, create orders) | Low (payment confirmation only) |
| Stripe state sync | Required | Not needed |
| Edge cases | Many (failed payments, item changes) | Few |
| Matches customer behavior | Partially | Yes |

## Testing Strategy

Key scenarios to test:
- Schedule setup from order confirmation
- Schedule setup from past order
- PendingOrder creation job
- One-click confirmation flow
- Edit-then-confirm flow
- PendingOrder expiration
- Payment failure handling
- Pause/resume/cancel actions
- Frequency changes
- Item updates
