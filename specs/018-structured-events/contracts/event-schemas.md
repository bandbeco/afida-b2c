# Event Schemas: Structured Events Infrastructure

**Feature**: 018-structured-events
**Date**: 2026-01-16

## Overview

This document defines the schema for each event type. All events follow the base structure and add domain-specific payload fields.

## Base Event Structure

Every event contains:

```ruby
{
  name: String,                    # "domain.action" format
  payload: Hash,                   # Event-specific data (see below)
  context: {                       # Set by EventContext concern
    request_id: String,            # Rails request UUID
    user_id: Integer | nil,        # Current.user&.id
    session_id: Integer | nil      # Current.session&.id
  },
  tags: Hash,                      # Optional domain tags
  timestamp: Integer,              # Nanoseconds since epoch
  source_location: {
    filepath: String,              # e.g., "app/controllers/checkouts_controller.rb"
    lineno: Integer,               # Line number
    label: String                  # Method name
  }
}
```

---

## Customer Journey Events

### `email_signup.completed`

Emitted when a user submits the email signup form.

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `email` | String | Yes | Subscriber's email address |
| `source` | String | Yes | Where signup occurred (e.g., "cart", "footer") |
| `discount_eligible` | Boolean | Yes | Whether eligible for first-order discount |

**Example**:
```ruby
Rails.event.notify("email_signup.completed",
  email: "customer@example.com",
  source: "cart",
  discount_eligible: true
)
```

---

### `email_signup.discount_claimed`

Emitted when a subscriber uses their first-order discount at checkout.

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `email` | String | Yes | Subscriber's email address |
| `order_id` | Integer | Yes | Order that used the discount |
| `discount_amount` | Decimal | Yes | Discount value applied |

**Example**:
```ruby
Rails.event.notify("email_signup.discount_claimed",
  email: "customer@example.com",
  order_id: 123,
  discount_amount: 5.00
)
```

---

### `cart.item_added`

Emitted when a product is added to the cart.

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `product_id` | Integer | Yes | Product ID |
| `product_sku` | String | Yes | Product SKU |
| `quantity` | Integer | Yes | Quantity added |
| `is_sample` | Boolean | Yes | Whether this is a free sample |

**Example**:
```ruby
Rails.event.notify("cart.item_added",
  product_id: 42,
  product_sku: "CUP-8OZ-SW",
  quantity: 2,
  is_sample: false
)
```

---

### `cart.item_removed`

Emitted when a product is removed from the cart.

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `product_id` | Integer | Yes | Product ID |
| `product_sku` | String | Yes | Product SKU |

**Example**:
```ruby
Rails.event.notify("cart.item_removed",
  product_id: 42,
  product_sku: "CUP-8OZ-SW"
)
```

---

### `checkout.started`

Emitted when user initiates checkout (redirects to Stripe).

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `cart_id` | Integer | Yes | Cart ID |
| `item_count` | Integer | Yes | Number of items in cart |
| `subtotal` | Decimal | Yes | Cart subtotal (before VAT/shipping) |

**Example**:
```ruby
Rails.event.notify("checkout.started",
  cart_id: 789,
  item_count: 3,
  subtotal: 45.00
)
```

---

### `checkout.completed`

Emitted when Stripe redirects back with successful payment.

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `order_id` | Integer | Yes | Created order ID |
| `total` | Decimal | Yes | Order total (including VAT/shipping) |
| `payment_method` | String | Yes | Payment method type (e.g., "card") |

**Example**:
```ruby
Rails.event.notify("checkout.completed",
  order_id: 456,
  total: 59.40,
  payment_method: "card"
)
```

---

### `order.placed`

Emitted when order record is created (after successful payment).

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `order_id` | Integer | Yes | Order ID |
| `email` | String | Yes | Customer email |
| `total` | Decimal | Yes | Order total |
| `item_count` | Integer | Yes | Number of line items |
| `has_discount` | Boolean | Yes | Whether discount was applied |
| `source` | String | Yes | "checkout" or "webhook" |

**Example**:
```ruby
Rails.event.notify("order.placed",
  order_id: 456,
  email: "customer@example.com",
  total: 59.40,
  item_count: 3,
  has_discount: true,
  source: "checkout"
)
```

---

### `samples.requested`

Emitted when a sample-only order is placed (free samples, no payment).

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `order_id` | Integer | Yes | Order ID |
| `email` | String | Yes | Customer email |
| `sample_count` | Integer | Yes | Number of samples |

**Example**:
```ruby
Rails.event.notify("samples.requested",
  order_id: 457,
  email: "customer@example.com",
  sample_count: 3
)
```

---

## Operational Events

### `webhook.received`

Emitted when a Stripe webhook is received (before processing).

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `event_type` | String | Yes | Stripe event type (e.g., "checkout.session.completed") |
| `stripe_event_id` | String | Yes | Stripe event ID (e.g., "evt_...") |

**Example**:
```ruby
Rails.event.notify("webhook.received",
  event_type: "checkout.session.completed",
  stripe_event_id: "evt_1ABC123"
)
```

---

### `webhook.processed`

Emitted when a Stripe webhook is processed successfully.

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `event_type` | String | Yes | Stripe event type |
| `stripe_event_id` | String | Yes | Stripe event ID |
| `order_id` | Integer | No | Order ID if order was created/updated |

**Example**:
```ruby
Rails.event.notify("webhook.processed",
  event_type: "checkout.session.completed",
  stripe_event_id: "evt_1ABC123",
  order_id: 456
)
```

---

### `webhook.failed`

Emitted when webhook processing encounters an error.

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `event_type` | String | Yes | Stripe event type |
| `stripe_event_id` | String | Yes | Stripe event ID |
| `error` | String | Yes | Error message |

**Example**:
```ruby
Rails.event.notify("webhook.failed",
  event_type: "checkout.session.completed",
  stripe_event_id: "evt_1ABC123",
  error: "Cart not found"
)
```

---

### `payment.succeeded`

Emitted when Stripe confirms payment success.

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `order_id` | Integer | Yes | Order ID |
| `amount` | Decimal | Yes | Payment amount |
| `payment_intent_id` | String | Yes | Stripe PaymentIntent ID |

**Example**:
```ruby
Rails.event.notify("payment.succeeded",
  order_id: 456,
  amount: 59.40,
  payment_intent_id: "pi_1ABC123"
)
```

---

### `payment.failed`

Emitted when a payment attempt fails.

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `email` | String | Yes | Customer email |
| `amount` | Decimal | Yes | Attempted amount |
| `error_code` | String | Yes | Stripe error code |
| `decline_reason` | String | No | Human-readable decline reason |

**Example**:
```ruby
Rails.event.notify("payment.failed",
  email: "customer@example.com",
  amount: 59.40,
  error_code: "card_declined",
  decline_reason: "insufficient_funds"
)
```

---

### `payment.refunded`

Emitted when a refund is processed.

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `order_id` | Integer | Yes | Order ID |
| `amount` | Decimal | Yes | Refund amount |
| `reason` | String | No | Refund reason |

**Example**:
```ruby
Rails.event.notify("payment.refunded",
  order_id: 456,
  amount: 59.40,
  reason: "customer_request"
)
```

---

### `order.fulfilled`

Emitted when an order is shipped.

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `order_id` | Integer | Yes | Order ID |
| `tracking_number` | String | No | Shipping tracking number |

**Example**:
```ruby
Rails.event.notify("order.fulfilled",
  order_id: 456,
  tracking_number: "1Z999AA10123456784"
)
```

---

### `order.cancelled`

Emitted when an order is cancelled.

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `order_id` | Integer | Yes | Order ID |
| `reason` | String | Yes | Cancellation reason |
| `refund_issued` | Boolean | Yes | Whether refund was issued |

**Example**:
```ruby
Rails.event.notify("order.cancelled",
  order_id: 456,
  reason: "customer_request",
  refund_issued: true
)
```

---

## Scheduled Reorder Events

### `reorder.scheduled`

Emitted when a customer creates a reorder schedule.

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schedule_id` | Integer | Yes | ReorderSchedule ID |
| `frequency` | String | Yes | Frequency enum value |
| `item_count` | Integer | Yes | Number of items in schedule |

**Example**:
```ruby
Rails.event.notify("reorder.scheduled",
  schedule_id: 12,
  frequency: "every_month",
  item_count: 5
)
```

---

### `reorder.confirmed`

Emitted when a customer confirms a pending order.

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `order_id` | Integer | Yes | Created order ID |
| `schedule_id` | Integer | Yes | ReorderSchedule ID |
| `total` | Decimal | Yes | Order total |

**Example**:
```ruby
Rails.event.notify("reorder.confirmed",
  order_id: 789,
  schedule_id: 12,
  total: 125.00
)
```

---

### `reorder.charge_failed`

Emitted when a scheduled payment fails.

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schedule_id` | Integer | Yes | ReorderSchedule ID |
| `email` | String | Yes | Customer email |
| `error_code` | String | Yes | Stripe error code |

**Example**:
```ruby
Rails.event.notify("reorder.charge_failed",
  schedule_id: 12,
  email: "customer@example.com",
  error_code: "card_declined"
)
```

---

### `pending_order.created`

Emitted when the job creates a pending order (3 days before charge).

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `pending_order_id` | Integer | Yes | PendingOrder ID |
| `schedule_id` | Integer | Yes | ReorderSchedule ID |
| `total` | Decimal | Yes | Pending order total |

**Example**:
```ruby
Rails.event.notify("pending_order.created",
  pending_order_id: 45,
  schedule_id: 12,
  total: 125.00
)
```

---

### `pending_order.reminder_sent`

Emitted when a reminder email is sent for a pending order.

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `pending_order_id` | Integer | Yes | PendingOrder ID |
| `email` | String | Yes | Customer email |

**Example**:
```ruby
Rails.event.notify("pending_order.reminder_sent",
  pending_order_id: 45,
  email: "customer@example.com"
)
```

---

### `pending_order.expired`

Emitted when a pending order expires without confirmation.

**Payload**:
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `pending_order_id` | Integer | Yes | PendingOrder ID |
| `schedule_id` | Integer | Yes | ReorderSchedule ID |

**Example**:
```ruby
Rails.event.notify("pending_order.expired",
  pending_order_id: 45,
  schedule_id: 12
)
```
