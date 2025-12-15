# API Contracts: Sign-Up & Account Experience

**Feature Branch**: `001-sign-up-accounts`
**Date**: 2025-12-15

## Endpoint Summary

| Method | Path | Controller#Action | Auth | Description |
|--------|------|-------------------|------|-------------|
| GET | `/sign_up` | `registrations#new` | No | Sign-up page with value messaging |
| POST | `/sign_up` | `registrations#create` | No | Create account |
| POST | `/post_checkout_registration` | `post_checkout_registrations#create` | No* | Convert guest to account |
| GET | `/orders` | `orders#index` | Yes | Order history with reorder |
| POST | `/orders/:id/reorder` | `orders#reorder` | Yes | Add order items to cart |
| GET | `/account` | `accounts#show` | Yes | Account settings |
| PATCH | `/account` | `accounts#update` | Yes | Update email/password |
| GET | `/subscriptions` | `subscriptions#index` | Yes | List subscriptions |
| DELETE | `/subscriptions/:id` | `subscriptions#destroy` | Yes | Cancel subscription |
| POST | `/subscription_checkouts` | `subscription_checkouts#create` | Yes | Create subscription checkout |
| GET | `/subscription_checkouts/success` | `subscription_checkouts#success` | Yes | Handle successful subscription |
| POST | `/webhooks/stripe` | `webhooks/stripe#create` | N/A | Stripe webhook handler |

*Requires valid session with recent_order_id

---

## Endpoint Details

### POST /post_checkout_registration

**Purpose**: Convert guest order to new account after checkout

**Request**:
```json
{
  "user": {
    "password": "securepassword123",
    "password_confirmation": "securepassword123"
  }
}
```

**Prerequisites**:
- `session[:recent_order_id]` must be set (proves order ownership)
- Order must not already have a user

**Success Response** (302 Redirect):
```
Location: /orders/:order_id/confirmation?token=xxx
Set-Cookie: _session_id=xxx (logged in)
```

**Error Responses**:

| Status | Condition | Response |
|--------|-----------|----------|
| 422 | Password validation failed | Re-render confirmation with errors |
| 422 | Email already registered | Show login link message |
| 403 | No recent order in session | Redirect to home |

---

### POST /orders/:id/reorder

**Purpose**: Add all items from a previous order to current cart

**Request**: No body required (order ID in URL)

**Success Response** (302 Redirect):
```
Location: /cart
Flash: { notice: "5 items added to your cart" }
```

**Partial Success Response** (302 Redirect):
```
Location: /cart
Flash: { notice: "3 items added to your cart. 2 items are no longer available." }
```

**Error Responses**:

| Status | Condition | Response |
|--------|-----------|----------|
| 404 | Order not found or not owned by user | Redirect to orders |
| 422 | All items unavailable | Flash error, stay on page |

---

### GET /account

**Purpose**: Display account settings

**Response** (HTML):
```html
<!-- Account settings page -->
<h1>Account Settings</h1>
<form action="/account" method="post">
  <input name="_method" value="patch">
  <input name="user[email_address]" value="current@email.com">
  <input name="user[current_password]">
  <input name="user[password]">
  <input name="user[password_confirmation]">
  <button type="submit">Update</button>
</form>
```

---

### PATCH /account

**Purpose**: Update account email or password

**Request**:
```json
{
  "user": {
    "email_address": "new@email.com",
    "current_password": "oldpassword",
    "password": "newpassword",
    "password_confirmation": "newpassword"
  }
}
```

**Validation Rules**:
- `current_password` required for any change
- `email_address` must be unique
- `password` and `password_confirmation` must match (if changing password)

**Success Response** (302 Redirect):
```
Location: /account
Flash: { notice: "Account updated successfully" }
```

**Error Response** (422):
```html
<!-- Re-render form with errors -->
```

---

### GET /subscriptions

**Purpose**: List user's subscriptions

**Response** (HTML):
```html
<h1>Your Subscriptions</h1>
<div class="subscription-card">
  <h3>Every 2 weeks</h3>
  <p>Next order: Dec 29, 2025</p>
  <ul>
    <li>Single Wall Cup 8oz (x2)</li>
    <li>Paper Napkins (x1)</li>
  </ul>
  <button data-turbo-method="delete"
          data-turbo-confirm="Cancel this subscription?">
    Cancel
  </button>
</div>
```

---

### DELETE /subscriptions/:id

**Purpose**: Cancel a subscription

**Request**: No body (subscription ID in URL)

**Behavior**:
1. Call Stripe API to cancel subscription
2. Update local subscription status to `cancelled`
3. Set `cancelled_at` timestamp

**Success Response** (302 Redirect):
```
Location: /subscriptions
Flash: { notice: "Subscription cancelled. No future orders will be placed." }
```

**Error Response**:

| Status | Condition | Response |
|--------|-----------|----------|
| 404 | Subscription not found or not owned | Redirect with error |
| 422 | Stripe API error | Flash error, redirect back |

---

### POST /subscription_checkouts

**Purpose**: Create Stripe Checkout session for subscription

**Prerequisites**:
- User must be logged in
- Cart must have items
- Subscription frequency must be specified

**Request**:
```json
{
  "subscription": {
    "frequency": "biweekly"
  }
}
```

**Behavior**:
1. Build line items from cart (same as regular checkout)
2. Create Stripe Price for the subscription total
3. Create Stripe Checkout Session with `mode: 'subscription'`
4. Redirect to Stripe Checkout

**Success Response** (303 Redirect):
```
Location: https://checkout.stripe.com/pay/xxx
```

**Error Responses**:

| Status | Condition | Response |
|--------|-----------|----------|
| 401 | Not logged in | Redirect to login |
| 422 | Empty cart | Flash error, redirect to cart |
| 422 | Invalid frequency | Flash error, redirect to cart |
| 500 | Stripe error | Flash error, redirect to cart |

---

### GET /subscription_checkouts/success

**Purpose**: Handle successful subscription checkout

**Query Parameters**:
- `session_id` - Stripe Checkout session ID

**Behavior**:
1. Retrieve Stripe session
2. Verify payment status
3. Create local Subscription record
4. Clear cart
5. Redirect to subscriptions page

**Success Response** (302 Redirect):
```
Location: /subscriptions
Flash: { notice: "Subscription created! Your first order is being processed." }
```

---

### POST /webhooks/stripe

**Purpose**: Handle Stripe webhook events

**Events Handled**:

| Event | Action |
|-------|--------|
| `checkout.session.completed` (subscription) | Create Subscription record |
| `invoice.payment_succeeded` | Create Order from subscription |
| `invoice.payment_failed` | Update subscription status to paused |
| `customer.subscription.updated` | Sync subscription status |
| `customer.subscription.deleted` | Mark subscription cancelled |

**Request Headers**:
```
Stripe-Signature: t=xxx,v1=xxx
Content-Type: application/json
```

**Response**:
- 200 OK - Event processed
- 400 Bad Request - Invalid signature
- 500 Internal Error - Processing failed (Stripe will retry)

---

## Routes Configuration

```ruby
# config/routes.rb additions

# Account management
resource :account, only: [:show, :update]

# Post-checkout registration
resource :post_checkout_registration, only: [:create]

# Subscriptions
resources :subscriptions, only: [:index, :destroy]

# Subscription checkout
resources :subscription_checkouts, only: [:create] do
  collection do
    get :success
    get :cancel
  end
end

# Reorder action on orders
resources :orders, only: [:index, :show] do
  member do
    post :reorder
  end
  get :confirmation, on: :member
end

# Stripe webhooks (may already exist)
namespace :webhooks do
  post :stripe, to: 'stripe#create'
end
```

---

## Request/Response Formats

All endpoints use standard Rails conventions:
- HTML responses for browser requests
- Turbo Stream responses where appropriate
- JSON only for webhook endpoints
- CSRF protection on all POST/PATCH/DELETE (except webhooks)
