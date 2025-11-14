# Quickstart: Legacy URL Redirects

**Feature**: 001-legacy-url-redirects
**Date**: 2025-11-14

## Overview

Quick reference guide for seeding and managing legacy URL redirects.

## Prerequisites

- Rails 8 application running
- PostgreSQL database accessible
- CSV mapping file at `config/legacy_redirects.csv`
- Product data already seeded in database

## Step 1: Run Database Migration

```bash
# Check if migration has been run
rails db:migrate:status | grep legacy_redirects

# Run migration if needed
rails db:migrate
```

**Expected Output**:
```
== CreateLegacyRedirects: migrating =====================
-- create_table(:legacy_redirects)
-- add_index(:legacy_redirects, "LOWER(legacy_path)", {:unique=>true, :name=>"index_legacy_redirects_on_lower_legacy_path"})
-- add_index(:legacy_redirects, :active)
-- add_index(:legacy_redirects, :hit_count)
== CreateLegacyRedirects: migrated ====================
```

## Step 2: Seed Redirect Data

```bash
# Run all seeds (includes legacy redirects)
rails db:seed

# OR run just legacy redirects seed
rails runner "load Rails.root.join('db/seeds/legacy_redirects.rb')"
```

**Expected Output**:
```
Seeding legacy redirects...
✅ Seeded 64 legacy redirects
   Active: 64
   Total: 64
```

## Step 3: Verify Seed Data

```bash
# Check redirect count
rails runner "puts LegacyRedirect.count"
# Expected: 64

# List first 5 redirects
rails runner "puts LegacyRedirect.limit(5).pluck(:legacy_path, :target_slug)"

# Verify all target products exist
rails runner "
  missing = LegacyRedirect.where.not(
    target_slug: Product.pluck(:slug)
  ).pluck(:target_slug).uniq
  puts missing.any? ? 'ERROR: Missing products: ' + missing.join(', ') : '✅ All products exist'
"
```

## Step 4: Run Tests

```bash
# Run all redirect-related tests
rails test test/models/legacy_redirect_test.rb
rails test test/middleware/legacy_redirect_middleware_test.rb
rails test test/controllers/admin/legacy_redirects_controller_test.rb
rails test test/integration/legacy_redirect_flow_test.rb
rails test test/system/legacy_redirect_system_test.rb

# Or run all tests at once
rails test
```

**Expected**: All tests pass (green)

## Step 5: Manual Testing in Browser

```bash
# Start development server
bin/dev
```

Visit these sample URLs in browser:

1. **Pizza box redirect**:
   - Legacy URL: `http://localhost:3000/product/12-310-x-310mm-pizza-box-kraft`
   - Expected: 301 redirect to `/products/pizza-box?size=12in&colour=kraft`
   - Verify: Product page shows correct variant pre-selected

2. **Hot cup redirect**:
   - Legacy URL: `http://localhost:3000/product/8oz-227ml-single-wall-paper-hot-cup-white`
   - Expected: 301 redirect to `/products/single-wall-paper-hot-cup?size=8oz&colour=white`

3. **Straw redirect**:
   - Legacy URL: `http://localhost:3000/product/6mm-x-200mm-bamboo-fibre-straws-black`
   - Expected: 301 redirect to `/products/bio-fibre-straws?size=6x200mm&colour=black`

**Verification Checklist**:
- [ ] Browser shows 301 status in Network tab
- [ ] URL changes to new product page
- [ ] Correct variant is pre-selected (check size/colour dropdowns)
- [ ] Add to cart works with selected variant
- [ ] Hit count increments in database

## Step 6: Check Hit Counts

```bash
# View redirects with hit counts
rails runner "
  LegacyRedirect.most_used.limit(10).each do |r|
    puts '#{r.legacy_path} → #{r.target_slug} (#{r.hit_count} hits)'
  end
"
```

## Common Commands

### View All Redirects

```bash
rails runner "
  LegacyRedirect.order(:legacy_path).each do |r|
    params = r.variant_params.present? ? '?' + r.variant_params.to_query : ''
    puts '#{r.legacy_path} → /products/#{r.target_slug}#{params}'
  end
"
```

### Find Redirect by Legacy Path

```bash
rails runner "
  redirect = LegacyRedirect.find_by_path('/product/12-310-x-310mm-pizza-box-kraft')
  puts redirect.inspect
"
```

### Deactivate a Redirect

```bash
rails runner "
  redirect = LegacyRedirect.find_by_path('/product/some-legacy-url')
  redirect.deactivate!
  puts 'Deactivated'
"
```

### Reactivate a Redirect

```bash
rails runner "
  redirect = LegacyRedirect.find_by_path('/product/some-legacy-url')
  redirect.activate!
  puts 'Reactivated'
"
```

### Add a New Redirect Manually

```bash
rails runner "
  LegacyRedirect.create!(
    legacy_path: '/product/new-legacy-url',
    target_slug: 'target-product-slug',
    variant_params: { size: '12oz', colour: 'white' },
    active: true
  )
  puts 'Created'
"
```

## Rake Tasks

### Import Redirects from CSV

```bash
rails legacy_redirects:import
```

### Export Redirects to CSV

```bash
rails legacy_redirects:export
```

### Validate All Redirects

```bash
rails legacy_redirects:validate
```

**Checks**:
- All target products exist
- No duplicate legacy paths
- All redirects have valid format

### Reset Hit Counts

```bash
rails legacy_redirects:reset_counts
```

## Admin Interface

Access admin interface for managing redirects:

```
http://localhost:3000/admin/legacy_redirects
```

**Features**:
- View all redirects with hit counts
- Search/filter redirects
- Create new redirects
- Edit existing redirects
- Activate/deactivate redirects
- Delete redirects
- Bulk import from CSV

## Troubleshooting

### Redirect Not Working

**Problem**: Legacy URL returns 404 instead of redirecting

**Solutions**:
1. Check redirect exists and is active:
   ```bash
   rails runner "puts LegacyRedirect.find_active_by_path('/product/your-url').inspect"
   ```

2. Verify middleware is registered:
   ```bash
   grep -r "LegacyRedirectMiddleware" config/
   ```

3. Check middleware order:
   ```bash
   rails middleware
   # Should see LegacyRedirectMiddleware before ActionDispatch::Routing
   ```

### Product Not Found Error

**Problem**: Seed fails with "target_slug product not found"

**Solutions**:
1. Ensure products are seeded first:
   ```bash
   rails db:seed  # Seeds products before redirects
   ```

2. Check which products are missing:
   ```bash
   rails runner "
     csv_slugs = CSV.read('config/legacy_redirects.csv', headers: true)
       .map { |row| URI.parse(row['target']).path.sub('/products/', '') }.uniq
     missing = csv_slugs - Product.pluck(:slug)
     puts 'Missing products: ' + missing.join(', ')
   "
   ```

3. Add missing products or update CSV to use existing product slugs

### Variant Not Pre-Selected

**Problem**: Redirect works but variant not showing on product page

**Solutions**:
1. Check variant parameter names match product variant options
2. Verify JavaScript variant selector is working
3. Check browser console for errors
4. Ensure variant_params format is correct:
   ```bash
   rails runner "puts LegacyRedirect.find_by_path('/product/your-url').variant_params"
   # Should output: {"size"=>"12oz", "colour"=>"white"}
   ```

### Case Sensitivity Issues

**Problem**: Redirect works for lowercase but not mixed case

**Solution**: Index handles case-insensitivity automatically. Verify:
```bash
# Both should work:
curl -I http://localhost:3000/product/pizza-box
curl -I http://localhost:3000/product/Pizza-Box
```

## Performance Monitoring

### Check Redirect Response Times

```bash
# In development log (log/development.log)
grep "LegacyRedirectMiddleware" log/development.log | tail -20
```

### Benchmark a Redirect

```ruby
# In rails console
require 'benchmark'

Benchmark.ms do
  100.times do
    LegacyRedirect.find_active_by_path('/product/12-310-x-310mm-pizza-box-kraft')
  end
end
# Expected: < 100ms for 100 lookups (< 1ms per lookup)
```

## Deployment Checklist

Before deploying to production:

- [ ] All tests passing
- [ ] Seed data validated (no missing products)
- [ ] Sample redirects tested in staging
- [ ] Admin authentication enabled
- [ ] Database migration run in staging
- [ ] Performance benchmarks acceptable (<500ms redirect time)
- [ ] Rollback plan documented

## Rollback Procedure

If redirects cause issues in production:

1. **Disable all redirects** (fastest):
   ```bash
   rails runner "LegacyRedirect.update_all(active: false)"
   ```

2. **Remove middleware** (requires deployment):
   - Comment out middleware registration in `config/initializers/legacy_redirect_middleware.rb`
   - Deploy

3. **Full rollback** (destructive):
   ```bash
   rails db:rollback
   # This drops the legacy_redirects table
   ```

## Support

- **Documentation**: See `specs/001-legacy-url-redirects/` directory
- **Tests**: See `test/` directory for examples
- **Model**: See `app/models/legacy_redirect.rb` for business logic
- **Middleware**: See `app/middleware/legacy_redirect_middleware.rb` for request handling
