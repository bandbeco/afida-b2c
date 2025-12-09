# N+1 Query Prevention Strategy

This document outlines our multi-layered approach to preventing N+1 queries from reaching production.

## What are N+1 Queries?

N+1 queries occur when you load a collection of records and then access an association for each record, triggering a separate database query for each item in the collection.

**Example of N+1:**
```ruby
# BAD: N+1 query
products = Product.all  # 1 query
products.each do |product|
  puts product.category.name  # N additional queries (one per product)
end

# GOOD: Eager loading
products = Product.includes(:category).all  # 2 queries total
products.each do |product|
  puts product.category.name  # No additional queries
end
```

## Our Prevention Strategy

### 1. Development Environment Detection

**Tool:** Bullet gem
**When:** During local development
**How:** Visual warnings in browser

The Bullet gem is configured to detect N+1 queries in development and display warnings:
- Browser footer notifications
- Rails logger output
- Bullet logger file

**Configuration:** `config/initializers/bullet.rb` (development section)

**What to do when you see a warning:**
1. Review the warning message
2. Add appropriate `includes()`, `preload()`, or `eager_load()` to your query
3. Verify the warning disappears
4. Commit the fix

### 2. Test Environment Enforcement

**Tool:** Bullet gem with `raise: true`
**When:** Running test suite
**How:** Tests fail with N+1 errors

The Bullet gem is configured to **raise exceptions** in the test environment, making tests fail when N+1 queries are detected.

**Configuration:** `config/initializers/bullet.rb` (test section)

**Key points:**
- Any N+1 query will cause test failure
- Prevents committing code with N+1 issues
- Works with both unit and system tests

### 3. CI/CD Pipeline

**Tool:** GitHub Actions running test suite
**When:** On pull requests and main branch pushes
**How:** CI fails if tests fail due to N+1 queries

Your CI workflow at `.github/workflows/ci.yml` automatically:
1. Runs the full test suite
2. Bullet raises errors on N+1 queries
3. CI pipeline fails, preventing merge

**No additional configuration needed** - it works automatically because tests fail.

### 4. Pre-commit Hook

**Tool:** Git pre-commit hook
**When:** Before each commit
**How:** Runs RuboCop to catch code style issues

While not specifically for N+1 queries, the pre-commit hook maintains code quality standards.

**Installation:** See `bin/git-hooks/README.md`

### 5. Test Helpers for Explicit Checks

**Tool:** Custom test helpers
**When:** Writing tests for query-heavy features
**How:** Explicit assertions in tests

We provide test helpers for explicitly checking N+1 queries:

```ruby
# Assert no N+1 queries in a block
test "products index page has no N+1 queries" do
  assert_no_n_plus_one_queries do
    get products_path
    @products = assigns(:products)
    @products.each { |p| p.category.name }
  end
end

# Assert specific query count
test "loads products with exactly 2 queries" do
  assert_queries(2) do
    Product.includes(:category).limit(10).each do |p|
      p.category.name
    end
  end
end
```

**Available helpers:**
- `assert_no_n_plus_one_queries` - Fails if any N+1 queries detected
- `assert_queries(count)` - Fails if query count doesn't match

**Location:** `test/support/n_plus_one_helpers.rb`

## Common Patterns to Avoid N+1

### 1. Eager Loading with includes()

```ruby
# Use includes() for associations you'll access
Product.includes(:category, :variants)

# For multiple levels
Product.includes(variants: :image_attachment)

# For multiple associations
Product.includes(:category, variants: [:image_attachment, :product])
```

### 2. Conditional Eager Loading

```ruby
# Different associations based on product type
if product.customizable_template?
  Product.includes(:category, :branded_product_prices, image_attachment: :blob)
else
  Product.includes(:category, active_variants: { image_attachment: :blob })
end
```

### 3. Using Preloaded Data

Avoid methods that bypass eager loading:

```ruby
# BAD: .pluck() always triggers SQL
@product.branded_product_prices.pluck(:size)

# GOOD: Use preloaded data
@product.branded_product_prices.map(&:size)

# BAD: .minimum() always triggers SQL
@product.branded_product_prices.minimum(:price)

# GOOD: Use preloaded data
@product.branded_product_prices.map(&:price).min

# BAD: .where() on preloaded association triggers SQL
@product.variants.where(active: true)

# GOOD: Use select on preloaded data (or use a scope)
@product.variants.select(&:active)
```

### 4. Counter Cache

For frequently counted associations:

```ruby
# Add to migration
add_column :products, :variants_count, :integer, default: 0

# In model
class Variant < ApplicationRecord
  belongs_to :product, counter_cache: true
end

# Now this doesn't query:
product.variants.count  # Uses counter cache
```

## How to Fix N+1 Queries

### Step 1: Identify the Issue

Bullet will tell you:
- Which model has the problem
- Which association is being accessed without eager loading
- The exact line of code causing the issue

### Step 2: Add Eager Loading

Add `includes()` to the query:

```ruby
# Before
@products = Product.all

# After
@products = Product.includes(:category)
```

### Step 3: Test the Fix

1. Reload the page in development - Bullet warning should disappear
2. Run your tests - they should pass
3. Check the Rails log - should see reduced query count

### Step 4: Optimize Further

Review the SQL queries:
- Are all eager-loaded associations used?
- Are there still N+1 queries in nested associations?
- Can you use `preload()` or `eager_load()` for better performance?

## Monitoring in Production

While we prevent N+1 queries from reaching production, you can also monitor:

1. **APM Tools** (if/when added):
   - New Relic
   - Scout APM
   - Skylight

2. **Query Performance**:
   - Check `production.log` for slow queries
   - Monitor database query counts per request

## Summary

**Prevention Layers:**
1. ✅ Development warnings (Bullet gem)
2. ✅ Test failures (Bullet gem with raise: true)
3. ✅ CI/CD enforcement (GitHub Actions)
4. ✅ Test helpers for explicit checks
5. ✅ Code review and best practices

**Result:** N+1 queries are caught before they reach production through multiple automated checks.
