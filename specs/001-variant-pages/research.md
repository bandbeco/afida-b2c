# Research: Variant-Level Product Pages

**Date**: 2026-01-10
**Feature**: 001-variant-pages

## Summary

Research findings for implementing variant-level product pages. All technical decisions are based on existing codebase patterns and Rails/Postgres best practices.

---

## 1. Slug Generation Strategy

### Decision
Generate slugs from `"#{variant.name} #{product.name}".parameterize` with uniqueness validation.

### Rationale
- Follows existing `Product#generate_slug` pattern (line 143-146 of `app/models/product.rb`)
- Produces SEO-friendly, human-readable URLs
- Example: `"single-wall 8oz white"` + `"Coffee Cups"` → `single-wall-8oz-white-coffee-cups`

### Alternatives Considered
1. **SKU-based slugs** (`8wsw`) - Rejected: not human-readable, poor SEO
2. **ID-based paths** (`/variants/123`) - Rejected: not SEO-friendly
3. **Nested under product** (`/products/coffee-cups/8oz-white`) - Rejected: adds complexity, existing pattern uses flat slugs

### Implementation Notes
- Add `slug` column with unique index to `product_variants`
- Use `before_validation :generate_slug` callback
- Handle conflicts with counter suffix if needed (rare given variant name uniqueness)

---

## 2. Search Implementation

### Decision
Use Postgres full-text search with `tsvector` column on `product_variants`.

### Rationale
- Rails/Postgres stack already in use
- ~85 variants is trivial scale for Postgres FTS
- No external dependencies (Meilisearch/Algolia)
- Existing `Product.search` scope uses ILIKE, but FTS is more powerful and indexes better

### Alternatives Considered
1. **ILIKE search** (current Product approach) - Rejected: doesn't handle word boundaries, slower at scale
2. **Meilisearch** - Rejected: overkill for current scale, adds infrastructure
3. **pg_trgm trigram search** - Rejected: FTS better for word-based search

### Implementation Notes
```ruby
# Migration
add_column :product_variants, :search_vector, :tsvector
add_index :product_variants, :search_vector, using: :gin

# Trigger to update search_vector on insert/update
execute <<-SQL
  CREATE TRIGGER product_variants_search_vector_update
  BEFORE INSERT OR UPDATE ON product_variants
  FOR EACH ROW EXECUTE FUNCTION
  tsvector_update_trigger(search_vector, 'pg_catalog.english', name, sku);
SQL
```

Search scope:
```ruby
scope :search, ->(query) {
  return all if query.blank?
  where("search_vector @@ plainto_tsquery('english', ?)", query)
    .order(Arel.sql("ts_rank(search_vector, plainto_tsquery('english', #{connection.quote(query)})) DESC"))
}
```

Include product name and category via JOIN for broader matching.

---

## 3. Filter Implementation

### Decision
Use URL params with Turbo Frame updates for shop page filtering.

### Rationale
- Follows existing Hotwire patterns in codebase
- Bookmarkable filter states
- No full page reloads

### Filter Values Source
Use existing `variant_option_values` join table:
- `ProductVariant.joins(:option_values).where(option_values: { product_option: { name: 'size' }, value: '8oz' })`

### Available Filters
Based on existing option types in database:
- **Category**: From `categories` table (existing)
- **Size**: From `product_options` where name = 'size'
- **Colour**: From `product_options` where name = 'colour'
- **Material**: From `product_options` where name = 'material'

### Implementation Notes
- Controller reads params: `params[:category]`, `params[:size]`, etc.
- Scopes chain: `ProductVariant.active.in_category(cat).with_size(size).with_colour(colour)`
- Turbo Frame wraps product grid for partial updates

---

## 4. URL Routing Strategy

### Decision
Add `ProductVariantsController` with show action, route at `/products/:slug`.

### Rationale
- Clean URLs without variant ID
- SEO-friendly
- Consistent with existing Product URL pattern

### Route Configuration
```ruby
# config/routes.rb
# Must come before products resource to match first
get 'products/:slug', to: 'product_variants#show', as: :product_variant,
    constraints: { slug: /[a-z0-9\-]+/ }
```

### Collision Handling
Since variants will have slugs like `8oz-single-wall-white-coffee-cups` and products currently have slugs like `coffee-cups`, there's no collision risk. Products will be accessed via category pages, not direct URLs.

---

## 5. SEO Implementation

### Decision
Each variant page gets full SEO treatment following existing patterns.

### Rationale
- Core requirement from spec
- Existing `seo_helper.rb` provides `product_structured_data` helper
- Sitemap service already exists

### Implementation
- **Title**: `"#{variant.display_name} | Afida"`
- **Meta description**: Generate from variant + product description
- **Structured data**: Adapt `product_structured_data(product, variant)` for single variant
- **Sitemap**: Update `SitemapGeneratorService` to include variant URLs

---

## 6. "See Also" Related Variants

### Decision
Show sibling variants from same Product model.

### Rationale
- Product model already groups related variants
- Simple query: `variant.product.active_variants.where.not(id: variant.id).limit(8)`
- Matches spec requirement

### Implementation Notes
- Horizontal scrollable carousel (existing pattern in codebase)
- Reuse `_variant_card.html.erb` partial
- Limit to 8 variants to avoid overwhelming UI

---

## 7. Header Search UX

### Decision
Add search input to navbar with dropdown results via Stimulus controller.

### Rationale
- Spec requires search from any page
- Dropdown provides instant feedback
- "View all" links to `/shop?q=...`

### Implementation
- Add search input to `_navbar.html.erb` in `navbar-center` section
- New Stimulus controller `search_controller.js`:
  - Debounced input (200ms)
  - Turbo Frame fetch to `/search?q=...`
  - Dropdown positioning
- Results endpoint returns max 5 variants as cards

---

## 8. Shop Page Update

### Decision
Replace Product cards with ProductVariant cards on `/shop` and category pages.

### Rationale
- Core spec requirement
- Shows full range at a glance (Yusif's request)
- Each card links to variant page

### Implementation Notes
- Update `ProductsController#index` to load variants instead of products
- New partial `_variant_card.html.erb` (simpler than product card)
- Pagination via Pagy gem (already installed) if needed for >50 variants

---

## Open Questions Resolved

| Question | Resolution |
|----------|------------|
| How to handle slug collisions? | Counter suffix (e.g., `-2`) if name+product duplicate exists. Rare case. |
| Should search include category names? | Yes, via JOIN in search query. |
| Pagination needed for shop page? | Only if >100 variants. Start without, add if needed. |
| Mobile search UX? | Full-screen overlay on tap, same results API. |

---

## Dependencies

- No new gems required
- Postgres 14+ (already in use)
- Existing Stimulus/Turbo infrastructure
- Existing SEO helpers

## Risks

| Risk | Mitigation |
|------|------------|
| Slug conflicts | Unique index with counter suffix fallback |
| Search performance at scale | FTS with GIN index; upgrade to Meilisearch if >1000 variants |
| Filter combination explosion | Limit to 4 filter types; dynamic filter values from data |
