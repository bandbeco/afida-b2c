# Implementation Plan: Variant-Level Product Pages

**Branch**: `001-variant-pages` | **Date**: 2026-01-10 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-variant-pages/spec.md`

## Summary

Replace consolidated product pages (one page with variant selector) with individual pages per SKU. Each ProductVariant becomes a standalone, purchasable page with its own URL (`/products/:variant-slug`). This improves SEO surface area, simplifies the purchasing flow for customers who know what they want, and aligns with competitor patterns. The implementation includes header search with Postgres full-text search, shop page filters (category, size, colour, material), and "See also" sections for cross-variant discovery.

## Technical Context

**Language/Version**: Ruby 3.4.7, Rails 8.1.1
**Primary Dependencies**: Turbo-Rails, Stimulus-Rails, Vite Rails 3.0, Pagy (pagination)
**Storage**: PostgreSQL 14+ (existing schema, adding `slug` to `product_variants`, `search_vector` tsvector column)
**Testing**: Minitest with fixtures, Capybara + Selenium for system tests
**Target Platform**: Web (Linux server, browsers)
**Project Type**: Web application (Rails monolith with Vite frontend)
**Performance Goals**: Shop page loads within 2 seconds, search results within 500ms
**Constraints**: ~85 variants current, design for up to 500 without pagination
**Scale/Scope**: 21 products, ~85 variants, single-tenant e-commerce

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First Development | ✅ PASS | Tests will be written first for slug generation, search, filters. Fixtures used throughout. |
| II. SEO & Structured Data | ✅ PASS | Each variant page gets unique meta tags, Product structured data, sitemap inclusion. Core feature requirement. |
| III. Performance & Scalability | ✅ PASS | Postgres tsvector search is efficient. Turbo Frames for filter updates. Eager loading for variant cards. |
| IV. Security & Payment Integrity | ✅ PASS | No new payment flows. Standard Rails input sanitization. Search uses parameterized queries. |
| V. Code Quality & Maintainability | ✅ PASS | Following existing patterns. Slug generation follows Product model pattern. RuboCop compliance. |
| Technology Constraints | ✅ PASS | All within allowed stack (Rails, Postgres, Hotwire, Vite, TailwindCSS). No GraphQL, no JS frameworks. |

**Gate Result**: PASS - Proceed to Phase 0

## Project Structure

### Documentation (this feature)

```text
specs/001-variant-pages/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (API endpoints)
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
app/
├── controllers/
│   ├── product_variants_controller.rb  # NEW - variant page controller
│   ├── products_controller.rb          # MODIFY - update for variant cards
│   └── search_controller.rb            # NEW - search API endpoint
├── models/
│   └── product_variant.rb              # MODIFY - add slug, search_vector, scopes
├── views/
│   ├── product_variants/
│   │   └── show.html.erb               # NEW - variant page template
│   ├── products/
│   │   ├── index.html.erb              # MODIFY - variant cards
│   │   └── _variant_card.html.erb      # NEW - card partial
│   ├── search/
│   │   └── _results.html.erb           # NEW - search dropdown partial
│   └── shared/
│       ├── _header.html.erb            # MODIFY - add search input
│       └── _filters.html.erb           # NEW - filter controls
├── frontend/
│   └── javascript/
│       └── controllers/
│           ├── search_controller.js    # NEW - header search Stimulus
│           └── filters_controller.js   # NEW - shop page filters Stimulus
├── helpers/
│   └── variant_helper.rb               # NEW - slug generation, SEO helpers
└── services/
    └── variant_search_service.rb       # NEW - search logic encapsulation

db/
└── migrate/
    ├── XXXXXX_add_slug_to_product_variants.rb
    └── XXXXXX_add_search_vector_to_product_variants.rb

test/
├── controllers/
│   ├── product_variants_controller_test.rb
│   └── search_controller_test.rb
├── models/
│   └── product_variant_test.rb         # MODIFY - slug and search tests
├── system/
│   ├── variant_page_test.rb
│   ├── shop_page_test.rb
│   └── search_test.rb
├── integration/
│   └── variant_seo_test.rb
└── fixtures/
    └── product_variants.yml            # MODIFY - add slugs
```

**Structure Decision**: Follows existing Rails monolith structure. New controller for variant pages, existing products controller updated for variant card display. Search encapsulated in service for testability.

## Complexity Tracking

> No violations requiring justification. Feature follows existing patterns and constitution principles.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | - | - |
