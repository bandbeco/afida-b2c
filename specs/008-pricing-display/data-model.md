# Data Model: Pricing Display Consolidation

**Feature**: 008-pricing-display
**Date**: 2025-11-26

## Entity Changes

### OrderItem (Modified)

**Purpose**: Represents a line item in a completed order. Stores pricing data to enable correct historical display.

**Schema Change**:

```ruby
# Migration: add_pac_size_to_order_items
add_column :order_items, :pac_size, :integer, null: true
```

**Current Fields** (unchanged):
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | bigint | PK, not null | Primary key |
| order_id | bigint | FK, not null | Reference to parent order |
| product_id | bigint | FK, nullable | Reference to product (for lookups) |
| product_variant_id | bigint | FK, not null | Reference to variant |
| product_name | string | not null | Snapshot of product name at order time |
| product_sku | string | not null | Snapshot of SKU at order time |
| price | decimal(10,2) | not null | **SEMANTIC CHANGE**: Now stores pack price (was unit price) |
| quantity | integer | not null | Number of units ordered |
| line_total | decimal(10,2) | not null | Total for this line item |
| configuration | jsonb | default {} | Branded product configuration (if applicable) |

**New Field**:
| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| pac_size | integer | nullable | Units per pack (null = unit pricing) |

**Computed Properties** (new model methods):

| Method | Return Type | Description |
|--------|-------------|-------------|
| `pack_priced?` | Boolean | True if standard product with pac_size > 1 |
| `pack_price` | Decimal | The pack price (returns `price` if pack-priced, nil otherwise) |
| `unit_price` | Decimal | The unit price (derived from pack_price / pac_size, or price if unit-priced) |

**Business Rules**:
- `pack_priced?` returns `!configured? && pac_size.present? && pac_size > 1`
- If `pack_priced?` is true: `unit_price = price / pac_size`
- If `pack_priced?` is false: `unit_price = price` (price IS the unit price)
- Legacy orders with `pac_size = null` treated as unit-priced

---

### CartItem (Modified - Methods Only)

**Purpose**: Represents a line item in an active cart. No schema changes, only new methods for consistency.

**New Computed Properties**:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `pack_priced?` | Boolean | True if standard product with pac_size > 1 |
| `pack_price` | Decimal | The pack price (returns `price` if pack-priced, nil otherwise) |

**Existing Methods** (unchanged):
- `unit_price` - Already exists, returns derived unit price
- `configured?` - Already exists, checks if branded/custom product
- `price` - Already exists, stores pack price for standard items

**Business Rules**:
- `pack_priced?` returns `!configured? && product_variant.pac_size.present? && product_variant.pac_size > 1`
- Accesses `pac_size` from associated `product_variant` (not stored on CartItem)

---

## Relationships

```
Order (1) ----< (many) OrderItem
                         |
                         | pac_size (new column)
                         | price (semantic: pack price)
                         |
                         v
                    ProductVariant (reference only)
                         |
                         | pac_size (source of truth)

Cart (1) ----< (many) CartItem
                         |
                         | price (pack price)
                         |
                         v
                    ProductVariant (live reference)
                         |
                         | pac_size (accessed via association)
```

---

## Migration Details

**Migration Name**: `add_pac_size_to_order_items`

**Up**:
```ruby
add_column :order_items, :pac_size, :integer
```

**Down**:
```ruby
remove_column :order_items, :pac_size
```

**Notes**:
- No data migration required (site not live)
- Column is nullable to support legacy orders
- No index needed (not queried/filtered)

---

## Data Flow

### Order Creation Flow (Modified)

**Before**:
```ruby
OrderItem.create_from_cart_item(cart_item, order)
  -> price: cart_item.unit_price  # Loses pack context
```

**After**:
```ruby
OrderItem.create_from_cart_item(cart_item, order)
  -> price: cart_item.price       # Pack price preserved
  -> pac_size: cart_item.product_variant.pac_size  # Pack size captured
```

### Display Flow (New)

```
View/PDF calls format_price_display(item)
  -> Helper checks item.pack_priced?
  -> If true: format "#{pack_price} / pack (#{unit_price} / unit)"
  -> If false: format "#{unit_price} / unit"
```

---

## Validation Rules

### OrderItem
- `pac_size` must be positive integer if present
- `pac_size` can be null (for branded products or legacy orders)
- No change to existing validations

### CartItem
- No new validations (pac_size accessed from product_variant)

---

## Edge Cases

| Scenario | pac_size value | pack_priced? | Display Format |
|----------|----------------|--------------|----------------|
| Branded product | null | false | "£0.0320 / unit" |
| Standard product, pack of 500 | 500 | true | "£15.99 / pack (£0.0320 / unit)" |
| Standard product, pack of 1 | 1 | false | "£15.99 / unit" |
| Legacy order (no pac_size) | null | false | "£X.XX / unit" |
| Product variant without pac_size | null | false | "£X.XX / unit" |
