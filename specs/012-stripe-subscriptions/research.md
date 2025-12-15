# Research: Stripe Subscription Checkout

**Feature Branch**: `012-stripe-subscriptions`
**Phase**: 0 - Research
**Date**: 2025-12-15

## Executive Summary

This research validates the technical approach for implementing Stripe subscription checkout with ad-hoc pricing. Key findings confirm that Stripe's `mode: "subscription"` with inline `price_data` fully supports our use case where products don't exist in the Stripe catalog.

## Stripe API Research

### 1. Checkout Session with `mode: "subscription"`

**Source**: Stripe Checkout API Documentation

Creating a subscription checkout session requires:

```ruby
Stripe::Checkout::Session.create(
  mode: "subscription",
  customer: stripe_customer_id,  # Required for subscriptions
  line_items: [{
    price_data: {
      currency: "gbp",
      product_data: {
        name: variant.display_name,
        description: "#{variant.pac_size} units per pack"
      },
      unit_amount: variant.price_minor,  # Price in pence
      recurring: {
        interval: "week",        # week, month, year
        interval_count: 2        # Every 2 weeks
      }
    },
    quantity: quantity
  }],
  success_url: success_url,
  cancel_url: cancel_url
)
```

**Key Constraints**:
- `customer` parameter is **required** for subscription mode (unlike one-time payments)
- Customer must exist in Stripe before creating subscription checkout
- If user doesn't have `stripe_customer_id`, create customer first via `Stripe::Customer.create`

**Frequency Mapping**:
| App Frequency | Stripe interval | interval_count |
|---------------|-----------------|----------------|
| every_week | week | 1 |
| every_two_weeks | week | 2 |
| every_month | month | 1 |
| every_3_months | month | 3 |

### 2. Ad-hoc Price Creation with `price_data`

**Source**: Stripe Prices API Documentation

Since products don't exist in Stripe catalog, we use inline `price_data` instead of `price` ID:

```ruby
line_items: [{
  price_data: {
    currency: "gbp",
    product_data: {
      name: "Single Wall Hot Cup - 8oz",
      metadata: {
        product_variant_id: "123",
        sku: "SWHC-8OZ"
      }
    },
    unit_amount: 1600,  # £16.00 in pence
    recurring: {
      interval: "month",
      interval_count: 1
    }
  },
  quantity: 2
}]
```

**Important**: With `price_data`, Stripe creates an **archived ad-hoc price** for each checkout. These prices are not reusable but appear in subscription details for reference.

### 3. Subscription Webhooks

**Source**: Stripe Webhooks Documentation

**Required Events for Our Implementation**:

| Event | When Fired | Our Action |
|-------|------------|------------|
| `checkout.session.completed` | User completes subscription checkout | Create Subscription + first Order |
| `invoice.paid` | Subscription renews successfully | Create renewal Order |
| `customer.subscription.updated` | Status/frequency changes | Sync local status |
| `customer.subscription.deleted` | Subscription cancelled | Mark as cancelled |
| `invoice.payment_failed` | Payment fails on renewal | Log warning, status auto-updates |

**Webhook Payload - `invoice.paid`**:
```json
{
  "type": "invoice.paid",
  "data": {
    "object": {
      "id": "in_xxx",
      "subscription": "sub_xxx",
      "billing_reason": "subscription_cycle",  // or "subscription_create"
      "lines": {
        "data": [{
          "price": {
            "product": "prod_xxx",
            "metadata": { "product_variant_id": "123" }
          },
          "quantity": 2
        }]
      }
    }
  }
}
```

**Idempotency Strategy**:
- Use `invoice.id` as idempotency key for order creation
- Check `Order.exists?(stripe_invoice_id: invoice.id)` before creating
- First payment (`billing_reason: "subscription_create"`) handled by checkout success, not webhook

**Webhook Payload - `customer.subscription.updated`**:
```json
{
  "type": "customer.subscription.updated",
  "data": {
    "object": {
      "id": "sub_xxx",
      "status": "active",  // active, past_due, canceled, paused
      "current_period_start": 1702648800,
      "current_period_end": 1705327200,
      "cancel_at_period_end": false
    },
    "previous_attributes": {
      "status": "trialing"
    }
  }
}
```

### 4. Customer Management

**Finding**: Subscriptions require a Stripe customer. Our `User` model needs to store `stripe_customer_id`.

**Customer Creation** (if user doesn't have one):
```ruby
customer = Stripe::Customer.create(
  email: user.email,
  name: user.name,
  metadata: { user_id: user.id }
)
user.update!(stripe_customer_id: customer.id)
```

**Existing Codebase Check**: The `users` table already has `stripe_customer_id` column (from previous Stripe integration).

### 5. Tax Handling

**Source**: Stripe Tax Documentation

For subscriptions, tax can be handled identically to one-time checkouts:

```ruby
Stripe::Checkout::Session.create(
  mode: "subscription",
  line_items: [...],
  automatic_tax: { enabled: true },
  # OR for manual tax rate:
  subscription_data: {
    default_tax_rates: [tax_rate_id]
  }
)
```

**Current Pattern**: The existing `CheckoutsController` uses a predefined UK VAT tax rate. We'll follow the same pattern for subscriptions.

### 6. Shipping for Subscriptions

**Finding**: Stripe Checkout with `mode: "subscription"` supports `shipping_address_collection` but does NOT support `shipping_options` in the same way as one-time payments.

**Workaround Options**:
1. **Store shipping at subscription creation**: Capture address via `shipping_address_collection`, store in `subscriptions.shipping_snapshot`
2. **Separate shipping product**: Add shipping as a separate line item (recurring)
3. **Post-checkout shipping selection**: Redirect to internal shipping selection after Stripe

**Recommendation**: Option 1 - Store shipping address at subscription creation. For shipping cost, either:
- Include in product price (free shipping for subscriptions)
- Add as separate recurring line item

**Current Decision**: MVP will use existing shipping selection before checkout (same as one-time orders), stored in `shipping_snapshot`.

## Existing Codebase Findings

### Subscription Model

```ruby
# app/models/subscription.rb
class Subscription < ApplicationRecord
  belongs_to :user
  has_many :orders

  enum :status, { active: 0, paused: 1, cancelled: 2, payment_failed: 3 }
  enum :frequency, { every_week: 0, every_two_weeks: 1, every_month: 2, every_3_months: 3 }

  def pause!
    Stripe::Subscription.update(stripe_subscription_id, pause_collection: { behavior: "void" })
    paused!
  end

  def resume!
    Stripe::Subscription.update(stripe_subscription_id, pause_collection: "")
    active!
  end

  def cancel!
    Stripe::Subscription.cancel(stripe_subscription_id)
    cancelled!
  end
end
```

**Existing Fields**:
- `stripe_subscription_id` - Stripe's subscription ID
- `stripe_customer_id` - Redundant with user's, kept for reference
- `status` - Enum (active, paused, cancelled, payment_failed)
- `frequency` - Enum (every_week, every_two_weeks, every_month, every_3_months)
- `items_snapshot` - JSONB storing subscribed items
- `shipping_snapshot` - JSONB storing shipping details
- `current_period_start` - Current billing period start
- `current_period_end` - Next renewal date

### Existing Webhook Handler

```ruby
# app/controllers/webhooks/stripe_controller.rb
class Webhooks::StripeController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    event = construct_event
    case event.type
    when "checkout.session.completed"
      handle_checkout_completed(event.data.object)
    end
    head :ok
  rescue Stripe::SignatureVerificationError
    head :bad_request
  end
end
```

**Extension Points**:
- Add `invoice.paid` handler
- Add `customer.subscription.updated` handler
- Add `customer.subscription.deleted` handler

### Cart UI Integration Point

```erb
<!-- app/views/cart_items/_index.html.erb -->
<!-- Subscription toggle should be inserted before checkout button -->
```

**Required Changes**:
1. Add `_subscription_toggle.html.erb` partial
2. Conditionally render based on `user_signed_in?` and `!cart.only_samples?`
3. Wire up Stimulus controller for toggle behavior

## Technical Decisions

### Decision 1: Stripe Customer Creation Timing

**Options**:
A. Create customer when user signs up
B. Create customer on first subscription checkout (lazy)

**Decision**: **Option B** - Lazy creation. Only create Stripe customer when user initiates subscription checkout and doesn't have one. Avoids cluttering Stripe dashboard with customers who never subscribe.

### Decision 2: Items Snapshot Storage

**Options**:
A. Store full product/variant details in JSONB
B. Store only IDs and fetch current data on renewal

**Decision**: **Option A** - Full snapshot. Subscription should honor prices/products at subscription time, not current prices. This matches customer expectation and avoids surprise price changes.

**Snapshot Structure**:
```json
{
  "items": [
    {
      "product_variant_id": 123,
      "sku": "SWHC-8OZ",
      "name": "Single Wall Hot Cup - 8oz",
      "quantity": 2,
      "unit_price_minor": 1600,
      "pac_size": 500
    }
  ]
}
```

### Decision 3: First Order Creation

**Options**:
A. Create first order on `checkout.session.completed`
B. Create first order on `invoice.paid` (billing_reason: subscription_create)

**Decision**: **Option A** - On checkout completion. This provides immediate order confirmation to user and matches UX of one-time checkout. Webhook `invoice.paid` for first payment is ignored via `billing_reason` check.

### Decision 4: Renewal Order Creation

**Trigger**: `invoice.paid` webhook with `billing_reason: "subscription_cycle"`

**Process**:
1. Look up subscription by `invoice.subscription`
2. Verify `billing_reason != "subscription_create"` (skip first invoice)
3. Check idempotency: `Order.exists?(stripe_invoice_id: invoice.id)`
4. Create order from `items_snapshot`
5. Send notification email

## Open Questions Resolved

| Question | Resolution |
|----------|------------|
| Do products need to exist in Stripe? | No - use `price_data` for inline pricing |
| How to handle frequency mapping? | Direct mapping to Stripe intervals (documented above) |
| First order: webhook or success callback? | Success callback (immediate user feedback) |
| Shipping for subscriptions? | Store in snapshot, apply same as one-time |
| Tax handling? | Same VAT rate as one-time checkout |

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Webhook delivery failure | Low | High | Stripe retries; add idempotency |
| Price changes affecting renewals | N/A | N/A | Items snapshot captures prices at subscription time |
| Duplicate orders from webhooks | Medium | Medium | Idempotency check on `stripe_invoice_id` |
| Missing Stripe customer | Low | Medium | Create customer if missing before checkout |

## Implementation Checklist

- [ ] Add `stripe_invoice_id` column to orders (for idempotency)
- [ ] Implement `SubscriptionCheckoutService` with Stripe session creation
- [ ] Create `SubscriptionCheckoutsController` with create/success actions
- [ ] Extend `Webhooks::StripeController` with subscription event handlers
- [ ] Add cart UI toggle partial with Stimulus controller
- [ ] Create `SubscriptionMailer` for renewal notifications
- [ ] Add system tests for full subscription flow

## References

- [Stripe Checkout Subscriptions](https://stripe.com/docs/billing/subscriptions/checkout)
- [Stripe Subscription Webhooks](https://stripe.com/docs/billing/subscriptions/webhooks)
- [Stripe Ad-hoc Prices](https://stripe.com/docs/products-prices/pricing-models#ad-hoc-prices)
- [Existing Design Document](../../docs/plans/2025-12-15-stripe-subscriptions-design.md)
