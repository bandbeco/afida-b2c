# Research: Structured Events Infrastructure

**Feature**: 018-structured-events
**Date**: 2026-01-16
**Status**: Complete

## Research Questions Resolved

### 1. Event Emission API

**Decision**: Use Rails 8.1's `Rails.event` API

**Rationale**:
- Native to Rails 8.1 (already on Rails 8.1.1)
- Provides structured events with automatic metadata (timestamp, source_location)
- Subscriber pattern allows multiple destinations
- Built-in test helpers (`assert_event_reported`, `assert_no_event_reported`)
- No additional gem required for core functionality

**Alternatives Considered**:
- `ActiveSupport::Notifications` — Lower-level, requires manual metadata, designed for instrumentation not business events
- Custom event class — Reinvents the wheel, no test helper support
- Direct Logtail API calls — Couples business logic to logging infrastructure

**API Reference**:
```ruby
# Emit event
Rails.event.notify("order.placed", order_id: 123, email: "customer@example.com")

# Set request context (attached to all events in request)
Rails.event.set_context(request_id: request.request_id, user_id: current_user&.id)

# Subscribe to events
Rails.event.subscribe(EventLogSubscriber.new)

# Event structure received by subscriber
{
  name: "order.placed",
  payload: { order_id: 123, email: "customer@example.com" },
  context: { request_id: "abc-123", user_id: 456 },
  tags: {},
  timestamp: 1738964843208679035,  # nanoseconds
  source_location: { filepath: "...", lineno: 45, label: "..." }
}
```

### 2. Log Transport to Logtail

**Decision**: Use `logtail-rails` gem (v0.2.12+)

**Rationale**:
- Official Better Stack (Logtail) integration for Rails
- Automatically subscribes to Rails.event when using `Logtail::Logger.create_default_logger`
- Structured JSON logging out of the box
- 1GB/month free tier sufficient for current volume
- Simple configuration via initializer

**Alternatives Considered**:
- Manual HTTP calls to Logtail API — More work, no automatic Rails integration
- Papertrail — Smaller free tier (50MB), less structured query support
- Self-hosted Loki — Operational overhead, premature for current scale

**Setup**:
```ruby
# Gemfile
gem "logtail-rails", "~> 0.2"

# config/initializers/logtail.rb
Logtail.configure do |config|
  config.api_key = Rails.application.credentials.dig(:logtail, :source_token)
end
```

### 3. Event Naming Convention

**Decision**: `domain.action` pattern with past tense for completed actions

**Rationale**:
- Consistent with industry standards (Segment, Amplitude, PostHog)
- Domain prefix enables filtering (`event:order.*`)
- Past tense clarifies event represents completed action
- Easy to grep/search across codebase

**Convention**:
| Pattern | Example | When to Use |
|---------|---------|-------------|
| `domain.action` | `order.placed` | All events |
| Past tense | `completed`, `failed` | Completed actions |
| Present participle | `processing` | In-progress (rarely used) |
| Include `source` | `source: "webhook"` | When origin matters |

**Alternatives Considered**:
- Schematized event classes — More overhead for ~20 events, defer until scale demands
- `action_domain` pattern — Less intuitive for filtering

### 4. Subscriber Architecture

**Decision**: Single `EventLogSubscriber` that formats to JSON, extensible to multiple subscribers

**Rationale**:
- Start simple with one destination (Logtail)
- Subscriber pattern makes adding PostHog trivial later
- Separation of concerns: business code emits events, subscribers route them

**Pattern**:
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

# config/initializers/events.rb
Rails.event.subscribe(EventLogSubscriber.new)
```

**Future Extension**:
```ruby
# Add PostHog later without changing business code
Rails.event.subscribe(PosthogSubscriber.new) if Rails.env.production?
```

### 5. Request Context Strategy

**Decision**: Use `ApplicationController` concern with `before_action`

**Rationale**:
- Sets context once per request, inherited by all events
- Concern pattern allows reuse in API controllers if needed
- Simpler than custom middleware

**Implementation**:
```ruby
# app/controllers/concerns/event_context.rb
module EventContext
  extend ActiveSupport::Concern

  included do
    before_action :set_event_context
  end

  private

  def set_event_context
    Rails.event.set_context(
      request_id: request.request_id,
      user_id: Current.user&.id,
      session_id: Current.session&.id
    )
  end
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include EventContext
end
```

### 6. Testing Strategy

**Decision**: Use Rails 8.1 built-in test helpers

**Rationale**:
- `assert_event_reported` and `assert_no_event_reported` are purpose-built
- No test gem dependencies
- Assertions are clear and readable

**Pattern**:
```ruby
test "emits order.placed event on checkout" do
  assert_event_reported("order.placed", payload: { order_id: Integer }) do
    post checkout_success_path(session_id: @stripe_session.id)
  end
end

test "does not emit event on validation failure" do
  assert_no_event_reported("email_signup.completed") do
    post email_subscriptions_path, params: { email: "invalid" }
  end
end
```

## Event Catalog

### Customer Journey Events

| Event Name | Trigger | Required Payload |
|------------|---------|-----------------|
| `email_signup.completed` | Email form submitted | `email`, `source`, `discount_eligible` |
| `email_signup.discount_claimed` | Discount applied at checkout | `email`, `order_id`, `discount_amount` |
| `cart.item_added` | Product added to cart | `product_id`, `product_sku`, `quantity`, `is_sample` |
| `cart.item_removed` | Product removed from cart | `product_id`, `product_sku` |
| `checkout.started` | User initiates checkout | `cart_id`, `item_count`, `subtotal` |
| `checkout.completed` | Stripe redirects back success | `order_id`, `total`, `payment_method` |
| `order.placed` | Order record created | `order_id`, `email`, `total`, `item_count`, `has_discount` |
| `samples.requested` | Sample-only order placed | `order_id`, `email`, `sample_count` |

### Operational Events

| Event Name | Trigger | Required Payload |
|------------|---------|-----------------|
| `webhook.received` | Stripe webhook arrives | `event_type`, `stripe_event_id` |
| `webhook.processed` | Webhook handled successfully | `event_type`, `stripe_event_id`, `order_id` |
| `webhook.failed` | Webhook processing error | `event_type`, `stripe_event_id`, `error` |
| `payment.succeeded` | Stripe confirms payment | `order_id`, `amount`, `payment_intent_id` |
| `payment.failed` | Payment declined | `email`, `amount`, `error_code`, `decline_reason` |
| `payment.refunded` | Refund processed | `order_id`, `amount`, `reason` |
| `order.fulfilled` | Order shipped | `order_id`, `tracking_number` |
| `order.cancelled` | Order cancelled | `order_id`, `reason`, `refund_issued` |

### Scheduled Reorder Events

| Event Name | Trigger | Required Payload |
|------------|---------|-----------------|
| `reorder.scheduled` | Schedule created | `schedule_id`, `frequency`, `item_count` |
| `reorder.confirmed` | Pending order confirmed | `order_id`, `schedule_id`, `total` |
| `reorder.charge_failed` | Scheduled payment failed | `schedule_id`, `email`, `error_code` |
| `pending_order.created` | Job creates pending order | `pending_order_id`, `schedule_id`, `total` |
| `pending_order.reminder_sent` | Reminder email sent | `pending_order_id`, `email` |
| `pending_order.expired` | Customer didn't confirm | `pending_order_id`, `schedule_id` |

## External Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| Rails | 8.1.1 | `Rails.event` API (already installed) |
| logtail-rails | ~> 0.2 | Structured log transport to Better Stack |

## Credentials Required

```yaml
# config/credentials.yml.enc (production)
logtail:
  source_token: "your_logtail_source_token"
```

## Sources

- [Rails Structured Event Reporting](https://blog.saeloun.com/2025/12/18/rails-introduces-structured-event-reporting/)
- [logtail-rails gem](https://github.com/logtail/logtail-ruby-rails)
- [Better Stack Ruby & Rails logging](https://betterstack.com/docs/logs/ruby-and-rails/)
