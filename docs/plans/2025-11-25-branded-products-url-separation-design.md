# Branded Products URL Separation

**Date**: 2025-11-25
**Status**: Approved
**Author**: Design collaboration with user

## Overview & Goals

### Objective
Separate branded products (`product_type: "customizable_template"`) into their own URL namespace at `/branded-products` while keeping them excluded from the standard shop catalog.

### Why This Matters
- **SEO clarity**: Search engines see branded products as distinct from regular products
- **User experience**: Clear separation between "buy now" products and "customize & order" products
- **Organization**: Branded products have different pricing (quantity-based), workflows (configurator), and business logic

### What Changes
1. Routes: Add `resources :branded_products` with hyphenated path
2. Shop page: Exclude branded products using a new scope
3. Views: Replace hardcoded URLs with path helpers
4. Cleanup: Remove obsolete category shortcut

### What Stays the Same
- BrandedProductsController already exists and works
- Views already use the right path helpers
- API endpoints under `/branded_products` namespace remain unchanged

## Routing Changes

### Current State
`config/routes.rb` line 29:
```ruby
get "branded-products", to: "categories#show", defaults: { id: "branded-products" }
```

This shortcut points to the categories controller, which isn't what we want.

### New State
Add after line 26:
```ruby
resources :branded_products, only: [:index, :show], path: "branded-products", param: :slug
```

### Why This Structure
- `only: [:index, :show]` - Only need listing and detail pages
- `path: "branded-products"` - Hyphenated URLs (matches site convention)
- `param: :slug` - Uses slugs like regular products (e.g., `/branded-products/custom-hot-cups`)

### Generated Routes
- `GET /branded-products` → `branded_products#index` (listing page)
- `GET /branded-products/:slug` → `branded_products#show` (configurator page)

### Path Helpers
- `branded_products_path` → `/branded-products`
- `branded_product_path(product)` → `/branded-products/custom-hot-cups`

### What Gets Removed
- Line 29 shortcut to categories controller (no longer needed)

### API Endpoints
Lines 47-51 stay untouched - they're at `/branded_products/*` (underscore) for API calls, while public pages are at `/branded-products/*` (hyphen).

## Shop Page Filtering

### Problem
The shop page (`/shop`) currently shows ALL active products, including branded products. We want standard catalog products only.

### Solution
Add a new scope to filter by product type, then use it in the shop action.

### New Scope in Product Model
Add after line 32 in `app/models/product.rb`:
```ruby
scope :standard, -> { where(product_type: "standard") }
```

### Why This Scope
- Clear and concise: "standard" means non-customizable shop products
- Reusable: Could be useful elsewhere (feeds, sitemaps, etc.)
- Distinct from `quick_add_eligible`: That's about modal behavior, this is about catalog visibility

### Update PagesController#shop
Line 29 in `app/controllers/pages_controller.rb`, chain the scope:
```ruby
@products = Product
  .standard  # <- Add this line
  .includes(:active_variants,
            product_photo_attachment: :blob,
            lifestyle_photo_attachment: :blob)
```

### Effect
- Shop page shows only `product_type: "standard"` products
- Branded products remain accessible at `/branded-products`
- Categories, search, and sorting continue to work as before

## View Updates

### Current Issue
Two places have hardcoded `/branded-products` URLs that should use the path helper.

### File: `app/views/shared/_navbar.html.erb`

**Line 19** (desktop nav):
```ruby
# Change from:
<li class="text-lg font-medium"><%= link_to "Branded Products", "/branded-products", class: "..." %></li>

# To:
<li class="text-lg font-medium"><%= link_to "Branded Products", branded_products_path, class: "..." %></li>
```

**Line 30** (mobile nav):
```ruby
# Change from:
<li class="text-lg font-medium"><%= link_to "Branded Products", "/branded-products", class: "..." %></li>

# To:
<li class="text-lg font-medium"><%= link_to "Branded Products", branded_products_path, class: "..." %></li>
```

### Why This Matters
- Path helpers update automatically if routes change
- Prevents broken links
- Consistent with rest of the codebase

### Everything Else Already Works
- `app/views/pages/partials/_branding.html.erb` already uses `branded_products_path`
- `app/views/shared/_footer.html.erb` already uses `branded_products_path`
- `app/views/branded_products/_branded_product.html.erb` already uses `branded_product_path(product)`

## Implementation Summary

### Complete Change List

1. **config/routes.rb**:
   - Add `resources :branded_products, only: [:index, :show], path: "branded-products", param: :slug` after line 26
   - Remove line 29 (old category shortcut)

2. **app/models/product.rb**:
   - Add `scope :standard, -> { where(product_type: "standard") }` after line 32

3. **app/controllers/pages_controller.rb**:
   - Add `.standard` to the Product query chain in the `shop` action (line 29)

4. **app/views/shared/_navbar.html.erb**:
   - Replace `/branded-products` with `branded_products_path` on lines 19 and 30

### Testing Considerations

**Manual testing**:
- Visit `/branded-products` - should show branded product listing
- Visit `/branded-products/[slug]` - should show configurator
- Visit `/shop` - should NOT show branded products
- Check navbar links work correctly

**No broken functionality**:
- API endpoints at `/branded_products/*` unaffected
- Existing branded product views already use correct helpers
- BrandedProductsController doesn't need changes

### Edge Cases Handled
- Products with `product_type: "customized_instance"` remain excluded from both shop and branded pages (as intended)
- Default scope on Product still applies (only active products)
- Search, filtering, sorting on shop page continue to work
