# Data Model: Sign-Up & Account Experience

**Feature Branch**: `001-sign-up-accounts`
**Date**: 2025-12-15

## Entity Overview

```
┌─────────────┐       ┌─────────────┐       ┌─────────────────────┐
│    User     │──────<│    Order    │       │    Subscription     │
│             │1    * │             │       │                     │
└─────────────┘       └─────────────┘       └─────────────────────┘
      │                     │                         │
      │                     │                         │
      │                    1│                        1│
      │                     │                         │
      └──────────────────── │ ────────────────────────┘
              1             │              *
                            │
                           *│
                    ┌───────┴───────┐
                    │  OrderItem    │
                    │               │
                    └───────────────┘
```

## Entities

### User (Existing - No Schema Changes)

The User model already supports all required fields for this feature.

**Relevant Existing Fields**:
- `id` - Primary key
- `email_address` - Unique email (normalized to lowercase)
- `password_digest` - bcrypt password hash
- `email_address_verified` - Boolean for email verification status
- `organization_id` - Optional B2B organization link
- `role` - Organization role (owner/admin/member)

**Existing Associations**:
- `has_many :orders`
- `has_many :sessions`
- `has_many :carts`

**New Association Required**:
- `has_many :subscriptions`

---

### Order (Existing - No Schema Changes)

The Order model already supports user association and all fields needed for reorder.

**Relevant Existing Fields**:
- `id` - Primary key
- `user_id` - Foreign key to User (nullable for guest orders)
- `email` - Customer email (always present)
- `order_number` - Human-readable order number
- `stripe_session_id` - Stripe Checkout session reference
- `status` - Order status enum
- `subtotal_amount`, `vat_amount`, `shipping_amount`, `total_amount`
- Shipping address fields

**Existing Associations**:
- `belongs_to :user, optional: true`
- `has_many :order_items`

**Key Methods for Reorder**:
- `order_items.includes(product_variant: :product)` - Load items with products

---

### OrderItem (Existing - No Schema Changes)

**Relevant Existing Fields**:
- `product_variant_id` - Link to product variant (can be nil if product deleted)
- `quantity` - Number of units/packs
- `price` - Price at time of order
- `product_name`, `product_sku` - Snapshot of product details

**Key Method**:
- `product_still_available?` - Checks if product exists and is active

---

### Subscription (NEW)

Represents a recurring order configuration linked to a Stripe Subscription.

**Fields**:

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | bigint | PK | Primary key |
| `user_id` | bigint | NOT NULL, FK | Owner of subscription |
| `stripe_subscription_id` | string | NOT NULL, UNIQUE | Stripe subscription ID (sub_xxx) |
| `stripe_customer_id` | string | NOT NULL | Stripe customer ID (cus_xxx) |
| `stripe_price_id` | string | NOT NULL | Stripe price ID for recurring charge |
| `frequency` | string | NOT NULL | Enum: weekly, biweekly, monthly |
| `status` | string | NOT NULL, DEFAULT 'active' | Enum: active, paused, cancelled |
| `current_period_start` | datetime | | Current billing period start |
| `current_period_end` | datetime | | Current billing period end (next charge) |
| `cancelled_at` | datetime | | When subscription was cancelled |
| `items_snapshot` | jsonb | NOT NULL | Snapshot of items at creation |
| `shipping_snapshot` | jsonb | NOT NULL | Snapshot of shipping address |
| `created_at` | datetime | NOT NULL | |
| `updated_at` | datetime | NOT NULL | |

**Associations**:
- `belongs_to :user`
- `has_many :orders` (orders created by this subscription)

**Indexes**:
- `user_id` - For user's subscriptions list
- `stripe_subscription_id` - Unique, for webhook lookups
- `status` - For filtering active subscriptions

**Items Snapshot Structure**:
```json
{
  "items": [
    {
      "product_variant_id": 123,
      "product_name": "Single Wall Cup 8oz",
      "product_sku": "SWC-8OZ",
      "quantity": 2,
      "price": "16.00"
    }
  ],
  "subtotal": "32.00",
  "vat": "6.40",
  "shipping": "0.00",
  "total": "38.40"
}
```

**Shipping Snapshot Structure**:
```json
{
  "name": "John Smith",
  "line1": "123 Business St",
  "line2": null,
  "city": "London",
  "postal_code": "EC1A 1BB",
  "country": "GB"
}
```

**Status Enum**:
| Status | Description |
|--------|-------------|
| `active` | Subscription is active, will bill on schedule |
| `paused` | Temporarily paused (payment failed, awaiting retry) |
| `cancelled` | User cancelled, no future billing |

**Frequency Enum**:
| Frequency | Stripe Interval | Description |
|-----------|-----------------|-------------|
| `weekly` | `interval: 'week'` | Every 7 days |
| `biweekly` | `interval: 'week', interval_count: 2` | Every 14 days |
| `monthly` | `interval: 'month'` | Every month on same date |

---

## Migration

### Create Subscriptions Table

```ruby
class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :stripe_subscription_id, null: false
      t.string :stripe_customer_id, null: false
      t.string :stripe_price_id, null: false
      t.string :frequency, null: false
      t.string :status, null: false, default: 'active'
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.datetime :cancelled_at
      t.jsonb :items_snapshot, null: false, default: {}
      t.jsonb :shipping_snapshot, null: false, default: {}

      t.timestamps
    end

    add_index :subscriptions, :stripe_subscription_id, unique: true
    add_index :subscriptions, :status
  end
end
```

### Add Subscription Reference to Orders

```ruby
class AddSubscriptionToOrders < ActiveRecord::Migration[8.0]
  def change
    add_reference :orders, :subscription, null: true, foreign_key: true
  end
end
```

---

## Validation Rules

### Subscription

| Field | Rule | Error Message |
|-------|------|---------------|
| `user_id` | presence | "must have a user" |
| `stripe_subscription_id` | presence, uniqueness | "is required", "already exists" |
| `stripe_customer_id` | presence | "is required" |
| `stripe_price_id` | presence | "is required" |
| `frequency` | inclusion in [weekly, biweekly, monthly] | "is not a valid frequency" |
| `status` | inclusion in [active, paused, cancelled] | "is not a valid status" |
| `items_snapshot` | presence | "must have items" |
| `shipping_snapshot` | presence | "must have shipping address" |

---

## State Transitions

### Subscription Status

```
                    ┌──────────────────────────────────┐
                    │                                  │
                    ▼                                  │
    ┌─────────┐  create  ┌────────┐  payment_failed  ┌────────┐
    │  (new)  │─────────>│ active │────────────────>│ paused │
    └─────────┘          └────────┘                  └────────┘
                              │                          │
                              │ user_cancels             │ payment_succeeded
                              │                          │
                              ▼                          │
                         ┌───────────┐                   │
                         │ cancelled │<──────────────────┘
                         └───────────┘   user_cancels
```

**Transition Triggers**:
- `active → paused`: Stripe webhook `invoice.payment_failed`
- `paused → active`: Stripe webhook `invoice.payment_succeeded`
- `active → cancelled`: User clicks "Cancel" or Stripe webhook `customer.subscription.deleted`
- `paused → cancelled`: User clicks "Cancel" or too many payment failures

---

## Queries

### Common Access Patterns

```ruby
# User's active subscriptions
user.subscriptions.where(status: 'active')

# Orders created by a subscription
subscription.orders.order(created_at: :desc)

# Order history with reorder context
user.orders.includes(order_items: { product_variant: :product })
           .order(created_at: :desc)
           .limit(20)

# Check if subscription order
order.subscription_id.present?
```

---

## Data Integrity

### Referential Integrity

- `subscriptions.user_id` → `users.id` (CASCADE on delete - user deleted = subscriptions deleted)
- `orders.subscription_id` → `subscriptions.id` (SET NULL on delete - subscription deleted = orders remain)

### Unique Constraints

- `subscriptions.stripe_subscription_id` - One local record per Stripe subscription
- `orders.stripe_session_id` - Existing constraint, unchanged

### Null Safety

- Guest orders: `orders.user_id` nullable (existing behavior)
- Subscription orders: `orders.subscription_id` nullable (most orders aren't from subscriptions)
- Products can be deleted: `order_items.product_variant_id` nullable (existing behavior)
