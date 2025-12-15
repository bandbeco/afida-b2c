# Stripe Subscriptions: Complete Implementation Design

**Date**: 2025-12-15
**Status**: Approved
**Spec Reference**: `/specs/001-sign-up-accounts/spec.md` (User Story 5)

## Summary

Complete the subscription feature by implementing:
1. Cart UI toggle for recurring orders (logged-in users only)
2. Subscription checkout flow using Stripe's `mode: "subscription"`
3. Webhook handler for inbound sync and automatic order creation

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Stripe integration | `mode: "subscription"` | Stripe handles recurring billing, retries, dunning |
| Checkout UI | Dual buttons | Explicit user intent for recurring vs one-time |
| Auth requirement | Block at toggle | Clear expectation upfront, no wasted configuration |
| Price creation | Ad-hoc at checkout | Products don't exist in Stripe catalog |

## Cart UI Design

The cart summary section shows a subscription toggle **only for logged-in users**:

```
┌─────────────────────────────────────────┐
│ Cart Summary                            │
├─────────────────────────────────────────┤
│ Shipping          Calculate at checkout │
│ Subtotal                        £48.00  │
│ VAT 20%                          £9.60  │
│ Total                           £57.60  │
├─────────────────────────────────────────┤
│ ☐ Make this a recurring order           │
│   └─ Frequency: [Every 2 weeks ▼]       │
├─────────────────────────────────────────┤
│ [    Proceed to Checkout    ]           │
│ [   Subscribe & Checkout    ]           │
└─────────────────────────────────────────┘
```

**Guest users**: Disabled toggle with "Sign in to set up recurring orders" link.

**Frequency options** (matching `Subscription.frequency` enum):
- Weekly
- Every 2 Weeks
- Monthly
- Every 3 Months

## Subscription Checkout Flow

### SubscriptionCheckoutsController#create

```
User clicks "Subscribe & Checkout"
         ↓
1. Require authentication
2. Get/create Stripe Customer for user
3. Build line items from cart with recurring prices
4. Create Stripe Checkout Session (mode: "subscription")
5. Redirect to Stripe Checkout
```

### Stripe Price Creation

Ad-hoc recurring prices created at checkout:

```ruby
Stripe::Price.create(
  unit_amount: (item.price * 100).round,
  currency: "gbp",
  recurring: { interval: interval, interval_count: interval_count },
  product_data: { name: variant.display_name }
)
```

**Interval mapping:**
- `every_week` → `interval: "week", interval_count: 1`
- `every_two_weeks` → `interval: "week", interval_count: 2`
- `every_month` → `interval: "month", interval_count: 1`
- `every_3_months` → `interval: "month", interval_count: 3`

### SubscriptionCheckoutsController#success

```
1. Retrieve Stripe Session
2. Retrieve Stripe Subscription
3. Create local Subscription record:
   - stripe_subscription_id
   - stripe_customer_id
   - stripe_price_id
   - frequency, status: active
   - items_snapshot (cart contents)
   - shipping_snapshot (from Stripe)
   - current_period_end
4. Create initial Order + OrderItems
5. Clear cart
6. Send confirmation email
7. Redirect to order confirmation
```

## Webhook Handler

### Events to Handle

| Event | Action |
|-------|--------|
| `customer.subscription.updated` | Update status, current_period_end |
| `customer.subscription.deleted` | Mark as cancelled |
| `invoice.paid` | Create Order from subscription (renewals) |
| `invoice.payment_failed` | Log warning (Stripe handles retry) |

### Automatic Order Creation (invoice.paid)

```ruby
def handle_invoice_paid(invoice)
  return unless invoice.subscription.present?

  subscription = Subscription.find_by(stripe_subscription_id: invoice.subscription)
  return unless subscription

  # Skip first invoice (Order created at checkout)
  return if invoice.billing_reason == "subscription_create"

  # Create Order from subscription snapshot
  order = Order.create!(
    user: subscription.user,
    subscription: subscription,
    email: subscription.user.email_address,
    # amounts from invoice, shipping from snapshot
  )

  subscription.items.each { |item| /* create OrderItem */ }

  SubscriptionMailer.order_placed(order).deliver_later
end
```

## File Structure

### New Files

```
app/controllers/subscription_checkouts_controller.rb
app/services/subscription_checkout_service.rb
app/mailers/subscription_mailer.rb
app/views/subscription_mailer/order_placed.html.erb
app/views/cart_items/_subscription_toggle.html.erb
```

### Modified Files

```
app/controllers/webhooks/stripe_controller.rb  # Add subscription handlers
app/views/cart_items/_index.html.erb           # Render subscription toggle
app/frontend/javascript/controllers/subscription_toggle_controller.js  # Implement
```

## Complete User Journey

```
SUBSCRIPTION CREATION
─────────────────────
1. User logs in
2. Adds items to cart
3. Toggles "Make this recurring" → selects frequency
4. Clicks "Subscribe & Checkout"
5. Completes payment on Stripe
6. Subscription + Order #1 created
7. Confirmation email sent

AUTOMATIC RENEWAL (on schedule)
───────────────────────────────
8. Stripe charges customer automatically
9. invoice.paid webhook received
10. Order #N created from items_snapshot
11. SubscriptionMailer.order_placed sent

MANAGEMENT
──────────
- User visits /subscriptions
- Can Pause/Resume/Cancel
- External changes sync via webhooks
```

## Testing Strategy

Per tasks.md (T042-T055), TDD approach:

1. Write tests first (service, controller, system tests)
2. Verify tests fail
3. Implement
4. Verify tests pass

Key test scenarios:
- Subscription checkout creates Stripe session with correct mode
- Success callback creates Subscription and Order
- Webhook creates Order on invoice.paid
- Webhook updates status on subscription.updated/deleted
- Cart UI shows toggle only for logged-in users
- Guest users see sign-in prompt

## Stripe Dashboard Setup Required

1. Add webhook endpoint: `https://yourdomain.com/webhooks/stripe`
2. Subscribe to events:
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.paid`
   - `invoice.payment_failed`
3. Add webhook secret to credentials: `stripe.webhook_secret`

## Local Testing

```bash
# Forward Stripe webhooks to localhost
stripe listen --forward-to localhost:3000/webhooks/stripe
```
