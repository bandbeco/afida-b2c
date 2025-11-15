# Research: Shop Page Filters and Search

**Feature**: Shop Page - Product Listing with Filters and Search
**Branch**: `003-shop-page-filters-search`
**Date**: 2025-01-14

## Overview

This document resolves all technical unknowns identified in the Technical Context section of plan.md. Each decision is documented with rationale and alternatives considered.

---

## Decision 1: Pagination Gem Selection (Kaminari vs Pagy)

**Unknown**: Which pagination gem to use for product listing

**Decision**: Use **Pagy** gem

**Rationale**:
1. **Performance**: Pagy is significantly faster than Kaminari (40x faster according to benchmarks)
   - Pagy uses simple Ruby calculations vs ActiveRecord count queries
   - Minimal memory footprint (< 4KB vs Kaminari's > 100KB)
2. **Rails 8 Compatibility**: Pagy is actively maintained with Rails 8 support
3. **Simplicity**: Pagy has no dependencies (Kaminari requires ActiveRecord helpers)
4. **Features**: Pagy supports all needed features:
   - Page-based pagination (default)
   - Turbo/Hotwire integration (pagy_turbo helper)
   - Customizable templates (works with TailwindCSS/DaisyUI)
   - Overflow handling (when page number exceeds total pages)
5. **Modern Rails Pattern**: Pagy aligns with Rails 8's performance-first philosophy

**Alternatives Considered**:
- **Kaminari**: More popular historically, but heavier and slower. Last major update 2020.
- **will_paginate**: Older gem, not as actively maintained, similar performance to Kaminari
- **Custom pagination**: Would require writing SQL LIMIT/OFFSET logic, not worth the effort

**Implementation Notes**:
- Gem: `pagy` (latest version ~6.x)
- Backend: `include Pagy::Backend` in PagesController
- Frontend: `include Pagy::Frontend` in ApplicationHelper
- Turbo integration: Use `pagy_turbo` for frame updates
- Items per page: 24 (configurable via `Pagy::DEFAULT[:items]`)

**References**:
- Pagy GitHub: https://github.com/ddnexus/pagy
- Pagy vs Kaminari benchmarks: https://ddnexus.github.io/pagy/docs/performance/

---

## Decision 2: Search Implementation (PostgreSQL ILIKE vs Full-Text Search)

**Unknown**: How to implement product search for names/SKUs

**Decision**: Use **PostgreSQL ILIKE** with multiple column search

**Rationale**:
1. **Simplicity**: ILIKE is built into PostgreSQL, no additional setup required
2. **Sufficient for Current Scale**: 50-500 products doesn't require full-text search complexity
3. **Case-Insensitive**: ILIKE handles case-insensitivity natively (vs LIKE)
4. **Multi-Column Search**: Can search across `name`, `sku`, `colour` columns
5. **Indexable**: Can add GIN/GIST indexes if needed for performance (future optimization)

**Alternatives Considered**:
- **PostgreSQL Full-Text Search (FTS)**: Overkill for current scale, adds complexity
  - Requires additional `tsvector` column and triggers
  - Better for large datasets (10k+ products) with relevance ranking
- **pg_search gem**: Wrapper around FTS, adds dependency and complexity
- **Elasticsearch**: Massive overkill, requires separate service infrastructure
- **Trigram similarity (pg_trgm)**: Better for fuzzy matching, but ILIKE sufficient

**Implementation Notes**:
- ActiveRecord scope: `Product.search(query)` using ILIKE
- Search across: `products.name`, `products.sku`, `products.colour`
- Query: `WHERE name ILIKE ? OR sku ILIKE ? OR colour ILIKE ?` with `%#{query}%`
- Future optimization: Add GIN index if search becomes slow (`CREATE INDEX ... USING GIN`)

**Example Scope**:
```ruby
scope :search, ->(query) {
  return all if query.blank?
  where("name ILIKE ? OR sku ILIKE ? OR colour ILIKE ?",
        "%#{sanitize_sql_like(query)}%",
        "%#{sanitize_sql_like(query)}%",
        "%#{sanitize_sql_like(query)}%")
}
```

---

## Decision 3: Turbo Frame Strategy for Filters

**Unknown**: How to structure Turbo Frames for dynamic filter updates

**Decision**: Use **single Turbo Frame wrapping product grid + pagination**

**Rationale**:
1. **Simplicity**: One frame = one update target, easier to reason about
2. **Atomic Updates**: Product grid and pagination updated together (always in sync)
3. **URL Updates**: Turbo Frame with `data-turbo-action="replace"` updates URL
4. **SEO Friendly**: Initial page load has all HTML, Turbo enhances with JS
5. **No-JS Fallback**: Form submits to same URL, works without Turbo

**Alternatives Considered**:
- **Multiple Frames** (filters, products, pagination): More complex, can get out of sync
- **Stimulus Reflex**: Overkill, requires WebSocket infrastructure
- **AJAX with JavaScript**: Would require custom JS, Turbo provides this for free

**Implementation Notes**:
- Frame ID: `turbo-frame#products`
- Wraps: Product grid + pagination controls
- Does NOT wrap: Filter sidebar (remains static for UX)
- Controller action: Renders full layout on initial load, frame-only on Turbo requests
- URL handling: `data-turbo-action="replace"` keeps URL in sync with filters

**Structure**:
```erb
<!-- Static filter sidebar (outside frame) -->
<aside>
  <form data-turbo-frame="products">
    <!-- Category checkboxes -->
    <!-- Search input -->
    <!-- Sort dropdown -->
  </form>
</aside>

<!-- Dynamic product grid (inside frame) -->
<turbo-frame id="products">
  <div class="product-grid">
    <!-- Product cards -->
  </div>
  <%= pagy_nav(@pagy) %>
</turbo-frame>
```

---

## Decision 4: Database Indexes for Performance

**Unknown**: Which indexes to add for filtering/search performance

**Decision**: Add **composite and single-column indexes** on products table

**Rationale**:
1. **Category Filter**: Index on `category_id` (most common filter)
2. **Search Performance**: Indexes on `name`, `sku` for ILIKE queries
3. **Sorting**: Index on `position`, `name` (default scope already uses this)
4. **Active Status**: Composite index on `(active, category_id)` for common query

**Indexes to Add**:
```ruby
add_index :products, :category_id  # Category filtering
add_index :products, :name         # Search by name
add_index :products, :sku          # Search by SKU
add_index :products, [:active, :category_id]  # Common filter combo
```

**Existing Indexes** (no changes needed):
- Primary key (`id`) - already indexed
- `slug` - already unique indexed
- `position` - already indexed (via acts_as_list)

**Alternatives Considered**:
- **GIN index for full-text**: Not needed yet, ILIKE sufficient for current scale
- **Multi-column index (name, sku, colour)**: Not beneficial for ILIKE OR queries
- **Expression index (LOWER(name))**: ILIKE already case-insensitive

---

## Decision 5: Search Debouncing Implementation

**Unknown**: How to implement search input debouncing

**Decision**: Use **Stimulus controller with setTimeout**

**Rationale**:
1. **Native Solution**: No additional libraries needed
2. **Turbo Integration**: Triggers form submission after debounce delay
3. **User Experience**: 300ms delay balances responsiveness vs server load
4. **Simple Logic**: ~20 lines of JavaScript, easy to test and maintain

**Implementation Notes**:
- Controller: `search_controller.js`
- Debounce delay: 300ms (industry standard for search)
- Action: `data-action="input->search#debounce"`
- Clears timeout on each keystroke, only submits after 300ms of inactivity

**Code Outline**:
```javascript
// app/frontend/javascript/controllers/search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  debounce(event) {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()  // Triggers Turbo form submission
    }, this.delayValue)
  }
}
```

**Alternatives Considered**:
- **Lodash debounce**: Adds dependency, not needed for simple use case
- **Turbo Streams**: Overkill for search, Turbo Frames sufficient
- **No debouncing**: Would cause excessive server requests (poor UX and performance)

---

## Decision 6: Sort Options and Default Behavior

**Unknown**: Which sort options to provide and what should be default

**Decision**: Provide **4 sort options** with **position/name as default**

**Sort Options**:
1. **Relevance** (default) - `position ASC, name ASC` (matches existing default scope)
2. **Price: Low to High** - `min_price ASC, name ASC`
3. **Price: High to Low** - `min_price DESC, name ASC`
4. **Name: A-Z** - `name ASC`

**Rationale**:
1. **Default Maintains Current Behavior**: Product position reflects merchandising priorities
2. **Price Sorting**: Uses minimum variant price (most useful for multi-variant products)
3. **Alphabetical**: Useful for customers who know product names
4. **Simple Set**: 4 options balances choice without overwhelming users

**Implementation Notes**:
- Scope: `Product.sorted(sort_param)` handles all sort logic
- Default: `sort_param = params[:sort] || 'relevance'`
- Price sorting requires subquery or join to get min variant price
- URL param: `?sort=price_asc`, `?sort=price_desc`, `?sort=name_asc`

**Alternatives Considered**:
- **Newest First**: Products don't have visible creation dates, not useful for customers
- **Best Selling**: Requires order tracking, future enhancement
- **Customer Ratings**: No rating system exists yet
- **Separate "Featured" Filter**: Position already handles this

---

## Summary of Technical Decisions

| Decision | Choice | Key Reason |
|----------|--------|------------|
| Pagination | Pagy | 40x faster than Kaminari, Rails 8 compatible |
| Search | PostgreSQL ILIKE | Simple, sufficient for 50-500 products |
| Turbo Frames | Single frame (grid + pagination) | Atomic updates, simpler state management |
| Indexes | category_id, name, sku, (active, category_id) | Optimize common queries |
| Search Debounce | Stimulus controller (300ms) | Native solution, no dependencies |
| Sort Options | 4 options (relevance, price asc/desc, name) | Balances choice vs simplicity |

All NEEDS CLARIFICATION items from Technical Context are now resolved. Ready to proceed to Phase 1 (Design & Contracts).
