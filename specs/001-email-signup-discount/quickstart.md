# Quickstart: Email Signup Discount

**Feature**: 001-email-signup-discount
**Date**: 2026-01-16

## Prerequisites

- Ruby 3.4.7 / Rails 8.1.1 environment
- PostgreSQL running
- Stripe account with test API keys configured
- Development server running (`bin/dev`)

## One-Time Setup

### 1. Create Stripe Coupon

Create the `WELCOME5` coupon in Stripe (test mode first, then production):

**Via Stripe Dashboard**:
1. Go to Products → Coupons → Create coupon
2. Set:
   - ID: `WELCOME5`
   - Percent off: 5%
   - Duration: Once
   - Leave redemption limit empty

**Via Stripe CLI** (if installed):
```bash
stripe coupons create \
  --id=WELCOME5 \
  --percent-off=5 \
  --duration=once
```

**Via Rails console**:
```ruby
Stripe::Coupon.create(
  id: "WELCOME5",
  percent_off: 5,
  duration: "once"
)
```

## Development Workflow

### Run Tests

```bash
# All tests for this feature
rails test test/models/email_subscription_test.rb \
           test/controllers/email_subscriptions_controller_test.rb \
           test/system/email_signup_discount_test.rb

# Model tests only
rails test test/models/email_subscription_test.rb

# Controller tests only
rails test test/controllers/email_subscriptions_controller_test.rb

# System tests only
rails test:system test/system/email_signup_discount_test.rb
```

### Run Migrations

```bash
rails db:migrate
```

### Manual Testing

1. Start development server: `bin/dev`
2. Add item to cart: Visit any product page, click "Add to Cart"
3. View cart page: `/cart`
4. Enter email in signup form
5. Verify success message shows calculated savings
6. Proceed to checkout
7. Verify 5% discount appears in Stripe Checkout

### Test Scenarios

| Scenario | Email to Use | Expected Result |
|----------|--------------|-----------------|
| New visitor | Any new email | Success, discount applied |
| Already claimed | Use same email twice | "Already claimed" message |
| Existing customer | Email from orders table | "Not eligible" message |
| Logged-in with orders | Log in first | Form not shown |

## Key Files

| File | Purpose |
|------|---------|
| `app/models/email_subscription.rb` | Model with eligibility logic |
| `app/controllers/email_subscriptions_controller.rb` | Form submission handler |
| `app/views/email_subscriptions/_cart_signup_form.html.erb` | Form component |
| `app/views/carts/show.html.erb` | Cart page (renders form) |
| `app/controllers/checkouts_controller.rb` | Applies coupon at checkout |
| `app/frontend/javascript/controllers/discount_signup_controller.js` | Form UX |

## Troubleshooting

### Form not appearing on cart page

1. Check if logged-in user has orders: `Current.user.orders.exists?`
2. Verify partial is rendered in `carts/show.html.erb`
3. Check for JavaScript errors in browser console

### Discount not applied at checkout

1. Verify `session[:discount_code]` is set: Add `Rails.logger.info(session[:discount_code])` in checkout controller
2. Verify Stripe coupon exists: Check Stripe Dashboard → Coupons
3. Check for Stripe API errors in Rails logs

### Turbo Stream not working

1. Verify Turbo is loaded: Check for `<meta name="turbo-root">` in page source
2. Verify form has `data-turbo="true"`
3. Check response Content-Type is `text/vnd.turbo-stream.html`

## Verification Checklist

Before marking implementation complete:

- [ ] Model tests pass
- [ ] Controller tests pass
- [ ] System tests pass
- [ ] RuboCop passes
- [ ] Form appears for eligible visitors
- [ ] Form hidden for logged-in users with orders
- [ ] Success state shows correct savings amount
- [ ] Discount applies in Stripe Checkout
- [ ] Discount cleared after successful order
- [ ] Stripe coupon created in production
