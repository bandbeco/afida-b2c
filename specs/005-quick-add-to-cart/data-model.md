# Quick Add to Cart - Data Model

**Date**: 2025-01-15
**Branch**: `005-quick-add-to-cart`

## Overview

Quick Add feature uses **existing database models** with no schema changes. This document captures the relevant models, relationships, and new scopes required.

---

## Existing Models (No Schema Changes)

### Product

**Table**: `products`

**Relevant Fields**:
| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Primary key |
| `slug` | string | SEO-friendly URL identifier (unique) |
| `name` | string | Product name |
| `product_type` | enum | One of: 'standard', 'customizable_template', 'customized_instance' |
| `active` | boolean | Visibility flag (only active products shown) |
| `category_id` | integer | Foreign key to categories table |

**Existing Scopes**:
```ruby
default_scope { where(active: true).order(:position, :name) }
scope :catalog_products, -> { where(product_type: ["standard", "customizable_template"]) }
```

**New Scope** (to be added):
```ruby
scope :quick_add_eligible, -> { where(product_type: 'standard') }
```

**Rationale**:
- Excludes `customizable_template` products (branded cups) - too complex for modal
- Excludes `customized_instance` products (organization-specific products)
- Only standard catalog products eligible for quick add

**Usage**:
```ruby
# In views
@products.quick_add_eligible

# In controllers
Product.quick_add_eligible.in_categories(params[:category])
```

---

### ProductVariant

**Table**: `product_variants`

**Relevant Fields**:
| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Primary key |
| `product_id` | integer | Foreign key to products |
| `sku` | string | Unique variant identifier (e.g., "SWC-8OZ-WHT") |
| `name` | string | Variant name (e.g., "8oz", "12oz") |
| `price` | decimal | Pack price in cents |
| `pac_size` | integer | Units per pack (e.g., 50) |
| `active` | boolean | Visibility flag |
| `position` | integer | Sort order within product |

**Existing Scopes**:
```ruby
scope :active, -> { where(active: true) }
scope :by_position, -> { order(:position, :name) }
```

**Relationships**:
```ruby
belongs_to :product
has_many :cart_items, dependent: :restrict_with_error
```

**Key Methods**:
```ruby
def display_name
  "#{product.name} (#{name})"
end

def unit_price
  return price unless pac_size.present? && pac_size > 0
  price / pac_size
end
```

**Usage in Quick Add**:
- Variant selector populated from `@product.active_variants`
- Form submission sends `variant_sku` to identify selected variant
- Quantity options calculated from `pac_size` (1-10 packs)

---

### Cart

**Table**: `carts`

**Relevant Fields**:
| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Primary key |
| `user_id` | integer | Foreign key to users (nullable for guest carts) |
| `session_id` | string | Session identifier for guest carts |

**Relationships**:
```ruby
belongs_to :user, optional: true
has_many :cart_items, dependent: :destroy
```

**Key Methods**:
```ruby
def items_count
  cart_items.sum(:quantity)
end

def subtotal_amount
  cart_items.sum("price * quantity")
end

def total_amount
  subtotal_amount * (1 + VAT_RATE)
end
```

**Usage in Quick Add**:
- Access via `Current.cart` (set by ApplicationController)
- Quick add form submits to `CartItemsController#create`
- Cart drawer updates via Turbo Stream response

---

### CartItem

**Table**: `cart_items`

**Relevant Fields**:
| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Primary key |
| `cart_id` | integer | Foreign key to carts |
| `product_variant_id` | integer | Foreign key to product_variants |
| `quantity` | integer | Quantity in units |
| `price` | decimal | Unit price snapshot (cents) |

**Relationships**:
```ruby
belongs_to :cart
belongs_to :product_variant
```

**Validations**:
```ruby
validates :quantity, presence: true, numericality: { greater_than: 0 }
validates :price, presence: true, numericality: { greater_than: 0 }
```

**Usage in Quick Add**:
- Find or create cart item by `product_variant_id`
- If exists: increment `quantity`
- If new: create with selected `quantity` and `price`

---

## Relationships Diagram

```
Category (1) ──< (many) Product (1) ──< (many) ProductVariant
                           │
                           │ (filter: product_type = 'standard')
                           ↓
                    Quick Add Eligible

Cart (1) ──< (many) CartItem >── (1) ProductVariant >── (1) Product
```

---

## Data Flow: Quick Add to Cart

### Step 1: Render Product Cards
```ruby
# View: app/views/products/index.html.erb
@products = Product.quick_add_eligible
                   .includes(:active_variants, :category)
                   .in_categories(params[:categories])
                   .sorted(params[:sort])
```

**No N+1 Queries**: `includes` eager-loads variants and category.

### Step 2: Load Modal Content
```ruby
# Controller: ProductsController#quick_add
@product = Product.find_by!(slug: params[:id])

# Validate eligibility
redirect_to product_path(@product) unless @product.product_type == 'standard'

# Load variants
@variants = @product.active_variants.by_position
```

### Step 3: Submit Form
```ruby
# Form params
{
  cart_item: {
    variant_sku: "SWC-8OZ-WHT",
    quantity: 50  # 1 pack of 50 units
  }
}
```

### Step 4: Create/Update Cart Item
```ruby
# Controller: CartItemsController#create_standard_cart_item
product_variant = ProductVariant.find_by!(sku: params[:cart_item][:variant_sku])
cart_item = Current.cart.cart_items.find_or_initialize_by(product_variant: product_variant)

if cart_item.new_record?
  cart_item.quantity = params[:cart_item][:quantity]
  cart_item.price = product_variant.price
else
  cart_item.quantity += params[:cart_item][:quantity]  # Increment existing
end

cart_item.save!
```

---

## Validation Rules

### Product Eligibility
- ✅ Product must be `active: true`
- ✅ Product must have `product_type: 'standard'`
- ✅ Product must have at least one active variant

**Implementation**:
```ruby
# In view
<% if product.product_type == 'standard' && product.active_variants.any? %>
  <%= link_to "Quick Add", product_quick_add_path(product), ... %>
<% end %>
```

### Variant Selection
- ✅ Variant must be `active: true`
- ✅ Variant must belong to selected product
- ✅ Variant `sku` must exist in database

**Implementation**:
```ruby
# In controller
product_variant = ProductVariant.active.find_by!(sku: params[:cart_item][:variant_sku])

# Raise ActiveRecord::RecordNotFound if SKU invalid or inactive
```

### Quantity Rules
- ✅ Quantity must be multiple of `pac_size`
- ✅ Quantity range: 1-10 packs
- ✅ Minimum order: 1 pack (e.g., 50 units for 50-pack product)

**Implementation**:
```ruby
# In view: quantity selector
<% pac_size = variant.pac_size || 1 %>
<%= select_tag "cart_item[quantity]",
               options_for_select((1..10).map { |n|
                 ["#{n} pack(s) (#{n * pac_size} units)", n * pac_size]
               }),
               class: "select select-bordered" %>
```

---

## Database Queries

### Query 1: Load Product Cards (Shop Page)
```sql
SELECT products.*, categories.name AS category_name
FROM products
INNER JOIN categories ON categories.id = products.category_id
WHERE products.active = true
  AND products.product_type = 'standard'
ORDER BY products.position, products.name;
```

**Performance**:
- Single query with JOIN
- Indexed columns: `products.active`, `products.product_type`, `products.position`
- **No N+1**: Active variants eager-loaded via `includes(:active_variants)`

### Query 2: Load Modal Variants
```sql
SELECT *
FROM product_variants
WHERE product_variants.product_id = ?
  AND product_variants.active = true
ORDER BY product_variants.position, product_variants.name;
```

**Performance**:
- Single query per modal load
- Indexed columns: `product_variants.product_id`, `product_variants.active`

### Query 3: Find or Create Cart Item
```sql
-- Step 1: Find variant
SELECT * FROM product_variants WHERE sku = ? AND active = true LIMIT 1;

-- Step 2: Find existing cart item
SELECT * FROM cart_items
WHERE cart_id = ? AND product_variant_id = ?
LIMIT 1;

-- Step 3: Update or insert
UPDATE cart_items SET quantity = quantity + ? WHERE id = ?;
-- OR
INSERT INTO cart_items (cart_id, product_variant_id, quantity, price)
VALUES (?, ?, ?, ?);
```

**Performance**:
- 3 queries total (find variant, find cart item, upsert)
- Indexed columns: `product_variants.sku`, `cart_items.cart_id`, `cart_items.product_variant_id`

---

## Testing Queries

### Fixtures (test/fixtures/)

**products.yml**:
```yaml
hot_cup:
  name: "Single Wall Hot Cup"
  slug: "single-wall-hot-cup"
  product_type: standard
  active: true
  category: cups

branded_cup:
  name: "Branded Hot Cup"
  slug: "branded-hot-cup"
  product_type: customizable_template
  active: true
  category: cups
```

**product_variants.yml**:
```yaml
hot_cup_8oz:
  product: hot_cup
  sku: "SWC-8OZ-WHT"
  name: "8oz"
  price: 1250  # £12.50
  pac_size: 50
  active: true

hot_cup_12oz:
  product: hot_cup
  sku: "SWC-12OZ-WHT"
  name: "12oz"
  price: 1550  # £15.50
  pac_size: 50
  active: true
```

**Expected Test Scenarios**:
1. Quick Add button shows for standard products
2. Quick Add button hidden for customizable products
3. Modal loads with correct variants
4. Form submission increments existing cart item
5. Form submission creates new cart item if not exists

---

## Schema Changes Summary

**✅ NO DATABASE MIGRATIONS REQUIRED**

All functionality implemented using existing schema:
- New scope on `Product` model (code-only change)
- New controller action and routes (code-only change)
- New views and Stimulus controller (code-only change)

---

## Next Steps

1. Implement `Product.quick_add_eligible` scope
2. Add `ProductsController#quick_add` action
3. Create modal views and form partials
4. Write system tests for complete flow
5. Verify no N+1 queries with Bullet gem
