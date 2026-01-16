# Email Signup Discount Feature

**Date:** 2026-01-16
**Status:** Ready for implementation

## Overview

Offer 5% off the first order to visitors who sign up for the email list. The goal is to convert fence-sitters and build a qualified marketing list.

## User Experience

### Cart Page Component

A signup form appears on the cart page for eligible visitors:

```
┌─────────────────────────────────────────────────────────────┐
│  🎉 First order? Get 5% off                                 │
│                                                             │
│  Sign up for news & promotions to unlock your discount.     │
│                                                             │
│  ┌─────────────────────────────┐  ┌──────────────┐          │
│  │ Enter your email            │  │ Get 5% off   │          │
│  └─────────────────────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

After successful signup:

```
┌─────────────────────────────────────────────────────────────┐
│  ✓ 5% discount applied!                                     │
│                                                             │
│  You're saving £X.XX on this order.                         │
└─────────────────────────────────────────────────────────────┘
```

### Form States

| State | Condition | Display |
|-------|-----------|---------|
| Default | Eligible visitor | Email input + "Get 5% off" button |
| Success | Just signed up | "✓ 5% discount applied!" with savings amount |
| Already claimed | Email already subscribed | "You've already claimed this offer" |
| Not eligible | Email has previous orders | "This offer is for first-time customers" |
| Hidden | Logged-in user with order history | Component not rendered |

### Flow

1. Visitor adds items to cart and views cart page
2. If eligible, they see the signup form with calculated savings
3. They enter email and submit
4. Backend validates eligibility and stores subscription
5. Discount code stored in session, success message shown
6. At checkout, coupon automatically applied to Stripe session
7. Stripe Checkout shows 5% discount on order summary

## Eligibility Rules

A visitor is eligible for the discount if ALL conditions are true:

1. **Not already subscribed:** Email not in `email_subscriptions` table
2. **No previous orders:** Email not in `orders` table
3. **Not a returning logged-in user:** If logged in, user has no order history

## Data Model

### New Table: `email_subscriptions`

```ruby
create_table :email_subscriptions do |t|
  t.string :email, null: false
  t.datetime :discount_claimed_at
  t.string :source, null: false, default: "cart_discount"
  t.timestamps

  t.index :email, unique: true
end
```

| Column | Type | Purpose |
|--------|------|---------|
| `email` | string | Subscriber email (unique) |
| `discount_claimed_at` | datetime | When discount was claimed (null if just subscribed elsewhere) |
| `source` | string | Signup source: `"cart_discount"`, `"footer"`, etc. |

### Model: `EmailSubscription`

```ruby
class EmailSubscription < ApplicationRecord
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :source, presence: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  def self.eligible_for_discount?(email)
    normalized = email.strip.downcase

    # Check if already subscribed
    return false if exists?(email: normalized)

    # Check if has previous orders
    return false if Order.exists?(email: normalized)

    true
  end
end
```

## Stripe Integration

### Coupon Setup

Create a single reusable coupon in Stripe:

- **ID:** `WELCOME5`
- **Type:** Percentage discount
- **Amount:** 5% off
- **Duration:** Once (applies to single checkout)
- **Redemption limit:** None (we control eligibility)

### Checkout Flow

```
Cart page                          Backend                              Stripe
    │                                 │                                    │
    │ ── POST /email_subscriptions ─▶ │                                    │
    │                                 │ Validate eligibility               │
    │                                 │ Create EmailSubscription           │
    │   ◀── Turbo Stream response ─── │ Set session[:discount_code]        │
    │                                 │                                    │
    │ ── POST /checkout ────────────▶ │                                    │
    │                                 │ Read session[:discount_code]       │
    │                                 │ ── Create Checkout Session ──────▶ │
    │                                 │    discounts: [{ coupon: code }]   │
    │                                 │                                    │
    │   ◀─────────────────────── Redirect to Stripe Checkout ──────────────│
```

### CheckoutsController Changes

```ruby
# In create action, before creating Stripe session:
if session[:discount_code].present?
  session_params[:discounts] = [{ coupon: session[:discount_code] }]
end
```

```ruby
# In success action, after creating order:
session.delete(:discount_code)
```

## Implementation Components

### Files to Create

| File | Purpose |
|------|---------|
| `db/migrate/XXXXXX_create_email_subscriptions.rb` | Database migration |
| `app/models/email_subscription.rb` | Model with validation and eligibility check |
| `app/controllers/email_subscriptions_controller.rb` | Handle signup requests |
| `app/views/email_subscriptions/_cart_signup_form.html.erb` | Cart page component |
| `app/views/email_subscriptions/create.turbo_stream.erb` | Success response |
| `app/frontend/javascript/controllers/discount_signup_controller.js` | Form UX |
| `test/models/email_subscription_test.rb` | Model tests |
| `test/controllers/email_subscriptions_controller_test.rb` | Controller tests |
| `test/system/email_signup_discount_test.rb` | End-to-end flow test |

### Files to Modify

| File | Change |
|------|--------|
| `config/routes.rb` | Add `resources :email_subscriptions, only: [:create]` |
| `app/views/carts/show.html.erb` | Render `email_subscriptions/cart_signup_form` partial |
| `app/controllers/checkouts_controller.rb` | Apply coupon from session |
| `app/frontend/entrypoints/application.js` | Register Stimulus controller |

## Controller Logic

### EmailSubscriptionsController

```ruby
class EmailSubscriptionsController < ApplicationController
  allow_unauthenticated_access

  def create
    email = params[:email]&.strip&.downcase

    # Check eligibility
    unless EmailSubscription.eligible_for_discount?(email)
      # Determine reason for ineligibility
      if EmailSubscription.exists?(email: email)
        render turbo_stream: turbo_stream.replace(
          "discount-signup",
          partial: "email_subscriptions/already_claimed"
        )
      else
        render turbo_stream: turbo_stream.replace(
          "discount-signup",
          partial: "email_subscriptions/not_eligible"
        )
      end
      return
    end

    # Create subscription
    @subscription = EmailSubscription.create!(
      email: email,
      source: "cart_discount",
      discount_claimed_at: Time.current
    )

    # Store discount in session
    session[:discount_code] = "WELCOME5"

    # Calculate savings for display
    @savings_amount = Current.cart.subtotal_amount * 0.05

    render turbo_stream: turbo_stream.replace(
      "discount-signup",
      partial: "email_subscriptions/success",
      locals: { savings_amount: @savings_amount }
    )
  end
end
```

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Guest claims discount, then logs in | Discount remains in session, applied at checkout |
| User logs in after claiming discount as guest | Session persists, discount still valid |
| User abandons cart, returns later | Session may expire; they can re-enter email |
| Same email used for order + subscription check | Both checks use case-insensitive comparison |
| Discount claimed but checkout fails | Discount remains in session for retry |
| Browser blocks cookies | First-party Rails session cookies not affected |

## Future Considerations (Not in Scope)

- Footer signup form (different source, no instant discount)
- Email alias normalization (monitor for abuse first)
- Welcome email with discount code for non-cart signups
- Admin view of subscriptions
- Mailgun/marketing platform sync

## Testing Plan

### Model Tests
- Email uniqueness (case-insensitive)
- Email format validation
- `eligible_for_discount?` with various scenarios

### Controller Tests
- Successful signup returns success partial
- Already subscribed returns already_claimed partial
- Email with previous orders returns not_eligible partial
- Session contains discount code after success

### System Test
- Full flow: add to cart → sign up → checkout → verify discount applied
- Verify form not shown for logged-in users with orders
