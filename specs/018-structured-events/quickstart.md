# Quickstart: Structured Events Infrastructure

**Feature**: 018-structured-events
**Date**: 2026-01-16

## Prerequisites

- Rails 8.1.1 (already installed)
- Logtail account with source token

## Setup Steps

### 1. Install logtail-rails gem

```bash
bundle add logtail-rails
```

### 2. Add Logtail credentials

```bash
# Development
rails credentials:edit --environment development

# Add:
logtail:
  source_token: "your_dev_source_token"

# Production
rails credentials:edit

# Add:
logtail:
  source_token: "your_prod_source_token"
```

### 3. Create Logtail initializer

```ruby
# config/initializers/logtail.rb
if Rails.application.credentials.dig(:logtail, :source_token).present?
  Logtail.configure do |config|
    config.api_key = Rails.application.credentials.dig(:logtail, :source_token)
  end
end
```

### 4. Create EventLogSubscriber

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

### 5. Register subscriber

```ruby
# config/initializers/events.rb
Rails.event.subscribe(EventLogSubscriber.new)
```

### 6. Add EventContext concern

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
```

### 7. Include in ApplicationController

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include EventContext
  # ... rest of controller
end
```

## Emitting Events

```ruby
# In any controller, service, or job:
Rails.event.notify("order.placed",
  order_id: order.id,
  email: order.email,
  total: order.total_amount,
  item_count: order.order_items.count,
  has_discount: order.discount_applied?,
  source: "checkout"
)
```

## Testing Events

```ruby
# In tests:
test "emits order.placed event on checkout success" do
  assert_event_reported("order.placed", payload: { order_id: Integer }) do
    post checkout_success_path(session_id: @stripe_session.id)
  end
end

test "does not emit event on failure" do
  assert_no_event_reported("order.placed") do
    post checkout_success_path(session_id: "invalid")
  end
end
```

## Querying Events in Logtail

Once events are flowing, query in Logtail:

```
# All orders
event:order.placed

# Specific customer journey
payload.email:customer@example.com

# Payment failures
event:payment.failed

# Trace a webhook
event:webhook.* AND payload.stripe_event_id:evt_123

# Orders with discounts
event:order.placed AND payload.has_discount:true
```

## Verification Checklist

- [ ] `bundle exec rails console` — verify `Rails.event` is available
- [ ] Logtail source token in credentials
- [ ] EventLogSubscriber created and autoloaded
- [ ] Events initializer registers subscriber
- [ ] EventContext concern included in ApplicationController
- [ ] Test with: `Rails.event.notify("test.event", foo: "bar")` in console
- [ ] Check Logtail dashboard for test event
