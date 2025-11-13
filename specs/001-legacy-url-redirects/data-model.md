# Data Model: Legacy URL Smart Redirects

**Feature**: 001-legacy-url-redirects
**Date**: 2025-11-13
**Status**: Complete

## Entity: LegacyRedirect

### Purpose

Represents a mapping from a legacy product URL (from old afida.com site) to a new product page with optional extracted variant parameters. Stores redirect configuration, usage analytics, and enables/disables redirects without deletion.

### Database Schema

**Table**: `legacy_redirects`

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `bigint` | Primary key, auto-increment | Unique identifier |
| `legacy_path` | `string (500)` | NOT NULL, indexed (functional LOWER) | Original URL path (e.g., `/product/12-pizza-box-kraft`) |
| `target_slug` | `string (255)` | NOT NULL | Product slug on new site (e.g., `pizza-box-kraft`) |
| `variant_params` | `jsonb` | Default: `{}` | Extracted variant parameters (e.g., `{"size": "12\"", "colour": "Kraft"}`) |
| `hit_count` | `integer` | NOT NULL, default: 0 | Number of times this redirect has been used |
| `active` | `boolean` | NOT NULL, default: true | Whether this redirect is currently enabled |
| `created_at` | `timestamp` | NOT NULL, auto | Record creation timestamp |
| `updated_at` | `timestamp` | NOT NULL, auto | Record last update timestamp |

**Indexes**:
- Primary key index on `id`
- Functional unique index on `LOWER(legacy_path)` for case-insensitive lookups
- Index on `active` for filtering enabled redirects
- Index on `hit_count DESC` for analytics queries (most used redirects)

**Constraints**:
- `legacy_path` must be unique (case-insensitive)
- `legacy_path` must start with `/product/` (application-level validation)
- `target_slug` must reference an existing product slug (application-level validation)
- `variant_params` must be valid JSON object (database type enforces)

### ActiveRecord Model

**File**: `app/models/legacy_redirect.rb`

**Validations**:
```ruby
validates :legacy_path, presence: true, uniqueness: { case_sensitive: false }
validates :target_slug, presence: true
validates :legacy_path, format: { with: %r{\A/product/}, message: "must start with /product/" }
validate :target_slug_exists
```

**Scopes**:
```ruby
scope :active, -> { where(active: true) }
scope :inactive, -> { where(active: false) }
scope :most_used, -> { order(hit_count: :desc) }
scope :recently_updated, -> { order(updated_at: :desc) }
```

**Class Methods**:
```ruby
# Find redirect by path (case-insensitive)
def self.find_by_path(path)
  where('LOWER(legacy_path) = ?', path.downcase).first
end

# Bulk import from array of hashes
def self.import_from_data(redirects_array)
  # Validates and creates multiple redirects
  # Returns { success: count, errors: [...] }
end
```

**Instance Methods**:
```ruby
# Increment hit counter (SQL-based, thread-safe)
def record_hit!
  increment!(:hit_count)
end

# Build target URL with query parameters
def target_url
  url = "/products/#{target_slug}"
  if variant_params.present?
    query_string = variant_params.to_query
    url += "?#{query_string}"
  end
  url
end

# Deactivate redirect (soft delete)
def deactivate!
  update!(active: false)
end

# Activate redirect
def activate!
  update!(active: true)
end
```

**Callbacks**: None (keep model simple)

**Associations**: None (self-contained entity)

### State Transitions

**States**: Active (true/false)

**Transitions**:
- **Created** → `active: true` (default state)
- **Active** → **Inactive**: Admin deactivates redirect
- **Inactive** → **Active**: Admin reactivates redirect
- **Any state** → **Deleted**: Admin permanently deletes mapping (rare)

**No complex state machine needed** - Simple boolean flag sufficient

### Data Integrity Rules

**Creation**:
- `legacy_path` must be unique (case-insensitive)
- `target_slug` must reference existing Product
- `variant_params` validated during creation (optional, can be empty)

**Updates**:
- `legacy_path` can be updated if new value is unique
- `target_slug` can be updated if new product exists
- `variant_params` can be modified at any time
- `hit_count` only modified via `record_hit!` method (not direct updates)

**Deletion**:
- Soft delete preferred (set `active: false`)
- Hard delete allowed via admin but discouraged (loses analytics)

**Concurrency**:
- `record_hit!` uses SQL increment (handles concurrent requests safely)
- Last-write-wins for other attributes (acceptable for admin operations)

### Example Records

```ruby
# Example 1: Pizza box with size parameter
LegacyRedirect.create!(
  legacy_path: '/product/12-310-x-310mm-pizza-box-kraft',
  target_slug: 'pizza-box-kraft',
  variant_params: { size: '12"' },
  active: true
)

# Example 2: Hot cup with size and colour
LegacyRedirect.create!(
  legacy_path: '/product/8oz-227ml-single-wall-paper-hot-cup-white',
  target_slug: 'single-wall-paper-hot-cup',
  variant_params: { size: '8oz', colour: 'White' },
  active: true
)

# Example 3: Generic product (no variant params)
LegacyRedirect.create!(
  legacy_path: '/product/straws-mixed',
  target_slug: 'paper-straws',
  variant_params: {},
  active: true
)

# Example 4: Inactive redirect (unmapped product)
LegacyRedirect.create!(
  legacy_path: '/product/old-item-discontinued',
  target_slug: 'eco-friendly-catering-supplies',  # Category fallback
  variant_params: {},
  active: false  # Deactivated until mapping confirmed
)
```

### Database Migration

**File**: `db/migrate/XXXXXX_create_legacy_redirects.rb`

```ruby
class CreateLegacyRedirects < ActiveRecord::Migration[8.0]
  def up
    create_table :legacy_redirects do |t|
      t.string :legacy_path, limit: 500, null: false
      t.string :target_slug, limit: 255, null: false
      t.jsonb :variant_params, default: {}, null: false
      t.integer :hit_count, default: 0, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    # Functional index for case-insensitive lookups
    add_index :legacy_redirects, 'LOWER(legacy_path)', unique: true, name: 'index_legacy_redirects_on_lower_legacy_path'

    # Index for filtering active redirects
    add_index :legacy_redirects, :active

    # Index for analytics queries (most used redirects)
    add_index :legacy_redirects, :hit_count
  end

  def down
    drop_table :legacy_redirects
  end
end
```

### Seed Data

**File**: `db/seeds/legacy_redirects.rb`

Contains 63 manually curated mappings from results.json:

```ruby
legacy_redirects = [
  {
    legacy_path: '/product/12-310-x-310mm-pizza-box-kraft',
    target_slug: 'pizza-box-kraft',
    variant_params: { size: '12"' }
  },
  {
    legacy_path: '/product/8oz-227ml-single-wall-paper-hot-cup-white',
    target_slug: 'single-wall-paper-hot-cup',
    variant_params: { size: '8oz', colour: 'White' }
  },
  # ... 61 more mappings
]

legacy_redirects.each do |data|
  LegacyRedirect.find_or_create_by!(legacy_path: data[:legacy_path]) do |redirect|
    redirect.target_slug = data[:target_slug]
    redirect.variant_params = data[:variant_params]
    redirect.active = true
  end
end

puts "✅ Seeded #{legacy_redirects.count} legacy redirects"
```

## Performance Considerations

**Query Optimization**:
- Functional index on `LOWER(legacy_path)` ensures O(1) lookups
- No N+1 queries possible (self-contained entity, no associations)
- Hit count increment uses single SQL UPDATE (no round-trip)

**Expected Load**:
- 1-10 redirects per second (low traffic assumption)
- Single database query per redirect request
- <5ms query time with proper indexing

**Scalability**:
- Table size: 63 rows initially, ~100-200 rows long-term
- Database size impact: <100KB (JSONB adds ~50 bytes per record)
- No caching needed initially (database is fast enough)
- Future optimization: In-memory cache (Redis) if redirects exceed 1000+

**Monitoring**:
- Track hit_count to identify high-value redirects
- Log slow queries (>50ms) for index optimization
- Monitor inactive redirects (candidates for deletion after 1 year)

## Data Quality & Maintenance

**Validation**:
- Admin interface validates target_slug exists before saving
- Bulk import validates all records before inserting (transaction)
- Logs warnings for variant_params that don't match product options

**Cleanup**:
- Inactive redirects with hit_count = 0 can be deleted after 3 months
- Redirects should remain active for minimum 1 year (SEO best practice)
- Rake task to identify unused redirects: `rails legacy_redirects:report_unused`

**Auditing**:
- `created_at` and `updated_at` track changes
- Consider adding `last_hit_at` timestamp for analytics (optional future enhancement)
- Admin activity logged via Rails logs (who created/modified redirects)

## Summary

**Entity**: `LegacyRedirect`
**Table**: `legacy_redirects`
**Attributes**: 8 (id, legacy_path, target_slug, variant_params, hit_count, active, timestamps)
**Indexes**: 4 (primary key, unique LOWER(legacy_path), active, hit_count)
**Relationships**: None (standalone entity)
**Complexity**: Low (simple CRUD model with analytics counter)
