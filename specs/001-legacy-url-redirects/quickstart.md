# Quick Start Guide: Legacy URL Smart Redirects

**Feature**: 001-legacy-url-redirects
**Date**: 2025-11-13
**For**: Developers implementing this feature

## Overview

This feature implements a database-driven redirect system that intercepts legacy product URLs from the old afida.com site and redirects them to the new product structure with extracted variant parameters.

## Prerequisites

- Rails 8.x application running
- PostgreSQL 14+ database
- Existing product catalog with slugs
- Admin authentication already implemented
- `results.json` file with 63 legacy URLs available

## Quick Setup (5 Minutes)

### 1. Create Migration

```bash
rails generate migration CreateLegacyRedirects
```

Edit the generated migration file (`db/migrate/XXXXXX_create_legacy_redirects.rb`):

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

    add_index :legacy_redirects, 'LOWER(legacy_path)', unique: true, name: 'index_legacy_redirects_on_lower_legacy_path'
    add_index :legacy_redirects, :active
    add_index :legacy_redirects, :hit_count
  end

  def down
    drop_table :legacy_redirects
  end
end
```

Run migration:

```bash
rails db:migrate
```

### 2. Create Model

Create `app/models/legacy_redirect.rb`:

```ruby
class LegacyRedirect < ApplicationRecord
  # Validations
  validates :legacy_path, presence: true, uniqueness: { case_sensitive: false }
  validates :target_slug, presence: true
  validates :legacy_path, format: { with: %r{\A/product/}, message: "must start with /product/" }
  validate :target_slug_exists

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :most_used, -> { order(hit_count: :desc) }
  scope :recently_updated, -> { order(updated_at: :desc) }

  # Class methods
  def self.find_by_path(path)
    where('LOWER(legacy_path) = ?', path.downcase).first
  end

  # Instance methods
  def record_hit!
    increment!(:hit_count)
  end

  def target_url
    url = "/products/#{target_slug}"
    if variant_params.present?
      query_string = variant_params.to_query
      url += "?#{query_string}"
    end
    url
  end

  def deactivate!
    update!(active: false)
  end

  def activate!
    update!(active: true)
  end

  private

  def target_slug_exists
    return if target_slug.blank?
    unless Product.exists?(slug: target_slug)
      errors.add(:target_slug, "product not found")
    end
  end
end
```

### 3. Create Middleware

Create `app/middleware/legacy_redirect_middleware.rb`:

```ruby
class LegacyRedirectMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    return @app.call(env) unless %w[GET HEAD].include?(request.method)
    return @app.call(env) unless request.path.start_with?('/product/')

    normalized_path = request.path.chomp('/')
    redirect = LegacyRedirect.active.find_by_path(normalized_path)

    return @app.call(env) unless redirect

    increment_hit_counter(redirect)
    target_url = build_target_url(redirect, request)

    [301, redirect_headers(target_url), ['Redirecting...']]
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid => e
    Rails.logger.error("LegacyRedirectMiddleware: #{e.class} - #{e.message}")
    @app.call(env)
  end

  private

  def increment_hit_counter(redirect)
    redirect.record_hit!
  rescue => e
    Rails.logger.warn("LegacyRedirectMiddleware: Hit counter update failed - #{e.message}")
  end

  def build_target_url(redirect, request)
    url = "/products/#{redirect.target_slug}"

    all_params = redirect.variant_params.dup || {}
    if request.query_string.present?
      existing_params = Rack::Utils.parse_query(request.query_string)
      all_params.merge!(existing_params)
    end

    url += "?#{Rack::Utils.build_query(all_params)}" if all_params.present?
    url
  end

  def redirect_headers(location)
    {
      'Location' => location,
      'Content-Type' => 'text/html; charset=utf-8',
      'Cache-Control' => 'public, max-age=86400'
    }
  end
end
```

### 4. Register Middleware

Edit `config/application.rb`:

```ruby
module Shop
  class Application < Rails::Application
    # ... existing config

    # Register legacy redirect middleware
    config.middleware.use LegacyRedirectMiddleware
  end
end
```

### 5. Add Admin Routes

Edit `config/routes.rb`:

```ruby
namespace :admin do
  # ... existing admin routes

  resources :legacy_redirects do
    member do
      patch :toggle
      get :test
    end
    collection do
      post :import
    end
  end
end
```

### 6. Test It!

Create a test redirect in Rails console:

```bash
rails console
```

```ruby
LegacyRedirect.create!(
  legacy_path: '/product/test-redirect',
  target_slug: 'pizza-box-kraft',
  variant_params: { size: '12"' },
  active: true
)
```

Start the server and test:

```bash
rails server
```

Visit: `http://localhost:3000/product/test-redirect`

You should be redirected to: `http://localhost:3000/products/pizza-box-kraft?size=12%22`

## Next Steps (Complete Implementation)

### 1. Implement Admin Controller

See `contracts/admin_interface.md` for full specification.

Create `app/controllers/admin/legacy_redirects_controller.rb` with standard CRUD operations.

### 2. Implement Admin Views

Create views in `app/views/admin/legacy_redirects/`:
- `index.html.erb` - List all redirects
- `new.html.erb` - Create new redirect
- `edit.html.erb` - Edit existing redirect
- `_form.html.erb` - Shared form partial

### 3. Seed Initial Data

Create `db/seeds/legacy_redirects.rb` with 63 mappings from `results.json`:

```ruby
legacy_redirects = [
  {
    legacy_path: '/product/12-310-x-310mm-pizza-box-kraft',
    target_slug: 'pizza-box-kraft',
    variant_params: { size: '12"' }
  },
  # ... 62 more mappings
]

legacy_redirects.each do |data|
  LegacyRedirect.find_or_create_by!(legacy_path: data[:legacy_path]) do |redirect|
    redirect.target_slug = data[:target_slug]
    redirect.variant_params = data[:variant_params]
    redirect.active = true
  end
end
```

Load seeds:

```bash
rails db:seed
```

### 4. Write Tests

**Model Test** (`test/models/legacy_redirect_test.rb`):
- Test validations
- Test scopes
- Test `find_by_path` method
- Test `record_hit!` method
- Test `target_url` method

**Middleware Test** (`test/middleware/legacy_redirect_middleware_test.rb`):
- Test redirect behavior
- Test case insensitivity
- Test query parameter preservation
- Test error handling

**Controller Test** (`test/controllers/admin/legacy_redirects_controller_test.rb`):
- Test CRUD operations
- Test authentication
- Test validation errors

**Integration Test** (`test/integration/legacy_redirect_flow_test.rb`):
- Test end-to-end redirect flow
- Test hit counter increment

**System Test** (`test/system/legacy_redirect_system_test.rb`):
- Test browser redirect
- Test admin UI

Run tests:

```bash
rails test
```

### 5. Verify with RuboCop and Brakeman

```bash
rubocop
brakeman
```

## Common Tasks

### Add a New Redirect

**Via Rails Console**:
```ruby
LegacyRedirect.create!(
  legacy_path: '/product/new-legacy-url',
  target_slug: 'new-product-slug',
  variant_params: { size: '8oz' },
  active: true
)
```

**Via Admin UI**:
1. Navigate to `/admin/legacy_redirects`
2. Click "New Redirect"
3. Fill in form and submit

### View Redirect Statistics

**Via Rails Console**:
```ruby
# Most used redirects
LegacyRedirect.active.most_used.limit(10)

# Recently updated redirects
LegacyRedirect.recently_updated.limit(10)

# Total redirects
LegacyRedirect.count
LegacyRedirect.active.count

# Total hits
LegacyRedirect.sum(:hit_count)
```

**Via Admin UI**:
Navigate to `/admin/legacy_redirects` to see full list with statistics.

### Deactivate a Redirect

**Via Rails Console**:
```ruby
redirect = LegacyRedirect.find_by_path('/product/old-url')
redirect.deactivate!
```

**Via Admin UI**:
1. Navigate to `/admin/legacy_redirects`
2. Click "Toggle" button next to redirect

### Bulk Import from JSON

Create a JSON file (`legacy_redirects.json`):

```json
[
  {
    "legacy_path": "/product/item-1",
    "target_slug": "product-1",
    "variant_params": {"size": "12\""},
    "active": true
  }
]
```

Import via Rails console:

```ruby
data = JSON.parse(File.read('legacy_redirects.json'))
data.each do |item|
  LegacyRedirect.find_or_create_by!(legacy_path: item['legacy_path']) do |redirect|
    redirect.target_slug = item['target_slug']
    redirect.variant_params = item['variant_params']
    redirect.active = item['active']
  end
end
```

## Troubleshooting

### Redirect Not Working

1. **Check middleware is registered**:
   ```bash
   rails middleware
   ```
   Look for `LegacyRedirectMiddleware` in the list

2. **Check redirect exists and is active**:
   ```ruby
   LegacyRedirect.active.find_by_path('/product/your-url')
   ```

3. **Check database index**:
   ```bash
   rails dbconsole
   \d legacy_redirects
   ```
   Verify `index_legacy_redirects_on_lower_legacy_path` exists

4. **Check logs**:
   ```bash
   tail -f log/development.log
   ```
   Look for middleware errors

### Performance Issues

1. **Check database query time**:
   ```ruby
   require 'benchmark'
   Benchmark.ms { LegacyRedirect.active.find_by_path('/product/test') }
   ```
   Should be <5ms

2. **Verify index is being used**:
   ```sql
   EXPLAIN ANALYZE SELECT * FROM legacy_redirects WHERE LOWER(legacy_path) = '/product/test';
   ```
   Should show "Index Scan" not "Seq Scan"

3. **Monitor hit counter updates**:
   If hit counter updates are slow, they won't block redirects (fire-and-forget pattern)

### Admin UI Not Accessible

1. **Check authentication**:
   Verify you're logged in as admin

2. **Check routes**:
   ```bash
   rails routes | grep legacy_redirects
   ```

3. **Check controller exists**:
   ```bash
   ls app/controllers/admin/legacy_redirects_controller.rb
   ```

## Deployment Checklist

- [ ] Migration has been run on production database
- [ ] Seed data has been loaded (63 legacy redirects)
- [ ] Middleware is registered in `config/application.rb`
- [ ] Admin controller and views implemented
- [ ] All tests passing
- [ ] RuboCop passing
- [ ] Brakeman passing
- [ ] Performance tested (<10ms overhead)
- [ ] Admin authentication verified
- [ ] Redirects manually tested in staging
- [ ] Google Search Console notified of URL changes
- [ ] Monitoring set up for redirect hit counts

## Resources

- **Spec**: [spec.md](./spec.md)
- **Research**: [research.md](./research.md)
- **Data Model**: [data-model.md](./data-model.md)
- **Admin Interface Contract**: [contracts/admin_interface.md](./contracts/admin_interface.md)
- **Middleware Contract**: [contracts/middleware_interface.md](./contracts/middleware_interface.md)

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review contracts and data model documentation
3. Check Rails logs for errors
4. Test in Rails console first
5. Verify database indexes and queries
