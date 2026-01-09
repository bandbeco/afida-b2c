# Tasks: Variant-Level Product Pages

**Feature**: 001-variant-pages
**Generated**: 2026-01-10
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Overview

Implementation tasks for variant-level product pages. Tasks are organized by phase and user story priority.

---

## Phase 1: Setup & Foundation

### Task 1.1: Create feature branch and update fixtures
- [x] Ensure on `001-variant-pages` branch
- [x] Update `test/fixtures/product_variants.yml` to include `slug` field for all fixtures
- [x] Verify fixtures pass existing tests

**Files**: `test/fixtures/product_variants.yml`
**Dependencies**: None

---

### Task 1.2: Add slug column to product_variants
- [x] Generate migration: `rails g migration AddSlugToProductVariants`
- [x] Add `slug` column (string, 255 chars)
- [x] Add unique index on `slug`
- [x] Run migration

**Migration content**:
```ruby
class AddSlugToProductVariants < ActiveRecord::Migration[8.1]
  def change
    add_column :product_variants, :slug, :string, limit: 255
    add_index :product_variants, :slug, unique: true
  end
end
```

**Files**: `db/migrate/XXXXXX_add_slug_to_product_variants.rb`
**Dependencies**: Task 1.1

---

### Task 1.3: Add search_vector column with trigger
- [x] Generate migration: `rails g migration AddSearchVectorToProductVariants`
- [x] Add `search_vector` tsvector column
- [x] Add GIN index for full-text search
- [x] Create Postgres trigger function
- [x] Create trigger on INSERT/UPDATE
- [x] Backfill existing records

**Migration content** (see `data-model.md` for full SQL):
```ruby
class AddSearchVectorToProductVariants < ActiveRecord::Migration[8.1]
  def up
    add_column :product_variants, :search_vector, :tsvector
    add_index :product_variants, :search_vector, using: :gin

    execute <<-SQL
      CREATE OR REPLACE FUNCTION product_variants_search_trigger() RETURNS trigger AS $$
      BEGIN
        NEW.search_vector :=
          setweight(to_tsvector('english', coalesce(NEW.name, '')), 'A') ||
          setweight(to_tsvector('english', coalesce(NEW.sku, '')), 'B');
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER product_variants_search_update
      BEFORE INSERT OR UPDATE ON product_variants
      FOR EACH ROW EXECUTE FUNCTION product_variants_search_trigger();
    SQL

    # Backfill existing records
    ProductVariant.find_each(&:touch)
  end

  def down
    execute <<-SQL
      DROP TRIGGER IF EXISTS product_variants_search_update ON product_variants;
      DROP FUNCTION IF EXISTS product_variants_search_trigger();
    SQL
    remove_column :product_variants, :search_vector
  end
end
```

**Files**: `db/migrate/XXXXXX_add_search_vector_to_product_variants.rb`
**Dependencies**: Task 1.2

---

### Task 1.4: Populate slugs for existing variants
- [x] Generate data migration: `rails g migration PopulateProductVariantSlugs`
- [x] Generate slugs from `"#{variant.name} #{product.name}".parameterize`
- [x] Handle duplicates with counter suffix
- [x] Add NOT NULL constraint after population

**Files**: `db/migrate/XXXXXX_populate_product_variant_slugs.rb`
**Dependencies**: Task 1.3

---

### Task 1.5: Add slug generation to ProductVariant model
- [x] Add `before_validation :generate_slug` callback
- [x] Implement `generate_slug` method
- [x] Implement `ensure_unique_slug` private method
- [x] Add validation: `validates :slug, presence: true, uniqueness: true`
- [x] Add `to_param` method returning slug
- [x] Write tests for slug generation

**Files**: `app/models/product_variant.rb`, `test/models/product_variant_test.rb`
**Dependencies**: Task 1.4

**Tests to add**:
```ruby
test "generates slug from name and product name" do
  # ...
end

test "handles duplicate slugs with counter" do
  # ...
end

test "to_param returns slug" do
  # ...
end
```

---

## Phase 2: User Story 1 - Direct Purchase (P1)

> **Goal**: Customer can navigate to a variant URL, see product details, and add to cart.

### Task 2.1: Add routes for variant pages
- [x] Add route: `get 'products/:slug', to: 'product_variants#show', as: :product_variant`
- [x] Place route before any conflicting product routes
- [x] Verify route works with `rails routes | grep product_variant`

**Files**: `config/routes.rb`
**Dependencies**: Task 1.5

---

### Task 2.2: Create ProductVariantsController
- [ ] Create controller with `show` action
- [ ] Find variant by slug: `ProductVariant.active.find_by!(slug: params[:slug])`
- [ ] Handle 404 for missing/inactive variants
- [ ] Load associated product and category for breadcrumbs
- [ ] Write controller tests

**Files**: `app/controllers/product_variants_controller.rb`, `test/controllers/product_variants_controller_test.rb`
**Dependencies**: Task 2.1

**Controller tests**:
```ruby
test "show displays variant page" do
  variant = product_variants(:widget_small)
  get product_variant_path(variant.slug)
  assert_response :success
end

test "show returns 404 for invalid slug" do
  get product_variant_path("nonexistent-slug")
  assert_response :not_found
end

test "show returns 404 for inactive variant" do
  # ...
end
```

---

### Task 2.3: Create variant page view template
- [ ] Create `app/views/product_variants/show.html.erb`
- [ ] Display: product photo, variant name, price per pack, pack size, SKU
- [ ] Include quantity selector (reuse existing pattern)
- [ ] Include "Add to Cart" button with Turbo integration
- [ ] Add breadcrumb navigation partial
- [ ] Style with TailwindCSS/DaisyUI

**Files**: `app/views/product_variants/show.html.erb`
**Dependencies**: Task 2.2

**Layout sections**:
1. Breadcrumb: Home > Category > Variant Name
2. Main content: Photo (left), Details (right)
3. Details: Name, Price, Pack info, Quantity, Add to Cart
4. Below fold: Description, See also (Phase 5)

---

### Task 2.4: Add display helpers to ProductVariant
- [ ] Add `display_name` method: `"#{name.titleize} #{product.name}"`
- [ ] Add `meta_description` method
- [ ] Add `price_display` method (format with pack info)
- [ ] Write helper tests

**Files**: `app/models/product_variant.rb`, `test/models/product_variant_test.rb`
**Dependencies**: Task 2.3

---

### Task 2.5: Add SEO meta tags to variant pages
- [ ] Set `content_for :title` with variant display name
- [ ] Set `content_for :meta_description`
- [ ] Add canonical URL
- [ ] Add Product structured data (JSON-LD)
- [ ] Update sitemap to include variant URLs

**Files**: `app/views/product_variants/show.html.erb`, `app/helpers/seo_helper.rb`, `app/services/sitemap_generator_service.rb`
**Dependencies**: Task 2.4

**Structured data** (adapt from existing `product_structured_data`):
```ruby
def variant_structured_data(variant)
  {
    "@context": "https://schema.org",
    "@type": "Product",
    "name": variant.display_name,
    "sku": variant.sku,
    "offers": {
      "@type": "Offer",
      "price": variant.price.to_s,
      "priceCurrency": "GBP",
      "availability": "https://schema.org/InStock"
    }
  }
end
```

---

### Task 2.6: Write system test for variant page purchase flow
- [ ] Test navigating to variant URL
- [ ] Test page displays correct information
- [ ] Test quantity selection
- [ ] Test add to cart updates cart drawer
- [ ] Test SEO elements present

**Files**: `test/system/variant_page_test.rb`
**Dependencies**: Task 2.5

**System test**:
```ruby
class VariantPageTest < ApplicationSystemTestCase
  test "customer can view variant and add to cart" do
    variant = product_variants(:widget_small)
    visit product_variant_path(variant.slug)

    assert_text variant.display_name
    assert_text variant.price

    select "2", from: "Quantity"
    click_button "Add to Cart"

    assert_selector "[data-controller='cart-drawer']", visible: true
  end
end
```

---

## Phase 3: User Story 2 - Browse All Products (P1)

> **Goal**: Shop page displays all variants as individual cards, linking to variant pages.

### Task 3.1: Create variant card partial
- [ ] Create `app/views/products/_variant_card.html.erb`
- [ ] Display: photo, variant name, price per pack
- [ ] Link to variant page using `product_variant_path(variant)`
- [ ] Style to match existing product card design
- [ ] Add hover effect showing lifecycle photo if available

**Files**: `app/views/products/_variant_card.html.erb`
**Dependencies**: Task 2.1

---

### Task 3.2: Update ProductsController#index for variants
- [ ] Change query from `Product.active` to `ProductVariant.active`
- [ ] Include product association for display name
- [ ] Add pagination if >100 variants (using Pagy)
- [ ] Update instance variable: `@variants` instead of `@products`

**Files**: `app/controllers/products_controller.rb`
**Dependencies**: Task 3.1

---

### Task 3.3: Update shop page view to render variant cards
- [ ] Update `app/views/products/index.html.erb`
- [ ] Render `@variants` collection with `_variant_card` partial
- [ ] Wrap grid in Turbo Frame `variants-grid` for filter updates
- [ ] Update page title/description for shop page

**Files**: `app/views/products/index.html.erb`
**Dependencies**: Task 3.2

---

### Task 3.4: Update category pages for variant cards
- [ ] Update `CategoriesController#show` to load variants
- [ ] Update category view to use `_variant_card` partial
- [ ] Ensure consistent layout with shop page

**Files**: `app/controllers/categories_controller.rb`, `app/views/categories/show.html.erb`
**Dependencies**: Task 3.3

---

### Task 3.5: Write system test for shop page browsing
- [ ] Test shop page displays all variants
- [ ] Test clicking variant card navigates to variant page
- [ ] Test page loads within performance target

**Files**: `test/system/shop_page_test.rb`
**Dependencies**: Task 3.4

---

## Phase 4: User Story 3 - Search for Products (P2)

> **Goal**: Header search with dropdown results, linking to variant pages.

### Task 4.1: Add search route
- [ ] Add route: `get 'search', to: 'search#index'`
- [ ] Place before product routes to avoid slug collision

**Files**: `config/routes.rb`
**Dependencies**: Task 3.5

---

### Task 4.2: Add search scope to ProductVariant
- [ ] Add `scope :search` using tsvector query
- [ ] Add `scope :search_extended` including product/category names via JOIN
- [ ] Write tests for search scopes

**Files**: `app/models/product_variant.rb`, `test/models/product_variant_test.rb`
**Dependencies**: Task 4.1

**Scope implementation** (from `data-model.md`):
```ruby
scope :search, ->(query) {
  return all if query.blank?
  sanitized = sanitize_sql_like(query.to_s.truncate(100, omission: ""))
  where("search_vector @@ plainto_tsquery('english', ?)", sanitized)
    .order(Arel.sql("ts_rank(search_vector, plainto_tsquery('english', #{connection.quote(sanitized)})) DESC"))
}
```

---

### Task 4.3: Create SearchController
- [ ] Create controller with `index` action
- [ ] Query `ProductVariant.active.search_extended(params[:q])`
- [ ] Limit to 5 results for dropdown
- [ ] Return empty state if query < 2 chars
- [ ] Support Turbo Frame `search-results`
- [ ] Write controller tests

**Files**: `app/controllers/search_controller.rb`, `test/controllers/search_controller_test.rb`
**Dependencies**: Task 4.2

---

### Task 4.4: Create search results partial
- [ ] Create `app/views/search/_results.html.erb`
- [ ] Render compact variant cards (photo, name, price)
- [ ] Include "View all results" link to `/shop?q=...`
- [ ] Handle empty state gracefully

**Files**: `app/views/search/_results.html.erb`, `app/views/search/index.html.erb`
**Dependencies**: Task 4.3

---

### Task 4.5: Add search input to header
- [ ] Update `app/views/shared/_navbar.html.erb`
- [ ] Add search input in navbar-center
- [ ] Add Turbo Frame `search-results` for dropdown
- [ ] Style dropdown positioning

**Files**: `app/views/shared/_navbar.html.erb`
**Dependencies**: Task 4.4

---

### Task 4.6: Create search Stimulus controller
- [ ] Create `app/frontend/javascript/controllers/search_controller.js`
- [ ] Implement debounced input (200ms)
- [ ] Trigger Turbo Frame fetch on input
- [ ] Handle dropdown visibility (show on focus, hide on blur)
- [ ] Register controller in `application.js` lazy controllers

**Files**: `app/frontend/javascript/controllers/search_controller.js`, `app/frontend/entrypoints/application.js`
**Dependencies**: Task 4.5

---

### Task 4.7: Write system test for search functionality
- [ ] Test typing in search shows dropdown
- [ ] Test results link to variant pages
- [ ] Test "View all" links to shop with query
- [ ] Test search responds within 500ms

**Files**: `test/system/search_test.rb`
**Dependencies**: Task 4.6

---

## Phase 5: User Story 4 - Filter Products (P2)

> **Goal**: Shop page filters narrow results by category, size, colour, material.

### Task 5.1: Add filter scopes to ProductVariant
- [ ] Add `scope :with_option` for generic option filtering
- [ ] Add convenience scopes: `with_size`, `with_colour`, `with_material`
- [ ] Add `scope :in_category` for category filtering
- [ ] Write tests for filter scopes

**Files**: `app/models/product_variant.rb`, `test/models/product_variant_test.rb`
**Dependencies**: Task 4.7

**Scope implementation** (from `data-model.md`):
```ruby
scope :with_option, ->(option_name, value) {
  return all if value.blank?
  joins(option_values: :product_option)
    .where(product_options: { name: option_name })
    .where(product_option_values: { value: value })
}

scope :in_category, ->(category_slug) {
  return all if category_slug.blank?
  joins(product: :category).where(categories: { slug: category_slug })
}
```

---

### Task 5.2: Update ProductsController#index for filtering
- [ ] Parse filter params: `params[:category]`, `params[:size]`, `params[:colour]`, `params[:material]`
- [ ] Chain scopes: `.in_category(cat).with_size(size).with_colour(colour).with_material(material)`
- [ ] Preserve search query when filtering
- [ ] Pass available filter values to view

**Files**: `app/controllers/products_controller.rb`
**Dependencies**: Task 5.1

---

### Task 5.3: Create filters partial
- [ ] Create `app/views/shared/_filters.html.erb`
- [ ] Add dropdowns for: Category, Size, Colour, Material
- [ ] Populate options from available values
- [ ] Mark currently selected values
- [ ] Include "Clear all" link

**Files**: `app/views/shared/_filters.html.erb`
**Dependencies**: Task 5.2

---

### Task 5.4: Add filters to shop page
- [ ] Include `_filters` partial in shop page
- [ ] Position filters above product grid
- [ ] Wrap in form with Turbo Frame submission

**Files**: `app/views/products/index.html.erb`
**Dependencies**: Task 5.3

---

### Task 5.5: Create filters Stimulus controller
- [ ] Create `app/frontend/javascript/controllers/filters_controller.js`
- [ ] Update URL params on filter change
- [ ] Trigger Turbo Frame fetch
- [ ] Preserve filter state in URL for bookmarkability
- [ ] Register controller in `application.js`

**Files**: `app/frontend/javascript/controllers/filters_controller.js`, `app/frontend/entrypoints/application.js`
**Dependencies**: Task 5.4

---

### Task 5.6: Write system test for filter functionality
- [ ] Test selecting category filter narrows results
- [ ] Test combining multiple filters
- [ ] Test URL updates with filter params
- [ ] Test bookmarking filtered URL preserves state
- [ ] Test "Clear all" removes all filters

**Files**: `test/system/filters_test.rb`
**Dependencies**: Task 5.5

---

## Phase 6: User Story 5 - Discover Related Variants (P3)

> **Goal**: "See also" section shows sibling variants on variant pages.

### Task 6.1: Add sibling_variants method to ProductVariant
- [ ] Implement `sibling_variants(limit: 8)` method
- [ ] Return other active variants from same product
- [ ] Exclude current variant from results
- [ ] Write tests

**Files**: `app/models/product_variant.rb`, `test/models/product_variant_test.rb`
**Dependencies**: Task 5.6

**Implementation**:
```ruby
def sibling_variants(limit: 8)
  product.active_variants.where.not(id: id).limit(limit)
end
```

---

### Task 6.2: Create "See also" partial
- [ ] Create `app/views/product_variants/_see_also.html.erb`
- [ ] Display horizontal scrollable carousel of variant cards
- [ ] Reuse `_variant_card` partial (compact version)
- [ ] Hide section if no siblings exist

**Files**: `app/views/product_variants/_see_also.html.erb`
**Dependencies**: Task 6.1

---

### Task 6.3: Add "See also" section to variant page
- [ ] Include `_see_also` partial in show template
- [ ] Position below main product content
- [ ] Add "See also" heading

**Files**: `app/views/product_variants/show.html.erb`
**Dependencies**: Task 6.2

---

### Task 6.4: Write system test for "See also" functionality
- [ ] Test "See also" displays sibling variants
- [ ] Test clicking sibling navigates to its page
- [ ] Test section hidden for single-variant products

**Files**: `test/system/see_also_test.rb`
**Dependencies**: Task 6.3

---

## Phase 7: Polish & Integration

### Task 7.1: SEO integration test
- [ ] Verify all variant pages have unique titles
- [ ] Verify all variant pages have meta descriptions
- [ ] Verify structured data validates
- [ ] Verify sitemap includes all variants

**Files**: `test/integration/variant_seo_test.rb`
**Dependencies**: Task 6.4

---

### Task 7.2: Performance verification
- [ ] Test shop page loads within 2 seconds
- [ ] Test search responds within 500ms
- [ ] Add eager loading where needed
- [ ] Profile database queries

**Files**: Various (optimization as needed)
**Dependencies**: Task 7.1

---

### Task 7.3: Run full test suite and fix issues
- [ ] Run `rails test`
- [ ] Run `rails test:system`
- [ ] Fix any failing tests
- [ ] Run `rubocop` and fix issues
- [ ] Run `brakeman` security scan

**Dependencies**: Task 7.2

---

### Task 7.4: Manual QA checklist
- [ ] Navigate to 5+ variant pages, verify content
- [ ] Test add to cart from variant page
- [ ] Test search with various queries
- [ ] Test all filter combinations
- [ ] Test "See also" navigation
- [ ] Test on mobile viewport
- [ ] Verify breadcrumbs work correctly

**Dependencies**: Task 7.3

---

### Task 7.5: Commit and create PR
- [ ] Stage all changes
- [ ] Create commit with descriptive message
- [ ] Push branch to origin
- [ ] Create pull request with summary

**Dependencies**: Task 7.4

---

## Task Summary

| Phase | Tasks | Priority | Est. Complexity |
|-------|-------|----------|-----------------|
| 1. Setup & Foundation | 5 | - | Medium |
| 2. Direct Purchase (US1) | 6 | P1 | Medium |
| 3. Browse All (US2) | 5 | P1 | Low |
| 4. Search (US3) | 7 | P2 | Medium |
| 5. Filter (US4) | 6 | P2 | Medium |
| 6. Related Variants (US5) | 4 | P3 | Low |
| 7. Polish | 5 | - | Low |
| **Total** | **38** | | |

## Critical Path

```
1.1 → 1.2 → 1.3 → 1.4 → 1.5 (Foundation)
                          ↓
2.1 → 2.2 → 2.3 → 2.4 → 2.5 → 2.6 (Direct Purchase - P1)
              ↓
3.1 → 3.2 → 3.3 → 3.4 → 3.5 (Browse All - P1)
                          ↓
4.1 → 4.2 → 4.3 → 4.4 → 4.5 → 4.6 → 4.7 (Search - P2)
                                      ↓
5.1 → 5.2 → 5.3 → 5.4 → 5.5 → 5.6 (Filter - P2)
                                  ↓
6.1 → 6.2 → 6.3 → 6.4 (Related Variants - P3)
                  ↓
7.1 → 7.2 → 7.3 → 7.4 → 7.5 (Polish)
```
