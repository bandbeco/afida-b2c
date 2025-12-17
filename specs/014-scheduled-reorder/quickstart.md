# Quickstart: Scheduled Reorder with Review

**Feature**: 014-scheduled-reorder
**Date**: 2025-12-16

## Prerequisites

1. **Ruby 3.3.0+** and **Rails 8.x** installed
2. **PostgreSQL 14+** running locally
3. **Stripe CLI** for webhook testing: `brew install stripe/stripe-cli/stripe`
4. **Node.js 18+** for Vite asset compilation

## Setup Steps

### 1. Checkout Feature Branch

```bash
git checkout 014-scheduled-reorder
```

### 2. Install Dependencies

```bash
bundle install
```

### 3. Run Migrations

```bash
rails db:migrate
```

This will create:
- `reorder_schedules` table
- `reorder_schedule_items` table
- `pending_orders` table
- Add `stripe_customer_id` to `users`
- Add `reorder_schedule_id` to `orders`

### 4. Configure Stripe

Ensure your Stripe test credentials are configured:

```bash
rails credentials:edit
```

Verify these keys exist:
```yaml
stripe:
  public_key: pk_test_xxx
  secret_key: sk_test_xxx
  webhook_secret: whsec_xxx  # For webhook verification
```

### 5. Start Development Servers

```bash
bin/dev
```

This starts:
- Rails server on http://localhost:3000
- Vite dev server for assets

### 6. Start Stripe Webhook Forwarding (separate terminal)

```bash
stripe listen --forward-to localhost:3000/webhooks/stripe
```

Note the webhook signing secret and update credentials if needed.

## Testing the Feature

### Manual Testing Flow

#### 1. Create an Order First

1. Browse to http://localhost:3000/shop
2. Add items to cart
3. Complete checkout with test card `4242 4242 4242 4242`
4. Note the order confirmation page

#### 2. Set Up Reorder Schedule

1. On order confirmation, click "Set up reorder schedule"
2. Select frequency (e.g., "Monthly")
3. Complete Stripe Setup to save payment method
4. Verify schedule appears in "My Reorder Schedules"

#### 3. Trigger Pending Order Creation

For testing, manually create a pending order:

```bash
rails console
```

```ruby
# Find an active schedule
schedule = ReorderSchedule.active.first

# Create pending order (normally done by background job)
CreatePendingOrderFromSchedule.call(schedule)

# Check the pending order
schedule.pending_orders.pending.last
```

#### 4. Test Email Links

In development, emails are logged. Check the Rails console or use:

```ruby
# Get the confirmation URL
pending_order = PendingOrder.pending.last
token = pending_order.confirmation_token
puts "http://localhost:3000/pending-orders/#{pending_order.id}/confirm?token=#{token}"
```

Visit the URL to test one-click confirmation.

### Running Automated Tests

```bash
# Run all tests
rails test

# Run model tests only
rails test test/models/reorder_schedule_test.rb
rails test test/models/reorder_schedule_item_test.rb
rails test test/models/pending_order_test.rb

# Run controller tests
rails test test/controllers/reorder_schedules_controller_test.rb
rails test test/controllers/pending_orders_controller_test.rb

# Run service tests
rails test test/services/reorder_schedule_setup_service_test.rb
rails test test/services/pending_order_confirmation_service_test.rb

# Run system tests (requires Chrome/Selenium)
rails test:system
```

### Testing Background Jobs

```bash
rails console
```

```ruby
# Manually run the pending order creation job
CreatePendingOrdersJob.perform_now

# Manually run the expiration job
ExpirePendingOrdersJob.perform_now
```

## Key Files

### Models
- `app/models/reorder_schedule.rb`
- `app/models/reorder_schedule_item.rb`
- `app/models/pending_order.rb`

### Controllers
- `app/controllers/reorder_schedules_controller.rb`
- `app/controllers/pending_orders_controller.rb`

### Services
- `app/services/reorder_schedule_setup_service.rb`
- `app/services/pending_order_confirmation_service.rb`

### Jobs
- `app/jobs/create_pending_orders_job.rb`
- `app/jobs/expire_pending_orders_job.rb`

### Views
- `app/views/reorder_schedules/`
- `app/views/pending_orders/`
- `app/views/reorder_mailer/`

### Configuration
- `config/recurring.yml` - Background job schedules

## Stripe Test Cards

| Scenario | Card Number |
|----------|-------------|
| Success | 4242 4242 4242 4242 |
| Decline | 4000 0000 0000 9995 |
| Requires Auth | 4000 0025 0000 3155 |
| Insufficient Funds | 4000 0000 0000 9995 |

Use any future expiration date and any 3-digit CVC.

## Troubleshooting

### "Stripe webhook signature verification failed"

Ensure `stripe.webhook_secret` in credentials matches the secret from `stripe listen`.

### "Payment method not found"

The Stripe Setup session may not have completed. Check:
1. User has `stripe_customer_id`
2. ReorderSchedule has valid `stripe_payment_method_id`

### "No pending orders created"

Check:
1. Schedule is `active` status
2. `next_scheduled_date` is exactly 3 days from today
3. Job is configured in `config/recurring.yml`

### System tests failing

Ensure Chrome and ChromeDriver are installed:
```bash
brew install chromedriver
```

## Development Tips

1. **Skip email delivery in tests**: Already configured via `config/environments/test.rb`

2. **Mock Stripe in tests**: Use `Stripe::Mock` or stub API calls

3. **Time travel for job testing**:
```ruby
travel_to 3.days.from_now do
  CreatePendingOrdersJob.perform_now
end
```

4. **View emails in development**: Check `log/development.log` or use Letter Opener gem
