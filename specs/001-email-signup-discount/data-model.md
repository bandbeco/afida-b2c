# Data Model: Email Signup Discount

**Feature**: 001-email-signup-discount
**Date**: 2026-01-16

## Entities

### EmailSubscription

Represents a visitor who has signed up for the email list, optionally with a discount claim.

#### Fields

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | bigint | PK, auto | Primary key |
| `email` | string | NOT NULL, UNIQUE | Subscriber's email address (normalized to lowercase) |
| `discount_claimed_at` | datetime | NULL | Timestamp when discount was claimed (null if subscribed without claiming) |
| `source` | string | NOT NULL, DEFAULT 'cart_discount' | Where signup occurred: `cart_discount`, `footer`, etc. |
| `created_at` | datetime | NOT NULL | Record creation timestamp |
| `updated_at` | datetime | NOT NULL | Record update timestamp |

#### Indexes

| Index | Columns | Type | Purpose |
|-------|---------|------|---------|
| `index_email_subscriptions_on_email` | `email` | UNIQUE | Fast lookup, prevent duplicates |

#### Validations

| Field | Validation | Error Message |
|-------|------------|---------------|
| `email` | presence | "can't be blank" |
| `email` | uniqueness (case-insensitive) | "has already been taken" |
| `email` | format (URI::MailTo::EMAIL_REGEXP) | "is invalid" |
| `source` | presence | "can't be blank" |

#### Normalization

| Field | Transformation |
|-------|----------------|
| `email` | `strip.downcase` before save |

#### Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `eligible_for_discount?` | `self.eligible_for_discount?(email) -> Boolean` | Class method. Returns true if email has not subscribed AND has no orders |

## Relationships

```
EmailSubscription
    └── (none - standalone entity)

Order (existing)
    └── email field used for eligibility check
```

**Cross-Entity Query**: Eligibility check queries both `email_subscriptions` and `orders` tables by email.

## State Transitions

EmailSubscription has no explicit status field. States are implicit:

| State | Condition | Meaning |
|-------|-----------|---------|
| Subscribed only | `discount_claimed_at IS NULL` | Signed up but didn't claim discount |
| Discount claimed | `discount_claimed_at IS NOT NULL` | Signed up and claimed discount |

## Migration

```ruby
class CreateEmailSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :email_subscriptions do |t|
      t.string :email, null: false
      t.datetime :discount_claimed_at
      t.string :source, null: false, default: "cart_discount"

      t.timestamps
    end

    add_index :email_subscriptions, :email, unique: true
  end
end
```

## Fixtures

```yaml
# test/fixtures/email_subscriptions.yml

claimed_discount:
  email: "claimed@example.com"
  discount_claimed_at: <%= 1.day.ago %>
  source: "cart_discount"

subscribed_only:
  email: "subscribed@example.com"
  discount_claimed_at: null
  source: "footer"
```
