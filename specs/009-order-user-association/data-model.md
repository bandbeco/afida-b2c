# Data Model: Order User Association

**Feature**: 009-order-user-association
**Date**: 2025-11-26

## Summary

No database schema changes required. This document describes the existing data model that supports order-user association.

## Existing Entities

### User

**Table**: `users`
**Model**: `app/models/user.rb`

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | bigint | PK, auto | Primary key |
| email_address | string | NOT NULL, UNIQUE | User's email |
| password_digest | string | NOT NULL | Bcrypt password hash |
| organization_id | bigint | FK, NULL | Optional organization membership |
| role | enum | NULL | owner/admin/member (for org users) |
| created_at | datetime | NOT NULL | Record creation |
| updated_at | datetime | NOT NULL | Last update |

**Associations**:
```ruby
has_many :orders, dependent: :destroy
has_many :sessions, dependent: :destroy
has_many :carts, dependent: :destroy
belongs_to :organization, optional: true
```

---

### Order

**Table**: `orders`
**Model**: `app/models/order.rb`

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | bigint | PK, auto | Primary key |
| user_id | bigint | FK, NULL | **Order owner (key field)** |
| organization_id | bigint | FK, NULL | For B2B orders |
| placed_by_user_id | bigint | FK, NULL | User who placed B2B order |
| email | string | NOT NULL | Customer email |
| order_number | string | NOT NULL, UNIQUE | Display number (ORD-YYYY-NNNNNN) |
| stripe_session_id | string | NOT NULL, UNIQUE | Stripe checkout session |
| status | enum | NOT NULL | pending/paid/processing/shipped/delivered/cancelled/refunded |
| subtotal_amount | decimal | NOT NULL, >= 0 | Pre-tax subtotal |
| vat_amount | decimal | NOT NULL, >= 0 | VAT at 20% |
| shipping_amount | decimal | NOT NULL, >= 0 | Shipping cost |
| total_amount | decimal | NOT NULL, >= 0 | Final total |
| shipping_* | various | NOT NULL | Shipping address fields |
| created_at | datetime | NOT NULL | Order placement time |
| updated_at | datetime | NOT NULL | Last update |

**Key Association for This Feature**:
```ruby
belongs_to :user, optional: true  # NULL for guest orders
```

**Why `optional: true`**:
- Enables guest checkout (orders without user accounts)
- User can complete purchase without creating account
- Order is still valid and processed normally

---

## Entity Relationship Diagram

```
┌─────────────────────┐
│       User          │
├─────────────────────┤
│ id (PK)             │
│ email_address       │
│ ...                 │
└─────────┬───────────┘
          │
          │ 1:N (optional)
          │
          ▼
┌─────────────────────┐
│       Order         │
├─────────────────────┤
│ id (PK)             │
│ user_id (FK, NULL)  │◄─── KEY RELATIONSHIP
│ order_number        │
│ status              │
│ total_amount        │
│ ...                 │
└─────────────────────┘
```

## Authorization Logic

**Query Pattern for Authorized Access**:

```ruby
# Scoped lookup - only returns user's own orders
Current.user.orders.find(params[:id])

# Equivalent SQL:
# SELECT * FROM orders WHERE user_id = ? AND id = ?
```

**Why This Works**:
- `Current.user.orders` returns only orders belonging to current user
- `find(id)` within that scope ensures order belongs to user
- Raises `ActiveRecord::RecordNotFound` if order doesn't exist or belongs to another user
- No way to access orders with different `user_id` or `user_id = NULL`

## No Schema Migrations Required

The existing schema fully supports this feature:
- `user_id` column exists on `orders` table
- Foreign key relationship established
- Association configured in both models

All changes are controller/view level only.
