# Structured Events Infrastructure Design

**Date:** 2026-01-16
**Status:** Draft
**Author:** Claude + Laurent

## Overview

Implement application-wide structured event reporting using Rails 8.1's `Rails.event` API. Events flow to Logtail for querying and debugging, with the architecture ready for PostHog integration later.

## Goals

1. Track customer journey: signup → discount claimed → order placed
2. Track operational events: webhooks, payments, order lifecycle
3. Enable debugging of silent failures via structured log queries
4. Prepare infrastructure for future analytics tools (PostHog)

## Non-Goals

- Real-time dashboards (use Logtail's UI)
- Frontend event tracking (server-side only for now)
- Schematized event classes (using convention-based hashes)

## Event Naming Convention

**Pattern:** `domain.action` with past tense for completed actions

| Domain | Example Events |
|--------|----------------|
| `email_signup` | `completed`, `discount_claimed` |
| `cart` | `item_added`, `item_removed` |
| `checkout` | `started`, `completed` |
| `order` | `placed`, `fulfilled`, `cancelled` |
| `payment` | `succeeded`, `failed`, `refunded` |
| `webhook` | `received`, `processed`, `failed` |
| `pending_order` | `created`, `reminder_sent`, `expired` |
| `reorder` | `scheduled`, `confirmed`, `charge_failed` |

## Standard Payload Fields

Every event includes relevant identifiers for cross-referencing:

```ruby
Rails.event.notify("order.placed",
  order_id: order.id,
  user_id: user&.id,
  email: order.email,
  source: "checkout",
  total: order.total_amount,
  item_count: order.items.count
)
```

## Request Context

Set once per request via `before_action`:

```ruby
Rails.event.set_context(
  request_id: request.request_id,
  user_id: Current.user&.id,
  session_id: Current.session&.id
)
```

## Architecture

### Subscriber Pattern

```
Application Code
       │
       ▼
 Rails.event.notify(...)
       │
       ▼
 EventLogSubscriber ──────► Rails.logger (JSON) ──────► Logtail
       │
       ▼ (future)
 PosthogSubscriber ──────► PostHog API
```

### EventLogSubscriber

```ruby
# app/subscribers/event_log_subscriber.rb
class EventLogSubscriber
  def emit(event)
    Rails.logger.info(format_event(event))
  end

  private

  def format_event(event)
    {
      event: event[:name],
      payload: event[:payload],
      context: event[:context],
      tags: event[:tags],
      timestamp: event[:timestamp],
      source_location: event[:source_location]
    }.to_json
  end
end
```

### Registration

```ruby
# config/initializers/events.rb
Rails.event.subscribe(EventLogSubscriber.new)
```

## Customer Journey Events

### Email Signup Funnel

| Event | When | Key Payload |
|-------|------|-------------|
| `email_signup.completed` | User submits email | `email`, `source`, `discount_eligible` |
| `email_signup.discount_claimed` | Discount applied at checkout | `email`, `order_id`, `discount_amount` |

### Cart & Checkout

| Event | When | Key Payload |
|-------|------|-------------|
| `cart.item_added` | Product added to cart | `product_id`, `product_sku`, `quantity`, `is_sample` |
| `cart.item_removed` | Product removed from cart | `product_id`, `product_sku` |
| `checkout.started` | User clicks checkout | `cart_id`, `item_count`, `subtotal` |
| `checkout.completed` | Stripe redirects back | `order_id`, `total`, `payment_method` |
| `order.placed` | Order record created | `order_id`, `email`, `total`, `item_count`, `has_discount` |
| `samples.requested` | Sample-only order | `order_id`, `email`, `sample_count` |

### Scheduled Reorders

| Event | When | Key Payload |
|-------|------|-------------|
| `reorder.scheduled` | User creates schedule | `schedule_id`, `frequency`, `item_count` |
| `reorder.confirmed` | User confirms pending order | `order_id`, `schedule_id`, `total` |

## Operational Events

### Webhooks & Payments

| Event | When | Key Payload |
|-------|------|-------------|
| `webhook.received` | Stripe webhook arrives | `event_type`, `stripe_event_id` |
| `webhook.processed` | Webhook handled successfully | `event_type`, `stripe_event_id`, `order_id` |
| `webhook.failed` | Webhook processing errored | `event_type`, `stripe_event_id`, `error` |
| `payment.succeeded` | Stripe confirms payment | `order_id`, `amount`, `payment_intent_id` |
| `payment.failed` | Payment attempt fails | `email`, `amount`, `error_code`, `decline_reason` |
| `payment.refunded` | Refund processed | `order_id`, `amount`, `reason` |

### Order Lifecycle

| Event | When | Key Payload |
|-------|------|-------------|
| `order.fulfilled` | Order shipped | `order_id`, `tracking_number` |
| `order.cancelled` | Order cancelled | `order_id`, `reason`, `refund_issued` |

### Pending Orders

| Event | When | Key Payload |
|-------|------|-------------|
| `pending_order.created` | Job creates pending order | `pending_order_id`, `schedule_id`, `total` |
| `pending_order.reminder_sent` | Reminder email sent | `pending_order_id`, `email` |
| `pending_order.expired` | Customer didn't confirm | `pending_order_id`, `schedule_id` |
| `reorder.charge_failed` | Scheduled payment failed | `schedule_id`, `email`, `error_code` |

## Implementation

### Files to Create

| File | Purpose |
|------|---------|
| `app/subscribers/event_log_subscriber.rb` | JSON formatter for Logtail |
| `config/initializers/events.rb` | Subscriber registration |

### Files to Modify

| File | Events to Emit |
|------|----------------|
| `app/controllers/application_controller.rb` | Set request context |
| `app/controllers/email_subscriptions_controller.rb` | `email_signup.completed` |
| `app/controllers/cart_items_controller.rb` | `cart.item_added`, `cart.item_removed` |
| `app/controllers/checkouts_controller.rb` | `checkout.*`, `order.placed`, `email_signup.discount_claimed` |
| `app/controllers/pending_orders_controller.rb` | `pending_order.*`, `reorder.confirmed` |
| `app/controllers/reorder_schedules_controller.rb` | `reorder.scheduled` |
| Stripe webhook handler | `webhook.*`, `payment.*` |
| `app/jobs/create_pending_orders_job.rb` | `pending_order.created` |
| `app/services/pending_order_confirmation_service.rb` | `reorder.charge_failed` |

### External Setup

| Service | Action |
|---------|--------|
| Logtail | Create account, add `logtail-rails` gem, configure production logger |

## Querying Events in Logtail

Once implemented, you can query:

- `event:order.placed` — all orders
- `event:payment.failed` — payment failures
- `payload.email:customer@example.com` — trace a customer
- `event:webhook.* AND payload.stripe_event_id:evt_123` — trace a webhook

## Future Enhancements

1. **PostHog integration** — Add `PosthogSubscriber` for funnel visualization
2. **Frontend events** — Track `email_signup.form_viewed` via JS
3. **Admin dashboard** — Query aggregates for at-a-glance metrics
4. **Alerting** — Logtail alerts on `payment.failed` spikes

## Observability Stack Summary

| Purpose | Tool | Status |
|---------|------|--------|
| Traffic sources & Google Ads | GA4 | Already set up |
| Product analytics & funnels | PostHog | Future |
| Error tracking | Sentry | Already set up |
| Structured logs & events | Logtail + Rails.event | This design |
