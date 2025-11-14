# Data Model: Legacy URL Smart Redirects

**Feature**: 001-legacy-url-redirects
**Date**: 2025-11-14

## Overview

This document describes the database schema for the Legacy URL redirect system.

## Entity: LegacyRedirect

Represents a mapping from a legacy product URL (from old afida.com site) to a new product page with optional variant parameters.

### Schema

**Table**: `legacy_redirects`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `bigint` | PRIMARY KEY | Auto-incrementing unique identifier |
| `legacy_path` | `string(500)` | NOT NULL, UNIQUE (case-insensitive) | Legacy URL path (e.g., `/product/12-310-x-310mm-pizza-box-kraft`) |
| `target_slug` | `string(255)` | NOT NULL, FOREIGN KEY (products.slug) | Target product slug (e.g., `pizza-box`) |
| `variant_params` | `jsonb` | NOT NULL, DEFAULT `{}` | Variant parameters as JSON (e.g., `{"size": "12in", "colour": "kraft"}`) |
| `hit_count` | `integer` | NOT NULL, DEFAULT `0` | Number of times this redirect has been accessed |
| `active` | `boolean` | NOT NULL, DEFAULT `true` | Whether this redirect is currently enabled |
| `created_at` | `timestamp` | NOT NULL | Record creation timestamp |
| `updated_at` | `timestamp` | NOT NULL | Record last update timestamp |

### Indexes

1. **Unique case-insensitive index on legacy_path**
   - Name: `index_legacy_redirects_on_lower_legacy_path`
   - Expression: `LOWER(legacy_path)`
   - Purpose: Fast case-insensitive lookups, prevents duplicate paths with different casing

2. **Index on active**
   - Name: `index_legacy_redirects_on_active`
   - Purpose: Filter active vs inactive redirects efficiently

3. **Index on hit_count**
   - Name: `index_legacy_redirects_on_hit_count`
   - Purpose: Analytics queries (e.g., most used redirects)

### Validations

**Model**: `app/models/legacy_redirect.rb`

1. **Presence**:
   - `legacy_path` must be present
   - `target_slug` must be present

2. **Uniqueness**:
   - `legacy_path` must be unique (case-insensitive)

3. **Format**:
   - `legacy_path` must match `/^\/product\/.*/` (start with `/product/`)

4. **Custom Validation**:
   - `target_slug_exists`: Validates that referenced product exists in `products` table

### Scopes

1. **active**: `where(active: true)` - Returns only active redirects
2. **inactive**: `where(active: false)` - Returns only inactive redirects
3. **most_used**: `order(hit_count: :desc)` - Orders by hit count (descending)
4. **recently_updated**: `order(updated_at: :desc)` - Orders by update time (descending)

### Instance Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `record_hit!` | `boolean` | Atomically increments `hit_count` by 1 |
| `target_url` | `string` | Builds full target URL with variant params (e.g., `/products/pizza-box?size=12in&colour=kraft`) |
| `deactivate!` | `boolean` | Sets `active` to false |
| `activate!` | `boolean` | Sets `active` to true |

### Class Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `find_by_path` | `path` (string) | `LegacyRedirect` or `nil` | Case-insensitive lookup by legacy_path |
| `find_active_by_path` | `path` (string) | `LegacyRedirect` or `nil` | Case-insensitive lookup of active redirect only |

## Relationships

### LegacyRedirect → Product

**Type**: Implicit foreign key (validated, not enforced by database constraint)

**Relationship**: `LegacyRedirect.target_slug` references `Product.slug`

**Validation**: Model validation (`target_slug_exists`) ensures product exists

**Cascade Behavior**: None (validation prevents orphaned redirects)

**Rationale**: Product slugs can change, but legacy redirects should remain stable. Validation prevents creating redirects to non-existent products. If a product is deleted, admin must manually update or deactivate affected redirects.

## State Diagram

```
┌─────────────────┐
│   New Redirect  │
│   (active: true)│
└────────┬────────┘
         │
         │ record_hit!
         ▼
┌─────────────────┐
│  Active Redirect│
│  (hit_count > 0)│
└────────┬────────┘
         │
         │ deactivate!
         ▼
┌─────────────────┐
│Inactive Redirect│
│ (active: false) │
└────────┬────────┘
         │
         │ activate!
         ▼
┌─────────────────┐
│  Active Redirect│
│  (hit_count > 0)│
└─────────────────┘
```

## Lifecycle

1. **Creation**: Redirect created via seeds, admin interface, or rake task
2. **Activation**: Redirect is active by default (`active: true`)
3. **Usage**: Each request increments `hit_count` (analytics tracking)
4. **Deactivation**: Admin can deactivate redirect without deleting (preserves analytics)
5. **Reactivation**: Admin can re-enable previously deactivated redirect
6. **Deletion**: Admin can permanently delete redirect (rarely needed)

## Data Integrity

### Invariants

1. `legacy_path` must start with `/product/` (enforced by format validation)
2. `target_slug` must reference an existing product (enforced by custom validation)
3. `hit_count` must be >= 0 (enforced by default value and increment-only operations)
4. `variant_params` must be valid JSON object (enforced by JSONB type)

### Constraints

- No database-level foreign key constraint (to allow graceful handling of product deletions)
- Unique constraint on `LOWER(legacy_path)` prevents duplicate redirects
- NOT NULL constraints on all required fields

## Migration Strategy

### Seeding Data

**Source**: `config/legacy_redirects.csv` (64 mappings)

**Process**:
1. Parse CSV file row by row
2. Extract `legacy_path` from `source` column
3. Parse `target` column to extract `target_slug` and `variant_params`
4. Use `find_or_create_by!` for idempotent seeding
5. Set `active: true` by default

**Idempotency**: Running seeds multiple times updates existing records without duplicating

### Rolling Back

Migration is reversible:
```bash
rails db:rollback  # Drops legacy_redirects table
```

Seed rollback requires manual deletion or truncation:
```bash
rails runner "LegacyRedirect.delete_all"
```

## Performance Characteristics

### Query Performance

**Lookup by path** (most common operation):
- Uses functional index on `LOWER(legacy_path)`
- Expected performance: O(log n), typically <1ms for 64 records
- Scales well to thousands of redirects

**Analytics queries**:
- Index on `hit_count` enables fast sorting for "most used" queries
- Index on `active` enables fast filtering

### Write Performance

**Insert/Update**: Single row operations, fast (<5ms)
**Hit count increment**: Atomic operation using SQL `UPDATE ... SET hit_count = hit_count + 1`

### Storage

**Estimated size per row**: ~500 bytes (including indexes)
**Total size for 64 records**: ~32 KB (negligible)

## Example Data

```ruby
# Pizza box redirect with size variant
LegacyRedirect.create!(
  legacy_path: "/product/12-310-x-310mm-pizza-box-kraft",
  target_slug: "pizza-box",
  variant_params: { size: "12in", colour: "kraft" },
  active: true,
  hit_count: 0
)

# Straw redirect with size and colour variants
LegacyRedirect.create!(
  legacy_path: "/product/6mm-x-200mm-bamboo-fibre-straws-black",
  target_slug: "bio-fibre-straws",
  variant_params: { size: "6x200mm", colour: "black" },
  active: true,
  hit_count: 0
)

# Simple redirect without variants
LegacyRedirect.create!(
  legacy_path: "/product/wooden-coffee-stirrers-140mm",
  target_slug: "wooden-coffee-stirrers",
  variant_params: { size: "14cm", colour: "natural" },
  active: true,
  hit_count: 0
)
```
