# Implementation Plan: B2B Price List

**Branch**: `001-b2b-price-list` | **Date**: 2025-12-12 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-b2b-price-list/spec.md`

## Summary

Build a dedicated `/price-list` page that serves B2B customers with a filterable table of all product variants, quantity dropdowns for rapid ordering, and Excel/PDF export functionality. The page will use Turbo Frames for instant filter updates without page reloads, integrate with the existing cart infrastructure, and leverage Prawn (existing) and caxlsx (new) gems for document generation.

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x
**Primary Dependencies**: Rails 8, Hotwire (Turbo + Stimulus), TailwindCSS 4, DaisyUI, Prawn (PDF), caxlsx (Excel)
**Storage**: PostgreSQL 14+ (existing `products`, `product_variants`, `categories`, `cart_items` tables)
**Testing**: Minitest with Capybara for system tests
**Target Platform**: Web (responsive, mobile-friendly)
**Project Type**: Web application (Rails monolith with Vite frontend)
**Performance Goals**: Filters apply within 1 second, exports complete within 5 seconds
**Constraints**: Must work with existing cart drawer, respect VAT-excluded pricing convention
**Scale/Scope**: ~100 product variants initially, single new controller with 3 views

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| **I. Test-First Development** | WILL COMPLY | Tests written before implementation for controller, exports, and filtering |
| **II. SEO & Structured Data** | WILL COMPLY | Meta tags, canonical URL for /price-list page |
| **III. Performance & Scalability** | WILL COMPLY | Eager loading for product/category joins, SQL-based filtering via JSONB |
| **IV. Security & Payment Integrity** | WILL COMPLY | No new security surface; uses existing cart validation |
| **V. Code Quality & Maintainability** | WILL COMPLY | Single controller, follows existing patterns, RuboCop compliance |

**Technology Constraints Check**:
- Hotwire patterns used (Turbo Frames for filtering)
- No client-side state management frameworks
- Server-side rendering for SEO
- ActiveRecord for database access

## Project Structure

### Documentation (this feature)

```text
specs/001-b2b-price-list/
├── plan.md              # This file
├── spec.md              # Feature specification
├── checklists/          # Requirements checklist
└── tasks.md             # Implementation tasks (to be generated)
```

### Source Code (repository root)

```text
app/
├── controllers/
│   └── price_list_controller.rb     # NEW: index, export actions
├── views/
│   └── price_list/
│       ├── index.html.erb           # NEW: main page with filter bar
│       ├── _table.html.erb          # NEW: table partial (Turbo Frame target)
│       ├── _row.html.erb            # NEW: row partial with add-to-cart form
│       └── export.xlsx.axlsx        # NEW: Excel template
├── services/
│   └── price_list_pdf.rb            # NEW: PDF generation service
├── frontend/
│   └── javascript/
│       └── controllers/
│           ├── form_controller.js   # EXISTING: form submission
│           └── search_controller.js # EXISTING: debounced search
config/
└── routes.rb                        # MODIFY: add /price-list routes

test/
├── controllers/
│   └── price_list_controller_test.rb
├── services/
│   └── price_list_pdf_test.rb
└── system/
    └── price_list_test.rb
```

## Research Decisions

### Excel Export Library
**Decision**: Use `caxlsx` gem (~4.1)
**Rationale**: Pure Ruby implementation, actively maintained, Rails integration via `.xlsx.axlsx` templates

### PDF Export Approach
**Decision**: Use existing `prawn` gem (already in Gemfile)
**Rationale**: Already installed for order receipts, no new dependencies

### JSONB Filtering Pattern
**Decision**: Use PostgreSQL JSONB `->>` operator directly
**Pattern**:
```ruby
variants.where("option_values->>'material' = ?", params[:material])
variants.where("option_values->>'size' = ?", params[:size])
```

### Cart Integration
**Decision**: POST to existing `cart_cart_items_path`
**Rationale**: `CartItemsController#create` already handles finding variant, quantity increment, Turbo Stream response

## Complexity Tracking

> **No violations. Feature follows existing patterns.**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| *None* | *N/A* | *N/A* |
