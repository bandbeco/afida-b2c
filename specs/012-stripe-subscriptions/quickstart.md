# Quickstart: Stripe Subscription Checkout

**Feature Branch**: `012-stripe-subscriptions`
**Phase**: 1 - Design
**Date**: 2025-12-15

## Implementation Order

Follow this sequence to implement the subscription checkout feature:

```
1. Migration          → Add stripe_invoice_id to orders
2. Service            → SubscriptionCheckoutService
3. Controller         → SubscriptionCheckoutsController
4. Webhooks           → Extend Stripe webhook handler
5. Mailer             → SubscriptionMailer for renewals
6. Cart UI            → Subscription toggle partial + Stimulus
7. System Tests       → End-to-end subscription flow
```

## Quick Reference

### Key Files to Create

| File | Purpose |
|------|---------|
| `db/migrate/*_add_stripe_invoice_id_to_orders.rb` | Idempotency column |
| `app/services/subscription_checkout_service.rb` | Stripe session creation |
| `app/controllers/subscription_checkouts_controller.rb` | Create/success/cancel |
| `app/mailers/subscription_mailer.rb` | Renewal email notifications |
| `app/views/subscription_mailer/order_placed.html.erb` | Email template |
| `app/views/cart_items/_subscription_toggle.html.erb` | Cart UI toggle |
| `app/frontend/javascript/controllers/subscription_toggle_controller.js` | Toggle behavior |

### Key Files to Modify

| File | Changes |
|------|---------|
| `app/controllers/webhooks/stripe_controller.rb` | Add subscription event handlers |
| `app/models/order.rb` | Add stripe_invoice_id validation |
| `app/views/cart_items/_index.html.erb` | Render subscription toggle |
| `config/routes.rb` | Add subscription_checkouts routes |

### Stripe API Calls

```ruby
# Create subscription checkout session
Stripe::Checkout::Session.create(
  mode: "subscription",
  customer: customer_id,
  line_items: [...],
  success_url: "...",
  cancel_url: "..."
)

# Retrieve session on success
Stripe::Checkout::Session.retrieve(session_id, expand: ["subscription"])
```

### Frequency Mapping

```ruby
FREQUENCY_TO_STRIPE = {
  every_week:       { interval: "week",  interval_count: 1 },
  every_two_weeks:  { interval: "week",  interval_count: 2 },
  every_month:      { interval: "month", interval_count: 1 },
  every_3_months:   { interval: "month", interval_count: 3 }
}
```

### Webhook Events to Handle

| Event | Action |
|-------|--------|
| `invoice.paid` (billing_reason: subscription_cycle) | Create renewal order |
| `customer.subscription.updated` | Sync status + billing period |
| `customer.subscription.deleted` | Mark as cancelled |
| `invoice.payment_failed` | Log warning |

## Testing Checklist

### Manual Testing (Development)

1. **Setup Stripe CLI for webhooks**:
   ```bash
   stripe listen --forward-to localhost:3000/webhooks/stripe
   ```

2. **Test subscription creation**:
   - Sign in as test user
   - Add items to cart
   - Enable subscription toggle
   - Select frequency
   - Complete Stripe checkout with test card `4242 4242 4242 4242`
   - Verify subscription created and first order placed

3. **Test renewal order** (via Stripe CLI):
   ```bash
   stripe trigger invoice.paid --override subscription=sub_xxx
   ```
   - Verify renewal order created
   - Verify email sent

4. **Test status sync**:
   - Cancel subscription in Stripe Dashboard
   - Verify local status updates to cancelled

### Test Cards

| Card | Scenario |
|------|----------|
| `4242 4242 4242 4242` | Successful payment |
| `4000 0025 0000 3155` | Requires authentication |
| `4000 0000 0000 9995` | Declined |

## Common Gotchas

### 1. Customer Required for Subscriptions

Stripe Checkout with `mode: "subscription"` requires a customer ID. Create one if the user doesn't have one:

```ruby
def ensure_stripe_customer
  return Stripe::Customer.retrieve(user.stripe_customer_id) if user.stripe_customer_id.present?

  customer = Stripe::Customer.create(
    email: user.email_address,
    name: user.full_name,
    metadata: { user_id: user.id }
  )
  user.update!(stripe_customer_id: customer.id)
  customer
end
```

### 2. First Invoice vs Renewal

The `invoice.paid` webhook fires for BOTH first payment and renewals. Check `billing_reason`:

```ruby
return if invoice.billing_reason == "subscription_create"  # Skip first invoice
```

### 3. Idempotency for Webhooks

Stripe retries failed webhooks. Always check for existing records:

```ruby
return if Order.exists?(stripe_invoice_id: invoice.id)
```

### 4. Nullable stripe_session_id for Renewals

Renewal orders don't come from checkout sessions. Generate a placeholder:

```ruby
stripe_session_id: "renewal_#{invoice.id}"
```

### 5. Price in Minor Units

Stripe expects amounts in pence/cents. Rails typically stores in decimal pounds:

```ruby
unit_amount: (variant.price * 100).to_i  # £16.00 → 1600
```

## Environment Variables

Ensure these are set:

```bash
STRIPE_SECRET_KEY=sk_test_xxx
STRIPE_PUBLISHABLE_KEY=pk_test_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx  # From stripe listen output
```

## Useful Commands

```bash
# Run subscription-related tests
rails test test/controllers/subscription_checkouts_controller_test.rb
rails test test/controllers/webhooks/stripe_controller_test.rb
rails test test/services/subscription_checkout_service_test.rb
rails test test/system/subscription_checkout_test.rb

# Run all tests
rails test

# Check Stripe events in dashboard
open https://dashboard.stripe.com/test/events

# View local subscriptions
rails console
Subscription.all
```

## Related Documentation

- [spec.md](./spec.md) - Feature specification with user stories
- [research.md](./research.md) - Stripe API research and technical decisions
- [data-model.md](./data-model.md) - Database schema and model relationships
- [contracts/api-endpoints.md](./contracts/api-endpoints.md) - API endpoint contracts
- [Design Document](../../docs/plans/2025-12-15-stripe-subscriptions-design.md) - Original design decisions
