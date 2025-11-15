# Implementation Plan: Shop Page - Product Listing with Filters and Search

**Branch**: `003-shop-page-filters-search` | **Date**: 2025-01-14 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-shop-page-filters-search/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Transform the /shop page from a category-only view to a full product listing page with filtering (by category), search (by name/SKU), and sorting capabilities. All functionality must use Hotwire Turbo Frames for dynamic updates, maintain URL parameters for bookmarking, implement pagination for 24+ products, and prevent N+1 queries through proper eager loading. The implementation follows TDD principles with comprehensive test coverage for models, controllers, and system tests.

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x
**Primary Dependencies**:
- Rails 8 (ActiveRecord, ActionDispatch)
- PostgreSQL 14+ (using ILIKE for case-insensitive search)
- Hotwire (Turbo Frames for dynamic filtering)
- Vite + TailwindCSS 4 + DaisyUI (frontend)
- Kaminari or Pagy gem for pagination (NEEDS CLARIFICATION: which pagination gem to use)
- Stimulus controllers for debounced search input

**Storage**: PostgreSQL 14+ (existing `products`, `categories`, `product_variants` tables)
**Testing**: Rails Minitest (models, controllers, system tests with Capybara + Selenium)
**Target Platform**: Web application (desktop + mobile responsive)
**Project Type**: Web application (Rails MVC with Hotwire frontend)
**Performance Goals**:
- Page load < 2 seconds for 50+ products
- Search results < 500ms
- Filter updates via Turbo Frame (no full page reload)
- Lighthouse performance score > 90

**Constraints**:
- Must prevent N+1 queries (use eager loading with `.includes()`)
- Must use Turbo Frames (no full JavaScript framework)
- Must maintain SEO (server-side rendering, canonical URLs, meta tags)
- Must support no-JavaScript fallback (form submission)
- Must maintain existing URL structure for categories (/categories/:slug)

**Scale/Scope**:
- 50+ products currently, designed to handle 500+ products
- 10+ categories
- Pagination threshold: 24 products per page
- Mobile-first responsive design

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Test-First Development (NON-NEGOTIABLE)
✅ **PASS** - Feature will follow strict TDD:
- Model scopes (search, filter, sort) tested before implementation
- Controller filtering logic tested before implementation
- System tests for user flows (browse, filter, search, combine) written first
- Red-Green-Refactor cycle enforced for all code
- Test coverage: models (search/filter scopes), controllers (params handling), system (full user flows)

### II. SEO & Structured Data
✅ **PASS** - SEO maintained and enhanced:
- Canonical URLs preserved on /shop page
- Meta tags (title, description) already exist, will be maintained
- URL parameters (category, q, sort) support bookmarking/sharing
- Breadcrumb structured data will include filter state
- Page title will reflect active filters (e.g., "Cups - Shop | Afida")
- No negative SEO impact from client-side filtering (server-side rendering via Turbo Frames)

### III. Performance & Scalability
✅ **PASS** - Performance optimized:
- Eager loading with `.includes(:category, :active_variants, product_photo_attachment: :blob)` prevents N+1
- Pagination limits query size (24 products per page)
- Database indexes on `products.name`, `products.sku`, `products.category_id` ensure fast queries
- Turbo Frames avoid full page reloads (faster perceived performance)
- Search debouncing (300ms) reduces server load
- SQL-based filtering (no in-memory filtering of large datasets)

### IV. Security & Payment Integrity
✅ **PASS** - No security concerns:
- Feature is read-only (no data modification)
- SQL injection prevented by ActiveRecord parameterization
- XSS prevented by Rails auto-escaping in views
- No payment or authentication changes
- Public-facing page (no authorization required)

### V. Code Quality & Maintainability
✅ **PASS** - High code quality standards:
- Single Responsibility: PagesController#shop handles only product listing
- Named scopes for search/filter logic (e.g., `Product.search(query)`, `Product.in_category(id)`)
- No default scopes added (existing default scope on Product documented and acceptable)
- Stimulus controller for search debouncing (small, focused responsibility)
- DRY: Shared partials for product cards (already exist in codebase)
- Clear naming: filter params (category_id, q, sort, page)
- RuboCop compliance enforced before commit

**GATE RESULT**: ✅ ALL GATES PASSED - Proceed to Phase 0 Research

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# Rails MVC Application Structure
app/
├── controllers/
│   └── pages_controller.rb          # Updated: shop action with filtering
├── models/
│   ├── product.rb                    # Updated: add search, sort scopes
│   └── category.rb                   # Unchanged
├── views/
│   └── pages/
│       └── shop.html.erb             # Updated: product grid + filters + Turbo Frame
└── frontend/
    └── javascript/
        └── controllers/
            └── search_controller.js  # New: debounced search input

test/
├── models/
│   └── product_test.rb               # Updated: search/filter/sort scope tests
├── controllers/
│   └── pages_controller_test.rb      # Updated: filter/search param tests
└── system/
    └── shop_page_test.rb             # New: user flows (browse, filter, search)

db/
└── migrate/
    └── [timestamp]_add_indexes_to_products.rb  # New: name, sku, category_id indexes
```

**Structure Decision**: Standard Rails MVC web application. No new models required - feature extends existing Product/Category models with scopes and updates PagesController. Frontend uses Hotwire Turbo Frames with minimal Stimulus controller for search debouncing. Tests follow Rails conventions (models/, controllers/, system/).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No violations** - All constitution principles are satisfied. No complexity justification needed.

---

## Phase Summary

### Phase 0: Research (COMPLETED)

**Deliverable**: `research.md`

**Key Decisions Made**:
1. **Pagination**: Use Pagy gem (40x faster than Kaminari, Rails 8 compatible)
2. **Search**: PostgreSQL ILIKE (simple, sufficient for 50-500 products)
3. **Turbo Frames**: Single frame wrapping grid + pagination (atomic updates)
4. **Indexes**: Add category_id, name, sku, (active, category_id) for performance
5. **Search Debouncing**: Stimulus controller with 300ms delay
6. **Sort Options**: 4 options (relevance, price asc/desc, name A-Z)

All NEEDS CLARIFICATION items resolved. All technical unknowns documented with rationale.

### Phase 1: Design & Contracts (COMPLETED)

**Deliverables**:
- `data-model.md` - Model scopes, database indexes, performance considerations
- `contracts/shop-page-api.md` - HTTP endpoint contract, request/response formats
- `quickstart.md` - Step-by-step TDD implementation guide

**Key Design Elements**:
1. **Model Scopes** (Product):
   - `search(query)` - ILIKE search across name/SKU/colour
   - `in_category(category_id)` - Category filter
   - `sorted(sort_param)` - Sort by relevance/price/name
2. **Controller**: PagesController#shop with eager loading and pagination
3. **View**: Filter sidebar (static) + product grid (Turbo Frame)
4. **JavaScript**: Minimal - only search debouncing Stimulus controller

**Performance**:
- Max 5 database queries (with eager loading)
- Indexes reduce query time 5-100x
- Pagination limits dataset size (24 products/page)

**SEO**:
- Server-side rendering maintained
- URL parameters for filter state
- Canonical URLs and meta tags preserved

### Constitution Re-Check (POST-DESIGN)

All gates still PASS after detailed design:

✅ **Test-First Development**: TDD workflow documented in quickstart.md (red-green-refactor)
✅ **SEO & Structured Data**: Server-side rendering, URL parameters, canonical URLs
✅ **Performance & Scalability**: Eager loading, indexes, pagination, debouncing
✅ **Security**: Read-only feature, ActiveRecord parameterization, Rails auto-escaping
✅ **Code Quality**: Single responsibility, named scopes, clear naming, RuboCop compliance

**No new concerns or violations introduced by design.**

---

## Next Steps

### Phase 2: Task Breakdown

Run `/speckit.tasks` to generate detailed task list from this plan. The command will:
1. Parse spec.md user stories
2. Generate test-first task ordering
3. Create tasks.md with dependencies
4. Enable `/speckit.implement` for automated execution

### Implementation Approach

Two options:

**Option A: Automated Implementation**
```bash
/speckit.tasks    # Generate task breakdown
/speckit.implement  # Execute tasks with TDD
```

**Option B: Manual Implementation**
Follow the quickstart.md guide step-by-step:
1. Add Pagy gem (5 min)
2. Write model tests - RED (15 min)
3. Implement model scopes - GREEN (20 min)
4. Add database indexes (5 min)
5. Write controller tests - RED (15 min)
6. Update controller - GREEN (15 min)
7. Create Stimulus controller (10 min)
8. Update view (30 min)
9. Write system tests (15 min)
10. Verify performance (10 min)

**Estimated Total Time**: ~2 hours (TDD approach)

---

## Artifacts Generated

This planning phase produced:

1. **spec.md** - User stories, acceptance criteria, functional requirements, success criteria
2. **plan.md** - This file (technical context, constitution check, project structure)
3. **research.md** - Technical decisions with rationale (pagination, search, Turbo strategy)
4. **data-model.md** - Model scopes, indexes, performance considerations
5. **contracts/shop-page-api.md** - HTTP endpoint contract, request/response formats
6. **quickstart.md** - TDD implementation guide with code examples

**Total Documentation**: ~15,000 words across 6 files

**Branch**: `003-shop-page-filters-search`

**Ready for**: Task generation (`/speckit.tasks`) or manual implementation (quickstart.md)

---

## Planning Complete ✅

All planning phases completed successfully:
- ✅ Phase 0: Research
- ✅ Phase 1: Design & Contracts
- ✅ Constitution Check (pre and post design)
- ✅ Agent Context Updated

**Status**: Ready for implementation

**Next Command**: `/speckit.tasks` to generate task breakdown
