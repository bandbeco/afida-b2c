# Quickstart: Variant-Level Product Pages

**Date**: 2026-01-10
**Feature**: 001-variant-pages

## Overview

This guide provides quick instructions for implementing the variant-level product pages feature. Follow the tasks in `/speckit.tasks` for detailed implementation order.

---

## Prerequisites

- Ruby 3.4.7, Rails 8.1.1
- PostgreSQL 14+ running
- Node.js 18+ (for Vite)
- Development environment set up (`bin/setup`)

---

## Quick Setup

### 1. Run Migrations

```bash
rails db:migrate
```

Three migrations will run:
1. Add `slug` column to `product_variants`
2. Add `search_vector` tsvector column with trigger
3. Populate slugs for existing variants

### 2. Verify Slugs Generated

```bash
rails runner "puts ProductVariant.first(5).pluck(:slug)"
```

Expected output: slugs like `8oz-single-wall-white-coffee-cups`

### 3. Run Tests

```bash
rails test
```

All tests should pass after implementation.

---

## Key Files to Create

### Controllers

| File | Purpose |
|------|---------|
| `app/controllers/product_variants_controller.rb` | Variant page show action |
| `app/controllers/search_controller.rb` | Header search endpoint |

### Views

| File | Purpose |
|------|---------|
| `app/views/product_variants/show.html.erb` | Variant page template |
| `app/views/products/_variant_card.html.erb` | Card partial for grids |
| `app/views/search/_results.html.erb` | Search dropdown partial |
| `app/views/shared/_filters.html.erb` | Shop page filters |

### JavaScript (Stimulus)

| File | Purpose |
|------|---------|
| `app/frontend/javascript/controllers/search_controller.js` | Header search |
| `app/frontend/javascript/controllers/filters_controller.js` | Shop page filters |

### Tests

| File | Purpose |
|------|---------|
| `test/models/product_variant_test.rb` | Slug and search tests |
| `test/controllers/product_variants_controller_test.rb` | Variant page tests |
| `test/controllers/search_controller_test.rb` | Search tests |
| `test/system/variant_page_test.rb` | E2E variant page |
| `test/system/shop_page_test.rb` | E2E shop with filters |

---

## Route Changes

Add to `config/routes.rb`:

```ruby
get 'search', to: 'search#index'
get 'products/:slug', to: 'product_variants#show', as: :product_variant
```

---

## Testing Locally

### View a Variant Page

```bash
rails server
# Visit: http://localhost:3000/products/8oz-single-wall-white-coffee-cups
```

### Test Search

```bash
# Visit: http://localhost:3000/search?q=coffee
```

### Test Shop with Filters

```bash
# Visit: http://localhost:3000/shop?category=cups-and-lids&size=8oz
```

---

## Verification Checklist

- [ ] Variant slugs generated for all ~85 variants
- [ ] Variant pages load with correct SEO meta tags
- [ ] Shop page shows variant cards (not product cards)
- [ ] Header search returns results
- [ ] Filters narrow results correctly
- [ ] "See also" shows related variants
- [ ] Add to cart works from variant page
- [ ] All tests pass
- [ ] RuboCop passes

---

## Common Issues

### Slug Collisions
If migration fails due to duplicate slugs, check for variants with identical names under the same product. The migration handles this with counter suffixes.

### Search Not Working
Ensure the Postgres trigger was created:
```sql
SELECT * FROM pg_trigger WHERE tgname = 'product_variants_search_update';
```

### Filters Not Updating URL
Check that `filters_controller.js` is registered in `application.js` lazy controllers.

---

## Related Documents

- [Specification](./spec.md) - Feature requirements
- [Research](./research.md) - Technical decisions
- [Data Model](./data-model.md) - Schema changes
- [API Contracts](./contracts/api.md) - Endpoint definitions
