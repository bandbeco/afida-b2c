# Data Model: Shop Page Filters and Search

**Feature**: Shop Page - Product Listing with Filters and Search
**Branch**: `003-shop-page-filters-search`
**Date**: 2025-01-14

## Overview

This feature requires **no new database tables or entities**. All functionality is implemented using existing `products`, `categories`, and `product_variants` tables with added indexes and model scopes.

---

## Existing Entities (No Schema Changes)

### Product

**Table**: `products`

**Relevant Columns**:
- `id` (bigint, PK) - Unique identifier
- `name` (string) - Product name (searchable)
- `sku` (string) - Stock keeping unit (searchable)
- `colour` (string) - Product color/variant (searchable)
- `slug` (string, unique) - SEO-friendly URL identifier
- `category_id` (bigint, FK) - Category association (filterable)
- `active` (boolean) - Whether product is visible (default scope filter)
- `position` (integer) - Sort order within category (default sort)
- `featured` (boolean) - Featured product flag
- `created_at` (datetime) - Creation timestamp
- `updated_at` (datetime) - Last update timestamp

**Existing Relationships**:
- `belongs_to :category` - Product must belong to a category
- `has_many :variants` (ProductVariant) - Product pricing/inventory
- `has_many :active_variants` - Filtered to active variants only

**Existing Scopes**:
- `default_scope { where(active: true).order(:position, :name) }` - Active products by position
- `featured` - Featured products only
- `catalog_products` - Standard and customizable template products

**New Scopes** (to be added):
- `search(query)` - Search by name, SKU, or colour using ILIKE
- `in_category(category_id)` - Filter by category
- `sorted(sort_param)` - Sort by various criteria (relevance, price, name)

**Validation Rules** (existing):
- `name` must be present
- `slug` must be present and unique
- `category` must be associated

---

### Category

**Table**: `categories`

**Relevant Columns**:
- `id` (bigint, PK) - Unique identifier
- `name` (string) - Category name
- `slug` (string, unique) - SEO-friendly URL identifier
- `products_count` (integer, default: 0) - Counter cache for products
- `position` (integer) - Sort order
- `description` (text) - Category description
- `meta_title` (string) - SEO meta title
- `meta_description` (text) - SEO meta description

**Existing Relationships**:
- `has_many :products` - Products in this category

**Existing Scopes**:
- None (uses default ordering)

**New Scopes** (to be added):
- None needed

---

### ProductVariant

**Table**: `product_variants`

**Relevant Columns**:
- `id` (bigint, PK) - Unique identifier
- `product_id` (bigint, FK) - Associated product
- `sku` (string) - Variant-specific SKU
- `price` (decimal) - Variant price
- `stock` (integer) - Available inventory
- `active` (boolean) - Whether variant is available
- `position` (integer) - Sort order within product

**Existing Relationships**:
- `belongs_to :product` - Variant belongs to product

**Existing Scopes**:
- `active` - Only active variants
- `by_position` - Ordered by position

**New Scopes** (to be added):
- None needed (price sorting uses aggregate in Product model)

---

## Database Schema Changes

### New Migration: Add Indexes for Performance

**File**: `db/migrate/[timestamp]_add_search_and_filter_indexes_to_products.rb`

**Purpose**: Optimize filter and search queries

**Indexes to Add**:

```ruby
class AddSearchAndFilterIndexesToProducts < ActiveRecord::Migration[8.1]
  def change
    # Category filtering (if not already indexed)
    add_index :products, :category_id unless index_exists?(:products, :category_id)

    # Search by name
    add_index :products, :name

    # Search by SKU
    add_index :products, :sku

    # Composite index for common filter: active products in category
    add_index :products, [:active, :category_id]
  end
end
```

**Rationale**:
- `category_id` index: Fast category filtering (may already exist from FK constraint)
- `name` index: Accelerates ILIKE searches on product names
- `sku` index: Accelerates ILIKE searches on SKUs
- `(active, category_id)` composite: Optimizes default query (active products in category)

**Performance Impact**:
- Category filter queries: O(n) → O(log n) with index
- Search queries: Full table scan → Index scan for matching rows
- Combined filters: Single composite index scan

---

## Model Scope Specifications

### Product.search(query)

**Purpose**: Search products by name, SKU, or colour

**Parameters**:
- `query` (String, optional) - Search term

**Behavior**:
- Returns all products if `query` is blank
- Performs case-insensitive search (ILIKE) across name, SKU, colour
- Uses `sanitize_sql_like` to prevent SQL injection on wildcard characters

**SQL Generated**:
```sql
SELECT * FROM products
WHERE active = true
  AND (name ILIKE '%query%' OR sku ILIKE '%query%' OR colour ILIKE '%query%')
ORDER BY position ASC, name ASC
```

**Example Usage**:
```ruby
Product.search("pizza")  # Returns pizza boxes, pizza bags, etc.
Product.search("")       # Returns all products (default scope)
Product.search(nil)      # Returns all products (default scope)
```

---

### Product.in_category(category_id)

**Purpose**: Filter products by category

**Parameters**:
- `category_id` (Integer/String, optional) - Category ID

**Behavior**:
- Returns all products if `category_id` is blank
- Filters to products in specified category
- Maintains default scope (active products only)

**SQL Generated**:
```sql
SELECT * FROM products
WHERE active = true
  AND category_id = ?
ORDER BY position ASC, name ASC
```

**Example Usage**:
```ruby
Product.in_category(3)    # Products in category ID 3
Product.in_category("")   # All products (default scope)
Product.in_category(nil)  # All products (default scope)
```

---

### Product.sorted(sort_param)

**Purpose**: Sort products by various criteria

**Parameters**:
- `sort_param` (String, optional) - Sort option

**Accepted Values**:
- `"relevance"` or `nil` or `""` - Default: position ASC, name ASC
- `"price_asc"` - Price low to high (min variant price)
- `"price_desc"` - Price high to low (max variant price)
- `"name_asc"` - Alphabetical A-Z

**Behavior**:
- Default maintains existing default scope ordering
- Price sorting uses subquery to get min/max variant price per product
- Alphabetical overrides position-based ordering

**SQL Generated** (price_asc example):
```sql
SELECT products.*,
       (SELECT MIN(price) FROM product_variants
        WHERE product_variants.product_id = products.id
          AND product_variants.active = true) as min_price
FROM products
WHERE active = true
ORDER BY min_price ASC, name ASC
```

**Example Usage**:
```ruby
Product.sorted("relevance")   # position ASC, name ASC (default)
Product.sorted("price_asc")   # min_price ASC, name ASC
Product.sorted("price_desc")  # max_price DESC, name ASC
Product.sorted("name_asc")    # name ASC
Product.sorted(nil)           # Same as relevance (default)
```

**Implementation Note**:
Price sorting requires LEFT JOIN or subquery to get variant prices. Using subquery in SELECT clause is simpler and prevents duplicate rows.

---

## Scope Chaining

**All scopes are chainable** to support combined filters:

```ruby
# Category filter + search
Product.in_category(3).search("pizza")

# Category filter + search + sort
Product.in_category(3).search("8oz").sorted("price_asc")

# Search + sort (no category filter)
Product.search("cups").sorted("name_asc")
```

**Chain Order**:
1. `in_category(id)` - Reduces dataset first
2. `search(query)` - Further filters
3. `sorted(param)` - Final ordering

**SQL Optimization**:
All scopes use `WHERE` clauses and indexes, so order doesn't significantly impact performance. ActiveRecord merges all conditions into a single query.

---

## State Transitions

**No state machines or status transitions** - this is a read-only feature.

Products maintain their existing lifecycle:
- Active products (`active = true`) are displayed
- Inactive products (`active = false`) are hidden by default scope
- No status changes triggered by filtering/searching

---

## Validation Rules

**No new validations needed** - all validations exist on current models:

**Product**:
- `name` presence
- `slug` presence and uniqueness
- `category_id` presence (via `belongs_to :category`)

**Category**:
- `name` presence
- `slug` presence and uniqueness

**ProductVariant**:
- `product_id` presence (via `belongs_to :product`)
- `price` numericality (greater than or equal to 0)
- `sku` presence

---

## Performance Considerations

### Eager Loading

To prevent N+1 queries, the controller must eager load associations:

```ruby
@products = Product
  .includes(:category,
            :active_variants,
            product_photo_attachment: :blob,
            lifestyle_photo_attachment: :blob)
  .in_category(params[:category_id])
  .search(params[:q])
  .sorted(params[:sort])
  .page(params[:page])
```

**Associations Loaded**:
- `category` - For displaying category name on product cards
- `active_variants` - For calculating price range
- `product_photo_attachment` and `lifestyle_photo_attachment` - For product images

**Query Count**:
- Without eager loading: 1 + N + N + N + N = 4N+1 queries (for N products)
- With eager loading: 4-5 queries total (regardless of N)

### Index Usage

With added indexes, queries are optimized:

| Query Type | Without Index | With Index | Speedup |
|------------|---------------|------------|---------|
| Category filter | Full scan (O(n)) | Index seek (O(log n)) | 10-100x |
| Name search | Full scan | Index scan + filter | 5-20x |
| SKU search | Full scan | Index scan + filter | 5-20x |
| Combined filter | Full scan | Composite index | 20-100x |

### Pagination Impact

Pagy gem limits query size:
- 24 products per page = constant query time regardless of total products
- No OFFSET/LIMIT performance degradation (Pagy uses efficient pagination)

---

## Summary

**Entities Modified**: Product (add scopes), Category (no changes), ProductVariant (no changes)

**Schema Changes**: Add 4 indexes to products table

**New Scopes**:
- `Product.search(query)` - ILIKE search across name/SKU/colour
- `Product.in_category(category_id)` - Category filter
- `Product.sorted(sort_param)` - Sort by relevance/price/name

**Performance**:
- Indexes reduce query time 5-100x
- Eager loading prevents N+1 queries
- Pagination limits dataset size

**Validation**: No new validations (existing rules sufficient)

All data model design is complete. Ready to proceed to API contracts (Rails controller actions).
