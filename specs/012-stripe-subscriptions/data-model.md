# Data Model: Stripe Subscription Checkout

**Feature Branch**: `012-stripe-subscriptions`
**Phase**: 1 - Design
**Date**: 2025-12-15

## Overview

This feature builds on the existing `Subscription` model and `Order` model. The primary changes are:
1. Add `stripe_invoice_id` to orders for webhook idempotency
2. Document the existing data model relationships and snapshot structures

## Entity Relationship Diagram

```
┌──────────────┐         ┌──────────────────┐         ┌─────────────┐
│    User      │ 1────n  │   Subscription   │ 1────n  │    Order    │
├──────────────┤         ├──────────────────┤         ├─────────────┤
│ id           │         │ id               │         │ id          │
│ email_address│         │ user_id (FK)     │         │ user_id     │
│ first_name   │         │ stripe_sub_id    │←────────│ sub_id (FK) │
│ last_name    │         │ stripe_cust_id   │         │ stripe_     │
│              │         │ stripe_price_id  │         │   session_id│
└──────────────┘         │ status           │         │ stripe_     │
                         │ frequency        │         │   invoice_id│ ← NEW
                         │ items_snapshot   │         │ total_amount│
                         │ shipping_snapshot│         └─────────────┘
                         │ current_period_  │                │
                         │   start/end      │                │ 1
                         │ cancelled_at     │                │
                         └──────────────────┘                n
                                                      ┌─────────────┐
                                                      │ OrderItem   │
                                                      ├─────────────┤
                                                      │ id          │
                                                      │ order_id    │
                                                      │ product_    │
                                                      │   variant_id│
                                                      │ quantity    │
                                                      │ price       │
                                                      │ pac_size    │
                                                      └─────────────┘
```

## Schema Changes

### Migration: Add stripe_invoice_id to Orders

**File**: `db/migrate/YYYYMMDDHHMMSS_add_stripe_invoice_id_to_orders.rb`

```ruby
class AddStripeInvoiceIdToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :stripe_invoice_id, :string
    add_index :orders, :stripe_invoice_id, unique: true, where: "stripe_invoice_id IS NOT NULL"
  end
end
```

**Rationale**:
- `stripe_invoice_id` is nullable (one-time orders don't have invoice IDs)
- Unique constraint with `WHERE` clause allows multiple NULLs
- Used for idempotency check in webhook handler: prevents duplicate renewal orders

## Existing Models (No Changes)

### Subscription Model

**Table**: `subscriptions`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | bigint | PK | Primary key |
| `user_id` | bigint | FK, NOT NULL | Owner of subscription |
| `stripe_subscription_id` | string | UNIQUE, NOT NULL | Stripe's subscription ID |
| `stripe_customer_id` | string | NOT NULL | Stripe customer (copied from user) |
| `stripe_price_id` | string | NOT NULL | Stripe price ID (archived ad-hoc) |
| `status` | integer | NOT NULL, DEFAULT 0 | Enum: active=0, paused=1, cancelled=2 |
| `frequency` | integer | NOT NULL | Enum: weekly=0, biweekly=1, monthly=2, quarterly=3 |
| `items_snapshot` | jsonb | NOT NULL, DEFAULT {} | Cart items at subscription time |
| `shipping_snapshot` | jsonb | NOT NULL, DEFAULT {} | Shipping details |
| `current_period_start` | datetime | | Current billing period start |
| `current_period_end` | datetime | | Next billing date |
| `cancelled_at` | datetime | | When subscription was cancelled |
| `created_at` | datetime | NOT NULL | |
| `updated_at` | datetime | NOT NULL | |

**Indexes**:
- `index_subscriptions_on_stripe_subscription_id` (unique)
- `index_subscriptions_on_user_id`
- `index_subscriptions_on_status`

### Order Model (Existing + New Column)

**Table**: `orders`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | bigint | PK | Primary key |
| `user_id` | bigint | FK | Order owner (nullable for guests) |
| `subscription_id` | bigint | FK | Parent subscription (nullable) |
| `stripe_session_id` | string | UNIQUE, NOT NULL | Checkout session ID |
| `stripe_invoice_id` | string | UNIQUE (nullable) | **NEW**: Invoice ID for renewals |
| `order_number` | string | UNIQUE, NOT NULL | Human-readable order number |
| `status` | string | NOT NULL | Order status |
| `subtotal_amount` | decimal | NOT NULL | Pre-VAT total |
| `vat_amount` | decimal | NOT NULL | VAT amount |
| `total_amount` | decimal | NOT NULL | Grand total |
| `email` | string | NOT NULL | Customer email |
| `shipping_*` | various | | Shipping address fields |
| `created_at` | datetime | NOT NULL | |
| `updated_at` | datetime | NOT NULL | |

**New Index**:
- `index_orders_on_stripe_invoice_id` (unique, where not null)

## JSONB Snapshot Structures

### items_snapshot

Captures cart state at subscription creation. Used for renewal order creation.

```json
{
  "items": [
    {
      "product_variant_id": 123,
      "product_id": 45,
      "sku": "SWHC-8OZ",
      "name": "Single Wall Hot Cup - 8oz",
      "quantity": 2,
      "unit_price_minor": 1600,
      "pac_size": 500,
      "total_minor": 3200
    },
    {
      "product_variant_id": 456,
      "product_id": 78,
      "sku": "LID-8OZ",
      "name": "White Lid - 8oz",
      "quantity": 2,
      "unit_price_minor": 800,
      "pac_size": 500,
      "total_minor": 1600
    }
  ],
  "subtotal_minor": 4800,
  "vat_minor": 960,
  "total_minor": 5760,
  "currency": "gbp"
}
```

**Field Descriptions**:
- `product_variant_id`: FK reference (for display/linking, not price lookup)
- `product_id`: FK reference (for category/product page links)
- `sku`: SKU for fulfillment
- `name`: Display name at subscription time
- `quantity`: Number of packs/units
- `unit_price_minor`: Price per unit in pence (captured at subscription time)
- `pac_size`: Units per pack (for display)
- `total_minor`: Line item total in pence
- `subtotal_minor`: Sum of line totals
- `vat_minor`: VAT amount (20%)
- `total_minor`: Grand total including VAT
- `currency`: Currency code (always "gbp")

### shipping_snapshot

Captures shipping selection at subscription creation.

```json
{
  "method": "standard",
  "cost_minor": 795,
  "name": "Standard Delivery",
  "address": {
    "line1": "123 Business Park",
    "line2": "Suite 100",
    "city": "London",
    "postal_code": "E1 6AN",
    "country": "GB"
  },
  "recipient_name": "John Smith",
  "company": "Acme Catering Ltd"
}
```

## Model Associations

### Subscription

```ruby
class Subscription < ApplicationRecord
  belongs_to :user
  has_many :orders, dependent: :nullify

  # Existing enums
  enum :frequency, [:every_week, :every_two_weeks, :every_month, :every_3_months]
  enum :status, [:active, :paused, :cancelled], default: :active
end
```

### Order (updated)

```ruby
class Order < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :subscription, optional: true  # Existing
  has_many :order_items, dependent: :destroy

  # Add validation for invoice idempotency
  validates :stripe_invoice_id, uniqueness: true, allow_nil: true

  # Helper for renewal orders
  def renewal_order?
    subscription_id.present? && stripe_invoice_id.present?
  end
end
```

### User (context)

```ruby
class User < ApplicationRecord
  has_many :subscriptions, dependent: :destroy
  has_many :orders

  # May need stripe_customer_id if not already present
  # (Check: already exists in current schema)
end
```

## Data Flow

### Subscription Creation Flow

```
Cart Items → items_snapshot (JSONB)
           ↓
Stripe Checkout Session (mode: "subscription")
           ↓
checkout.session.completed webhook
           ↓
Create Subscription record with:
  - stripe_subscription_id from session
  - stripe_customer_id from session
  - stripe_price_id from session (archived ad-hoc price)
  - items_snapshot from cart
  - shipping_snapshot from session
  - frequency from user selection
  - current_period_start/end from subscription
           ↓
Create first Order with:
  - subscription_id = new subscription
  - stripe_session_id from checkout
  - stripe_invoice_id = NULL (first order via checkout, not invoice)
  - items from cart (direct, not snapshot)
```

### Renewal Order Flow

```
invoice.paid webhook (billing_reason: "subscription_cycle")
           ↓
Look up Subscription by invoice.subscription
           ↓
Idempotency check: Order.exists?(stripe_invoice_id: invoice.id)?
           ↓ (if not exists)
Create Order from subscription.items_snapshot:
  - subscription_id = subscription.id
  - stripe_session_id = generated placeholder (e.g., "renewal_#{invoice.id}")
  - stripe_invoice_id = invoice.id (for idempotency)
  - items from items_snapshot
```

## Validation Rules

### Subscription

| Field | Validation | Error Message |
|-------|------------|---------------|
| `user_id` | presence | "must belong to a user" |
| `stripe_subscription_id` | presence, uniqueness | "is required", "has already been taken" |
| `stripe_customer_id` | presence | "is required" |
| `stripe_price_id` | presence | "is required" |
| `frequency` | presence, inclusion | "is required", "is not valid" |
| `status` | presence | "is required" |
| `items_snapshot` | presence | "is required" |
| `shipping_snapshot` | presence | "is required" |

### Order (new validation)

| Field | Validation | Error Message |
|-------|------------|---------------|
| `stripe_invoice_id` | uniqueness (allow nil) | "has already been taken" |

## Query Patterns

### Find subscription by Stripe ID (webhook lookup)

```ruby
Subscription.find_by!(stripe_subscription_id: stripe_sub_id)
```

### Check for existing renewal order (idempotency)

```ruby
Order.exists?(stripe_invoice_id: invoice_id)
```

### Get user's active subscriptions

```ruby
user.subscriptions.active_subscriptions
# OR
Subscription.where(user: user, status: :active)
```

### Get orders for a subscription

```ruby
subscription.orders.order(created_at: :desc)
```

## Testing Considerations

### Fixtures/Factories

**Subscription fixture**:
```yaml
active_subscription:
  user: customer_one
  stripe_subscription_id: "sub_test123"
  stripe_customer_id: "cus_test123"
  stripe_price_id: "price_test123"
  frequency: 2  # every_month
  status: 0     # active
  items_snapshot: '{"items":[{"product_variant_id":1,"name":"Test Product","quantity":1,"unit_price_minor":1000,"pac_size":100}],"subtotal_minor":1000,"vat_minor":200,"total_minor":1200}'
  shipping_snapshot: '{"method":"standard","cost_minor":795}'
  current_period_start: <%= 1.month.ago.to_fs(:db) %>
  current_period_end: <%= 1.day.from_now.to_fs(:db) %>
```

**Renewal order fixture**:
```yaml
renewal_order:
  user: customer_one
  subscription: active_subscription
  stripe_session_id: "renewal_inv_test456"
  stripe_invoice_id: "inv_test456"
  order_number: "ORD-2024-0002"
  status: "completed"
  email: "customer@example.com"
  subtotal_amount: 10.00
  vat_amount: 2.00
  total_amount: 12.00
```

## Migration Checklist

- [ ] Create migration for `stripe_invoice_id` column
- [ ] Add unique index with WHERE clause for nullable uniqueness
- [ ] Run migration in development/test
- [ ] Verify existing orders unaffected (all have NULL invoice_id)
- [ ] Add model validation for uniqueness
