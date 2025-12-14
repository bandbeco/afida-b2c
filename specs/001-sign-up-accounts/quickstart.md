# Quickstart: Sign-Up & Account Experience

**Feature Branch**: `001-sign-up-accounts`
**Date**: 2025-12-15

## Prerequisites

- Ruby 3.3.0+
- Node.js 18+
- PostgreSQL 14+
- Stripe CLI (for webhook testing)

## Setup

### 1. Switch to Feature Branch

```bash
git checkout 001-sign-up-accounts
```

### 2. Install Dependencies

```bash
bin/setup --skip-server
```

### 3. Run Migrations

```bash
rails db:migrate
```

### 4. Configure Stripe (if not already done)

Ensure your Stripe test credentials are in Rails credentials:

```bash
rails credentials:edit
```

Required keys:
```yaml
stripe:
  publishable_key: pk_test_xxx
  secret_key: sk_test_xxx
  webhook_signing_secret: whsec_xxx  # For subscription webhooks
```

### 5. Start Development Server

```bash
bin/dev
```

Application runs at http://localhost:3000

---

## Testing Subscriptions Locally

### Stripe CLI for Webhooks

Subscriptions require webhook events. Use Stripe CLI to forward events locally:

```bash
# Install Stripe CLI if needed
brew install stripe/stripe-cli/stripe

# Login to Stripe
stripe login

# Forward webhooks to local server
stripe listen --forward-to localhost:3000/webhooks/stripe

# Note the webhook signing secret output (whsec_xxx)
# Add it to Rails credentials as stripe.webhook_signing_secret
```

### Test Subscription Flow

1. **Create an account** at http://localhost:3000/sign_up

2. **Add items to cart** at http://localhost:3000/shop

3. **Enable subscription** in cart:
   - Check "Make this a recurring order"
   - Select frequency (Weekly, Every 2 weeks, Monthly)

4. **Complete checkout** with test card:
   - Card: `4242 4242 4242 4242`
   - Expiry: Any future date
   - CVC: Any 3 digits

5. **Verify subscription created** at http://localhost:3000/subscriptions

6. **Simulate renewal** (in separate terminal):
   ```bash
   # Trigger invoice payment event
   stripe trigger invoice.payment_succeeded
   ```

7. **Check order created** at http://localhost:3000/orders

### Test Reorder Flow

1. **Place a regular order** (no subscription)

2. **View order history** at http://localhost:3000/orders

3. **Click "Reorder"** on any past order

4. **Verify items in cart** at http://localhost:3000/cart

### Test Guest-to-Account Conversion

1. **Log out** if logged in

2. **Add items and checkout as guest**

3. **On confirmation page**, enter password to create account

4. **Verify logged in** and order appears in history

---

## Running Tests

```bash
# All tests
rails test

# Model tests only
rails test test/models/

# Subscription-specific tests
rails test test/models/subscription_test.rb
rails test test/controllers/subscriptions_controller_test.rb
rails test test/system/subscription_test.rb

# Reorder tests
rails test test/services/reorder_service_test.rb
rails test test/system/reorder_test.rb
```

---

## Key Files

### Models
- `app/models/subscription.rb` - Subscription model
- `app/models/user.rb` - User with subscriptions association
- `app/models/order.rb` - Order with subscription reference

### Controllers
- `app/controllers/subscriptions_controller.rb` - Subscription management
- `app/controllers/subscription_checkouts_controller.rb` - Subscription checkout
- `app/controllers/post_checkout_registrations_controller.rb` - Guest conversion
- `app/controllers/accounts_controller.rb` - Account settings
- `app/controllers/orders_controller.rb` - Extended with reorder

### Services
- `app/services/reorder_service.rb` - Reorder business logic
- `app/services/subscription_service.rb` - Stripe subscription integration

### Views
- `app/views/registrations/new.html.erb` - Enhanced sign-up page
- `app/views/orders/index.html.erb` - Order history with reorder
- `app/views/orders/confirmation.html.erb` - Guest conversion form
- `app/views/subscriptions/index.html.erb` - Subscription management
- `app/views/accounts/show.html.erb` - Account settings

### JavaScript
- `app/frontend/javascript/controllers/account_dropdown_controller.js`
- `app/frontend/javascript/controllers/subscription_toggle_controller.js`

---

## Stripe Test Cards

| Scenario | Card Number |
|----------|-------------|
| Successful payment | `4242 4242 4242 4242` |
| Requires authentication | `4000 0025 0000 3155` |
| Card declined | `4000 0000 0000 9995` |
| Insufficient funds | `4000 0000 0000 9995` |

For subscription testing, use `4242 4242 4242 4242` for reliable success.

---

## Common Issues

### Webhook Not Receiving Events

1. Check Stripe CLI is running: `stripe listen --forward-to localhost:3000/webhooks/stripe`
2. Verify webhook signing secret matches credentials
3. Check Rails logs for webhook errors

### Subscription Not Created

1. Verify user is logged in before checkout
2. Check subscription checkbox is enabled in cart
3. Verify Stripe webhook handler is processing `checkout.session.completed`

### Reorder Items Missing

1. Check product/variant still exists and is active
2. Review flash message for "items no longer available"
3. Verify order belongs to current user

---

## Development Tips

### Viewing Stripe Dashboard

- Subscriptions: https://dashboard.stripe.com/test/subscriptions
- Customers: https://dashboard.stripe.com/test/customers
- Invoices: https://dashboard.stripe.com/test/invoices
- Webhooks: https://dashboard.stripe.com/test/webhooks

### Resetting Test Data

```bash
# Reset database (loses all orders, users, etc.)
rails db:reset

# Cancel all test subscriptions in Stripe
# (Do this in Stripe dashboard or via Stripe CLI)
```

### Debugging Webhooks

```ruby
# In rails console
Stripe::Event.list(limit: 10).each { |e| puts "#{e.type}: #{e.id}" }
```
