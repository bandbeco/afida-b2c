# API Contracts: Stripe Subscription Checkout

**Feature Branch**: `012-stripe-subscriptions`
**Phase**: 1 - Design
**Date**: 2025-12-15

## Overview

This document defines the HTTP endpoints and webhook handlers for the subscription checkout feature.

## Endpoints Summary

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/subscription_checkouts` | Required | Create Stripe subscription checkout session |
| GET | `/subscription_checkouts/success` | Required | Handle successful checkout callback |
| GET | `/subscription_checkouts/cancel` | Required | Handle cancelled checkout callback |
| POST | `/webhooks/stripe` | Webhook sig | Handle Stripe webhook events |

## Routes Configuration

```ruby
# config/routes.rb (additions)
resource :subscription_checkouts, only: [:create] do
  get :success, on: :collection
  get :cancel, on: :collection
end

# Existing webhook route (no changes needed)
namespace :webhooks do
  post "stripe", to: "stripe#create"
end
```

---

## Endpoint: Create Subscription Checkout

**POST** `/subscription_checkouts`

Creates a Stripe Checkout Session in subscription mode and redirects user to Stripe.

### Request

**Headers**:
- `Content-Type: application/x-www-form-urlencoded` (Rails form submission)
- `X-CSRF-Token: <token>` (Rails CSRF protection)

**Parameters** (form data):
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `frequency` | string | Yes | Subscription frequency: `every_week`, `every_two_weeks`, `every_month`, `every_3_months` |

**Example Request** (from form submission):
```
POST /subscription_checkouts
Content-Type: application/x-www-form-urlencoded

frequency=every_month
```

### Response

**Success (302 Redirect)**:
Redirects to Stripe Checkout page.

```
HTTP/1.1 302 Found
Location: https://checkout.stripe.com/c/pay/cs_test_xxx
```

**Error - Not Authenticated (302 Redirect)**:
```
HTTP/1.1 302 Found
Location: /session/new
```
Flash: "Please sign in to set up a subscription"

**Error - Empty Cart (302 Redirect)**:
```
HTTP/1.1 302 Found
Location: /cart
```
Flash: "Your cart is empty"

**Error - Samples Only (302 Redirect)**:
```
HTTP/1.1 302 Found
Location: /cart
```
Flash: "Subscriptions are not available for sample orders"

**Error - Invalid Frequency (422)**:
```
HTTP/1.1 422 Unprocessable Entity
```
Flash: "Invalid subscription frequency"

### Controller Logic

```ruby
class SubscriptionCheckoutsController < ApplicationController
  before_action :require_authentication
  before_action :require_cart_with_items
  before_action :reject_samples_only_cart

  def create
    frequency = params[:frequency]

    unless Subscription.frequencies.key?(frequency)
      flash[:alert] = "Invalid subscription frequency"
      redirect_to cart_path and return
    end

    service = SubscriptionCheckoutService.new(
      cart: Current.cart,
      user: Current.user,
      frequency: frequency
    )

    session = service.create_checkout_session(
      success_url: success_subscription_checkouts_url,
      cancel_url: cancel_subscription_checkouts_url
    )

    redirect_to session.url, allow_other_host: true
  end
end
```

---

## Endpoint: Checkout Success Callback

**GET** `/subscription_checkouts/success`

Handles redirect from Stripe after successful subscription checkout.

### Request

**Query Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `session_id` | string | Yes | Stripe Checkout Session ID |

**Example**:
```
GET /subscription_checkouts/success?session_id=cs_test_xxx
```

### Response

**Success (302 Redirect)**:
```
HTTP/1.1 302 Found
Location: /orders/ORD-2024-0001
```
Flash: "Subscription created! Your first order has been placed."

**Error - Missing Session ID (302 Redirect)**:
```
HTTP/1.1 302 Found
Location: /cart
```
Flash: "Something went wrong. Please try again."

**Error - Session Not Found (302 Redirect)**:
```
HTTP/1.1 302 Found
Location: /cart
```
Flash: "Payment session not found. Please contact support."

### Controller Logic

```ruby
def success
  session_id = params[:session_id]

  unless session_id.present?
    flash[:alert] = "Something went wrong. Please try again."
    redirect_to cart_path and return
  end

  service = SubscriptionCheckoutService.new(
    cart: Current.cart,
    user: Current.user,
    frequency: nil  # Retrieved from session metadata
  )

  result = service.complete_checkout(session_id)

  if result.success?
    flash[:notice] = "Subscription created! Your first order has been placed."
    redirect_to order_path(result.order)
  else
    flash[:alert] = result.error_message
    redirect_to cart_path
  end
end
```

---

## Endpoint: Checkout Cancel Callback

**GET** `/subscription_checkouts/cancel`

Handles redirect from Stripe when user cancels checkout.

### Request

No parameters required.

### Response

**Always (302 Redirect)**:
```
HTTP/1.1 302 Found
Location: /cart
```
Flash: "Subscription checkout was cancelled. Your cart is still here."

### Controller Logic

```ruby
def cancel
  flash[:notice] = "Subscription checkout was cancelled. Your cart is still here."
  redirect_to cart_path
end
```

---

## Webhook: Stripe Events

**POST** `/webhooks/stripe`

Handles incoming Stripe webhook events. Extended for subscription events.

### Request

**Headers**:
- `Content-Type: application/json`
- `Stripe-Signature: <signature>` (Stripe webhook signature)

**Body**: Stripe Event JSON

### Subscription Events Handled

#### invoice.paid

Triggered when a subscription invoice is successfully paid.

**Payload** (relevant fields):
```json
{
  "type": "invoice.paid",
  "data": {
    "object": {
      "id": "in_xxx",
      "subscription": "sub_xxx",
      "billing_reason": "subscription_cycle",
      "amount_paid": 5760,
      "currency": "gbp",
      "customer": "cus_xxx",
      "lines": {
        "data": [
          {
            "quantity": 2,
            "price": {
              "unit_amount": 1600,
              "product": "prod_xxx"
            }
          }
        ]
      }
    }
  }
}
```

**Handler Logic**:
```ruby
def handle_invoice_paid(invoice)
  # Skip first invoice (handled by checkout success)
  return if invoice.billing_reason == "subscription_create"

  # Idempotency check
  return if Order.exists?(stripe_invoice_id: invoice.id)

  subscription = Subscription.find_by!(stripe_subscription_id: invoice.subscription)

  order = create_renewal_order(subscription, invoice)
  SubscriptionMailer.order_placed(order).deliver_later
end
```

#### customer.subscription.updated

Triggered when subscription status or details change.

**Payload** (relevant fields):
```json
{
  "type": "customer.subscription.updated",
  "data": {
    "object": {
      "id": "sub_xxx",
      "status": "active",
      "current_period_start": 1702648800,
      "current_period_end": 1705327200,
      "pause_collection": null
    },
    "previous_attributes": {
      "status": "past_due"
    }
  }
}
```

**Handler Logic**:
```ruby
def handle_subscription_updated(stripe_subscription)
  subscription = Subscription.find_by(stripe_subscription_id: stripe_subscription.id)
  return unless subscription

  subscription.update!(
    status: map_stripe_status(stripe_subscription.status, stripe_subscription.pause_collection),
    current_period_start: Time.at(stripe_subscription.current_period_start),
    current_period_end: Time.at(stripe_subscription.current_period_end)
  )
end

def map_stripe_status(stripe_status, pause_collection)
  return :paused if pause_collection.present?

  case stripe_status
  when "active" then :active
  when "canceled" then :cancelled
  when "past_due", "unpaid" then :active  # Still active, payment retrying
  else :active
  end
end
```

#### customer.subscription.deleted

Triggered when subscription is cancelled.

**Payload** (relevant fields):
```json
{
  "type": "customer.subscription.deleted",
  "data": {
    "object": {
      "id": "sub_xxx",
      "status": "canceled",
      "canceled_at": 1702734000
    }
  }
}
```

**Handler Logic**:
```ruby
def handle_subscription_deleted(stripe_subscription)
  subscription = Subscription.find_by(stripe_subscription_id: stripe_subscription.id)
  return unless subscription

  subscription.update!(
    status: :cancelled,
    cancelled_at: stripe_subscription.canceled_at ? Time.at(stripe_subscription.canceled_at) : Time.current
  )
end
```

#### invoice.payment_failed

Triggered when subscription payment fails.

**Handler Logic**:
```ruby
def handle_invoice_payment_failed(invoice)
  return unless invoice.subscription.present?

  subscription = Subscription.find_by(stripe_subscription_id: invoice.subscription)
  return unless subscription

  Rails.logger.warn("Subscription #{subscription.id} payment failed: invoice #{invoice.id}")
  # Status will be updated via customer.subscription.updated webhook
end
```

### Response

**Success**:
```
HTTP/1.1 200 OK
```

**Invalid Signature**:
```
HTTP/1.1 400 Bad Request
```

---

## Service: SubscriptionCheckoutService

### Interface

```ruby
class SubscriptionCheckoutService
  # Initialize with cart, user, and frequency
  def initialize(cart:, user:, frequency:)

  # Create Stripe Checkout Session
  # Returns: Stripe::Checkout::Session
  # Raises: Stripe::StripeError
  def create_checkout_session(success_url:, cancel_url:)

  # Complete checkout after success callback
  # Returns: Result object with .success?, .order, .error_message
  def complete_checkout(session_id)
end
```

### Stripe Session Parameters

```ruby
Stripe::Checkout::Session.create(
  mode: "subscription",
  customer: ensure_stripe_customer.id,
  line_items: build_line_items,
  success_url: "#{success_url}?session_id={CHECKOUT_SESSION_ID}",
  cancel_url: cancel_url,
  metadata: {
    user_id: user.id.to_s,
    frequency: frequency,
    cart_id: cart.id.to_s
  },
  subscription_data: {
    metadata: {
      user_id: user.id.to_s,
      frequency: frequency
    }
  },
  shipping_address_collection: {
    allowed_countries: ["GB"]
  },
  automatic_tax: { enabled: false },
  # Note: For UK VAT, we add tax as part of line item pricing
)
```

### Line Items Builder

```ruby
def build_line_items
  cart.cart_items.includes(product_variant: :product).map do |item|
    variant = item.product_variant
    {
      price_data: {
        currency: "gbp",
        product_data: {
          name: variant.display_name,
          description: "#{variant.pac_size} units per pack",
          metadata: {
            product_variant_id: variant.id.to_s,
            product_id: variant.product_id.to_s,
            sku: variant.sku
          }
        },
        unit_amount: (variant.price * 100).to_i,  # Convert to pence
        recurring: stripe_recurring_params
      },
      quantity: item.quantity
    }
  end
end

def stripe_recurring_params
  case frequency.to_sym
  when :every_week
    { interval: "week", interval_count: 1 }
  when :every_two_weeks
    { interval: "week", interval_count: 2 }
  when :every_month
    { interval: "month", interval_count: 1 }
  when :every_3_months
    { interval: "month", interval_count: 3 }
  end
end
```

---

## Mailer: SubscriptionMailer

### order_placed

Sends email notification when a renewal order is created.

**Template**: `app/views/subscription_mailer/order_placed.html.erb`

```ruby
class SubscriptionMailer < ApplicationMailer
  def order_placed(order)
    @order = order
    @subscription = order.subscription
    @user = order.user

    mail(
      to: @user.email_address,
      subject: "Your subscription order ##{@order.order_number} has been placed"
    )
  end
end
```

---

## Error Handling

### User-Facing Errors

| Scenario | Response | Flash Message |
|----------|----------|---------------|
| Not authenticated | Redirect to sign in | "Please sign in to set up a subscription" |
| Empty cart | Redirect to cart | "Your cart is empty" |
| Samples only | Redirect to cart | "Subscriptions are not available for sample orders" |
| Invalid frequency | Redirect to cart | "Invalid subscription frequency" |
| Stripe error | Redirect to cart | "Payment service error. Please try again." |
| Session not found | Redirect to cart | "Payment session not found. Please contact support." |

### Internal Errors (Logged)

| Scenario | Log Level | Action |
|----------|-----------|--------|
| Webhook signature invalid | WARN | Return 400 |
| Subscription not found (webhook) | WARN | Skip processing |
| Duplicate invoice (idempotency) | INFO | Skip processing |
| Stripe API error | ERROR | Re-raise for retry |

---

## Testing Contracts

### Controller Tests

```ruby
# test/controllers/subscription_checkouts_controller_test.rb

test "create requires authentication" do
  post subscription_checkouts_path, params: { frequency: "every_month" }
  assert_redirected_to new_session_path
end

test "create requires non-empty cart" do
  sign_in(users(:customer))
  Current.cart.cart_items.destroy_all

  post subscription_checkouts_path, params: { frequency: "every_month" }
  assert_redirected_to cart_path
  assert_match /empty/, flash[:alert]
end

test "create rejects samples-only cart" do
  sign_in(users(:customer))
  # Setup cart with only samples

  post subscription_checkouts_path, params: { frequency: "every_month" }
  assert_redirected_to cart_path
  assert_match /sample/, flash[:alert]
end

test "create redirects to Stripe on success" do
  sign_in(users(:customer))
  setup_cart_with_items

  Stripe::Checkout::Session.stubs(:create).returns(
    OpenStruct.new(url: "https://checkout.stripe.com/xxx")
  )

  post subscription_checkouts_path, params: { frequency: "every_month" }
  assert_redirected_to "https://checkout.stripe.com/xxx"
end
```

### Webhook Tests

```ruby
# test/controllers/webhooks/stripe_controller_test.rb

test "invoice.paid creates renewal order" do
  subscription = subscriptions(:active_subscription)

  event = build_stripe_event("invoice.paid", {
    id: "inv_new123",
    subscription: subscription.stripe_subscription_id,
    billing_reason: "subscription_cycle",
    amount_paid: 1200
  })

  assert_difference "Order.count", 1 do
    post webhooks_stripe_path,
      params: event.to_json,
      headers: stripe_signature_header(event)
  end

  assert_response :ok

  order = Order.last
  assert_equal subscription, order.subscription
  assert_equal "inv_new123", order.stripe_invoice_id
end

test "invoice.paid is idempotent" do
  subscription = subscriptions(:active_subscription)
  existing_order = orders(:renewal_order)

  event = build_stripe_event("invoice.paid", {
    id: existing_order.stripe_invoice_id,
    subscription: subscription.stripe_subscription_id,
    billing_reason: "subscription_cycle"
  })

  assert_no_difference "Order.count" do
    post webhooks_stripe_path,
      params: event.to_json,
      headers: stripe_signature_header(event)
  end

  assert_response :ok
end
```
