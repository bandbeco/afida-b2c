# Data Model: User Address Storage

**Feature**: 001-user-address-storage
**Date**: 2025-12-17

## Entity Overview

```
┌─────────────┐       ┌─────────────┐
│    User     │ 1───* │   Address   │
│             │       │             │
│ - id        │       │ - id        │
│ - email     │       │ - user_id   │
│ - ...       │       │ - nickname  │
└─────────────┘       │ - recipient │
                      │ - company   │
                      │ - line1     │
                      │ - line2     │
                      │ - city      │
                      │ - postcode  │
                      │ - phone     │
                      │ - country   │
                      │ - default   │
                      └─────────────┘
```

## Entities

### Address

A delivery location saved by a user for reuse during checkout.

#### Attributes

| Attribute | Type | Constraints | Description |
|-----------|------|-------------|-------------|
| id | bigint | PK, auto-increment | Unique identifier |
| user_id | bigint | FK(users), NOT NULL, indexed | Owning user |
| nickname | string(50) | NOT NULL | User-friendly identifier ("Office", "Home") |
| recipient_name | string(100) | NOT NULL | Name of person receiving delivery |
| company_name | string(100) | NULL | Business name for B2B deliveries |
| line1 | string(200) | NOT NULL | Street address |
| line2 | string(100) | NULL | Apt, suite, unit, floor |
| city | string(100) | NOT NULL | City/town |
| postcode | string(20) | NOT NULL | UK postcode |
| phone | string(30) | NULL | Contact number for courier |
| country | string(2) | NOT NULL, default "GB" | ISO country code (UK only) |
| default | boolean | NOT NULL, default false | Is this the user's default address? |
| created_at | datetime | NOT NULL | Creation timestamp |
| updated_at | datetime | NOT NULL | Last update timestamp |

#### Indexes

| Index | Columns | Type | Purpose |
|-------|---------|------|---------|
| idx_addresses_user_id | user_id | B-tree | User's addresses lookup |
| idx_addresses_user_default | user_id, default | B-tree, partial (WHERE default = true) | Fast default address lookup |

#### Validations

| Rule | Attributes | Error Message |
|------|------------|---------------|
| Presence | nickname, recipient_name, line1, city, postcode, country | "[field] can't be blank" |
| Length | nickname (max 50), recipient_name (max 100), line1 (max 200) | "[field] is too long" |
| Format | postcode | "is not a valid UK postcode" (optional validation) |
| Uniqueness | (user_id, default) WHERE default = true | "User can only have one default address" (enforced by callback) |

#### Callbacks

| Event | Action | Purpose |
|-------|--------|---------|
| before_save | ensure_single_default | If setting default=true, unset any existing default for this user |
| after_destroy | assign_new_default | If deleted address was default, make oldest remaining address the default |

#### Scopes

| Scope | Query | Usage |
|-------|-------|-------|
| default_first | `order(default: :desc, created_at: :asc)` | Display addresses with default at top |

### User (Extended)

Existing User model extended with address association.

#### New Associations

| Association | Type | Options |
|-------------|------|---------|
| addresses | has_many | dependent: :destroy |

#### New Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| default_address | Address \| nil | Returns default address or first address if no default |
| has_saved_addresses? | boolean | Returns true if user has any saved addresses |

## Relationships

### User → Address

- **Cardinality**: One-to-Many (1:*)
- **Direction**: User has many Addresses, Address belongs to User
- **Cascade**: Delete user → Delete all addresses
- **Business Rules**:
  - User can have 0 or more addresses
  - At most one address per user can have `default = true`
  - If user has addresses but none is default, `default_address` returns the oldest

## Migration

```ruby
class CreateAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :addresses do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :nickname, null: false, limit: 50
      t.string :recipient_name, null: false, limit: 100
      t.string :company_name, limit: 100
      t.string :line1, null: false, limit: 200
      t.string :line2, limit: 100
      t.string :city, null: false, limit: 100
      t.string :postcode, null: false, limit: 20
      t.string :phone, limit: 30
      t.string :country, null: false, limit: 2, default: "GB"
      t.boolean :default, null: false, default: false

      t.timestamps
    end

    # Partial index for fast default address lookup
    add_index :addresses, [:user_id, :default],
              where: "\"default\" = true",
              name: "idx_addresses_user_default"
  end
end
```

## State Diagram

Address has no explicit state machine. The `default` flag is the only state-like attribute:

```
┌─────────────────┐
│  Non-Default    │ ←──────────────────┐
│  (default=false)│                    │
└────────┬────────┘                    │
         │                             │
         │ set_default                 │
         ↓                             │
┌─────────────────┐                    │
│    Default      │ ───────────────────┘
│  (default=true) │   another address
└─────────────────┘   set as default
```

## Query Patterns

### Common Queries

```ruby
# Get user's addresses (default first)
user.addresses.default_first

# Get user's default address
user.default_address
# OR
user.addresses.find_by(default: true)

# Check if user has saved addresses
user.has_saved_addresses?
# OR
user.addresses.exists?

# Check if address matches order (for save prompt)
user.addresses.exists?(line1: order.shipping_address_line1,
                       postcode: order.shipping_postal_code)
```

### Performance Considerations

- **N+1 Prevention**: When loading user with addresses, use `includes(:addresses)`
- **Default Lookup**: Partial index ensures O(1) lookup for default address
- **Address Count**: Use `addresses.size` (not `count`) when addresses are loaded
