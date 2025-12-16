# Data Model: Scheduled Reorder with Review

**Feature**: 014-scheduled-reorder
**Date**: 2025-12-16

## Entity Relationship Diagram

```
┌─────────────────┐       ┌─────────────────────────┐       ┌──────────────────────────┐
│      User       │       │    ReorderSchedule      │       │   ReorderScheduleItem    │
├─────────────────┤       ├─────────────────────────┤       ├──────────────────────────┤
│ id              │───┐   │ id                      │───┐   │ id                       │
│ email_address   │   │   │ user_id (FK)            │   │   │ reorder_schedule_id (FK) │
│ stripe_customer_│   └──>│ frequency (enum)        │   └──>│ product_variant_id (FK)  │
│   id (new)      │       │ status (enum)           │       │ quantity                 │
│ ...             │       │ next_scheduled_date     │       │ price (reference)        │
└─────────────────┘       │ stripe_payment_method_id│       │ created_at               │
                          │ created_at              │       │ updated_at               │
                          │ updated_at              │       └──────────────────────────┘
                          │ cancelled_at            │                    │
                          │ paused_at               │                    │
                          └─────────────────────────┘                    │
                                      │                                  │
                                      │ 1:N                              │
                                      ▼                                  │
                          ┌─────────────────────────┐                    │
                          │     PendingOrder        │                    │
                          ├─────────────────────────┤                    │
                          │ id                      │                    │
                          │ reorder_schedule_id (FK)│                    │
                          │ order_id (FK, optional) │                    │
                          │ status (enum)           │                    │
                          │ items_snapshot (JSONB)  │<───────────────────┘
                          │ scheduled_for           │     (snapshot of items
                          │ confirmed_at            │      at current prices)
                          │ expired_at              │
                          │ created_at              │
                          │ updated_at              │
                          └─────────────────────────┘
                                      │
                                      │ 1:1 (when confirmed)
                                      ▼
                          ┌─────────────────────────┐
                          │        Order            │
                          ├─────────────────────────┤
                          │ id                      │
                          │ reorder_schedule_id (FK)│ ← New column
                          │ ...                     │
                          └─────────────────────────┘
```

## Tables

### reorder_schedules

Primary entity representing a customer's recurring order setup.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | Primary key |
| user_id | bigint | FK, NOT NULL, INDEX | Owner of the schedule |
| frequency | integer | NOT NULL | Enum: 0=weekly, 1=every_two_weeks, 2=monthly, 3=every_3_months |
| status | integer | NOT NULL, DEFAULT 0 | Enum: 0=active, 1=paused, 2=cancelled |
| next_scheduled_date | date | NOT NULL, INDEX | Next delivery date |
| stripe_payment_method_id | string | NOT NULL | Stripe PaymentMethod ID for charges |
| paused_at | datetime | NULL | When schedule was paused |
| cancelled_at | datetime | NULL | When schedule was cancelled |
| created_at | datetime | NOT NULL | Creation timestamp |
| updated_at | datetime | NOT NULL | Last update timestamp |

**Indexes**:
- `index_reorder_schedules_on_user_id`
- `index_reorder_schedules_on_next_scheduled_date` (for job queries)
- `index_reorder_schedules_on_status_and_next_scheduled_date` (composite for active schedules query)

**Migration**:
```ruby
create_table :reorder_schedules do |t|
  t.references :user, null: false, foreign_key: true
  t.integer :frequency, null: false
  t.integer :status, null: false, default: 0
  t.date :next_scheduled_date, null: false
  t.string :stripe_payment_method_id, null: false
  t.datetime :paused_at
  t.datetime :cancelled_at
  t.timestamps
end

add_index :reorder_schedules, :next_scheduled_date
add_index :reorder_schedules, [:status, :next_scheduled_date]
```

---

### reorder_schedule_items

Individual products in a reorder schedule.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | Primary key |
| reorder_schedule_id | bigint | FK, NOT NULL, INDEX | Parent schedule |
| product_variant_id | bigint | FK, NOT NULL, INDEX | Product variant |
| quantity | integer | NOT NULL, > 0 | Number of units/packs |
| price | decimal(10,2) | NOT NULL | Reference price at time of adding |
| created_at | datetime | NOT NULL | Creation timestamp |
| updated_at | datetime | NOT NULL | Last update timestamp |

**Indexes**:
- `index_reorder_schedule_items_on_reorder_schedule_id`
- `index_reorder_schedule_items_on_product_variant_id`
- `index_reorder_schedule_items_on_schedule_and_variant` (uniqueness)

**Migration**:
```ruby
create_table :reorder_schedule_items do |t|
  t.references :reorder_schedule, null: false, foreign_key: true
  t.references :product_variant, null: false, foreign_key: true
  t.integer :quantity, null: false
  t.decimal :price, precision: 10, scale: 2, null: false
  t.timestamps
end

add_index :reorder_schedule_items, [:reorder_schedule_id, :product_variant_id],
          unique: true, name: 'idx_schedule_items_unique'
```

---

### pending_orders

Draft orders awaiting customer confirmation.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | Primary key |
| reorder_schedule_id | bigint | FK, NOT NULL, INDEX | Parent schedule |
| order_id | bigint | FK, NULL, INDEX | Created order (when confirmed) |
| status | integer | NOT NULL, DEFAULT 0 | Enum: 0=pending, 1=confirmed, 2=expired |
| items_snapshot | jsonb | NOT NULL | Items with current prices |
| scheduled_for | date | NOT NULL, INDEX | Intended delivery date |
| confirmed_at | datetime | NULL | When customer confirmed |
| expired_at | datetime | NULL | When order expired |
| created_at | datetime | NOT NULL | Creation timestamp |
| updated_at | datetime | NOT NULL | Last update timestamp |

**items_snapshot schema**:
```json
{
  "items": [
    {
      "product_variant_id": 123,
      "product_name": "Kraft Napkins",
      "variant_name": "Pack of 500",
      "quantity": 2,
      "price": "8.00",
      "available": true
    }
  ],
  "subtotal": "16.00",
  "vat": "3.20",
  "shipping": "0.00",
  "total": "19.20",
  "unavailable_items": [
    {
      "product_variant_id": 456,
      "product_name": "Discontinued Item",
      "variant_name": "Large",
      "reason": "Product no longer available"
    }
  ]
}
```

**Indexes**:
- `index_pending_orders_on_reorder_schedule_id`
- `index_pending_orders_on_order_id`
- `index_pending_orders_on_scheduled_for`
- `index_pending_orders_on_status_and_scheduled_for` (for expiration job)

**Migration**:
```ruby
create_table :pending_orders do |t|
  t.references :reorder_schedule, null: false, foreign_key: true
  t.references :order, foreign_key: true
  t.integer :status, null: false, default: 0
  t.jsonb :items_snapshot, null: false, default: {}
  t.date :scheduled_for, null: false
  t.datetime :confirmed_at
  t.datetime :expired_at
  t.timestamps
end

add_index :pending_orders, :scheduled_for
add_index :pending_orders, [:status, :scheduled_for]
```

---

### users (modifications)

Add Stripe customer ID for payment method management.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| stripe_customer_id | string | NULL, INDEX | Stripe Customer ID |

**Migration**:
```ruby
add_column :users, :stripe_customer_id, :string
add_index :users, :stripe_customer_id, unique: true
```

---

### orders (modifications)

Link orders to their source reorder schedule.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| reorder_schedule_id | bigint | FK, NULL, INDEX | Source schedule (if from reorder) |

**Migration**:
```ruby
add_reference :orders, :reorder_schedule, foreign_key: true
```

Note: Removes existing `subscription_id` column (from unmerged feature) - clean slate.

---

## Model Definitions

### ReorderSchedule

```ruby
class ReorderSchedule < ApplicationRecord
  belongs_to :user
  has_many :reorder_schedule_items, dependent: :destroy
  has_many :product_variants, through: :reorder_schedule_items
  has_many :pending_orders, dependent: :destroy
  has_many :orders, dependent: :nullify

  enum :frequency, {
    every_week: 0,
    every_two_weeks: 1,
    every_month: 2,
    every_3_months: 3
  }, validate: true

  enum :status, {
    active: 0,
    paused: 1,
    cancelled: 2
  }, validate: true, default: :active

  validates :next_scheduled_date, presence: true
  validates :stripe_payment_method_id, presence: true

  scope :active, -> { where(status: :active) }
  scope :due_in_days, ->(days) { where(next_scheduled_date: days.days.from_now.to_date) }

  def advance_schedule!
    self.next_scheduled_date = calculate_next_date
    save!
  end

  def pause!
    update!(status: :paused, paused_at: Time.current)
  end

  def resume!
    update!(status: :active, paused_at: nil, next_scheduled_date: calculate_next_date(from: Date.current))
  end

  def cancel!
    update!(status: :cancelled, cancelled_at: Time.current)
  end

  private

  def calculate_next_date(from: next_scheduled_date)
    case frequency
    when "every_week" then from + 1.week
    when "every_two_weeks" then from + 2.weeks
    when "every_month" then from + 1.month
    when "every_3_months" then from + 3.months
    end
  end
end
```

### ReorderScheduleItem

```ruby
class ReorderScheduleItem < ApplicationRecord
  belongs_to :reorder_schedule
  belongs_to :product_variant

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :product_variant_id, uniqueness: { scope: :reorder_schedule_id }

  delegate :product, :display_name, to: :product_variant

  def available?
    product_variant.active? && product_variant.product&.active?
  end

  def current_price
    product_variant.price
  end
end
```

### PendingOrder

```ruby
class PendingOrder < ApplicationRecord
  belongs_to :reorder_schedule
  belongs_to :order, optional: true

  enum :status, {
    pending: 0,
    confirmed: 1,
    expired: 2
  }, validate: true, default: :pending

  validates :items_snapshot, presence: true
  validates :scheduled_for, presence: true

  scope :pending, -> { where(status: :pending) }
  scope :expired_unprocessed, -> { pending.where("scheduled_for < ?", Date.current) }

  def confirm!(order)
    update!(
      status: :confirmed,
      order: order,
      confirmed_at: Time.current
    )
  end

  def expire!
    update!(status: :expired, expired_at: Time.current)
  end

  def items
    (items_snapshot["items"] || []).map(&:with_indifferent_access)
  end

  def total_amount
    items_snapshot["total"]&.to_d || 0
  end

  def subtotal_amount
    items_snapshot["subtotal"]&.to_d || 0
  end

  def vat_amount
    items_snapshot["vat"]&.to_d || 0
  end

  def unavailable_items
    (items_snapshot["unavailable_items"] || []).map(&:with_indifferent_access)
  end

  # Generate signed token for email links
  def confirmation_token
    to_sgid(expires_in: 7.days, for: "pending_order_confirm").to_s
  end

  def edit_token
    to_sgid(expires_in: 7.days, for: "pending_order_edit").to_s
  end
end
```

---

## State Transitions

### ReorderSchedule Status

```
        ┌─────────┐
        │ active  │◄──────────┐
        └────┬────┘           │
             │                │
       pause!│          resume!
             │                │
             ▼                │
        ┌─────────┐           │
        │ paused  │───────────┘
        └────┬────┘
             │
       cancel! (from any state)
             │
             ▼
        ┌───────────┐
        │ cancelled │
        └───────────┘
```

### PendingOrder Status

```
        ┌─────────┐
        │ pending │
        └────┬────┘
             │
    ┌────────┴────────┐
    │                 │
confirm!           expire!
    │                 │
    ▼                 ▼
┌───────────┐   ┌─────────┐
│ confirmed │   │ expired │
└───────────┘   └─────────┘
```

---

## Validation Rules

### ReorderSchedule
- Must belong to a user
- `frequency` must be valid enum value
- `status` must be valid enum value
- `next_scheduled_date` must be present
- `stripe_payment_method_id` must be present

### ReorderScheduleItem
- Must belong to a schedule
- Must belong to a product variant
- `quantity` must be > 0
- `price` must be >= 0
- Same variant cannot appear twice in same schedule (unique constraint)

### PendingOrder
- Must belong to a schedule
- `items_snapshot` must be present
- `scheduled_for` must be present
- Only one pending order per schedule at a time (enforced in application logic)
