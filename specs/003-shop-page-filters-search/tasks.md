# Implementation Tasks: Shop Page - Product Listing with Filters and Search

**Feature Branch**: `003-shop-page-filters-search`
**Created**: 2025-01-14
**Estimated Time**: ~2 hours (following TDD)

## Overview

This document breaks down the implementation into discrete, testable tasks organized by user story priority. Each phase delivers a complete, independently testable increment of functionality.

**TDD Workflow**: All tasks follow RED-GREEN-REFACTOR:
1. Write failing test (RED)
2. Implement minimum code to pass (GREEN)
3. Refactor for quality (REFACTOR)

---

## Task Legend

- **[P]**: Parallelizable - can be worked on simultaneously with other [P] tasks
- **[US#]**: User Story number from spec.md
- **Task ID**: Sequential execution order (T001, T002, etc.)

---

## Phase 1: Setup & Dependencies (Est: 10 minutes)

**Goal**: Install and configure required gems and infrastructure

### Tasks

- [X] T001 [P] Install Pagy gem by running `bundle add pagy`
- [X] T002 [P] Create Pagy initializer at config/initializers/pagy.rb with items=24 and overflow=:last_page
- [X] T003 Include Pagy::Backend in app/controllers/application_controller.rb
- [X] T004 Include Pagy::Frontend in app/helpers/application_helper.rb
- [X] T005 Verify Rails server starts without errors

**Deliverable**: Pagy gem installed and configured

**Independent Test**: Run `rails server` - should start without errors

---

## Phase 2: Foundational - Database Performance (Est: 5 minutes)

**Goal**: Add database indexes for optimal query performance

### Tasks

- [X] T006 Generate migration AddSearchAndFilterIndexesToProducts
- [X] T007 Write migration to add indexes: category_id, name, sku, [active, category_id]
- [X] T008 Run `rails db:migrate` to apply migration
- [X] T009 Verify migration with `rails db:migrate:status`

**Deliverable**: Database indexes for search and filter performance

**Independent Test**: Check schema.rb - indexes should exist on products table

---

## Phase 3: User Story 1 - Browse All Products (P1) (Est: 40 minutes)

**User Story**: As a customer visiting the shop page, I want to see all available products in a visual grid layout

**Goal**: Display all active products with pagination

**Independent Test**: Visit /shop and verify all active products displayed in grid with photos, names, prices

### Tasks

#### Tests (RED Phase)

- [X] T010 [P] [US1] Write test "shop page displays all products by default" in test/controllers/pages_controller_test.rb
- [X] T011 [P] [US1] Write system test "browsing all products" in test/system/shop_page_test.rb
- [X] T012 [US1] Run tests - should FAIL (RED phase confirmed)

#### Implementation (GREEN Phase)

- [X] T013 [US1] Update PagesController#shop in app/controllers/pages_controller.rb to load products with pagination
- [X] T014 [US1] Add eager loading: .includes(:category, :active_variants, product_photo_attachment: :blob)
- [X] T015 [US1] Add pagination: @pagy, @products = pagy(@products)
- [X] T016 [US1] Update app/views/pages/shop.html.erb with product grid layout and Turbo Frame
- [X] T017 [P] [US1] Create app/views/products/_card.html.erb partial (if not exists)
- [X] T018 [US1] Add meta tags (title, description) to shop.html.erb
- [X] T019 [US1] Run controller tests - should PASS (GREEN phase)
- [X] T020 [US1] Run system tests - should PASS (GREEN phase)

#### Verification

- [X] T021 [US1] Manual test: Visit /shop - verify all products displayed
- [X] T022 [US1] Verify pagination appears if 25+ products exist
- [X] T023 [US1] Verify product cards show photo, name, category, price range

**Deliverable**: Working /shop page with all products, pagination, and product grid

---

## Phase 4: User Story 2 - Filter by Category (P2) (Est: 25 minutes)

**User Story**: As a customer, I want to filter by category to focus on specific product types

**Goal**: Add category radio buttons that filter products via Turbo Frame

**Independent Test**: Click category filter - only products from that category shown, URL updated

### Tasks

#### Tests (RED Phase)

- [ ] T024 [P] [US2] Write test "in_category filters by category ID" in test/models/product_test.rb
- [ ] T025 [P] [US2] Write test "in_category returns all when blank" in test/models/product_test.rb
- [ ] T026 [P] [US2] Write test "shop page filters by category" in test/controllers/pages_controller_test.rb
- [ ] T027 [P] [US2] Write system test "filtering by category" in test/system/shop_page_test.rb
- [ ] T028 [US2] Run tests - should FAIL (RED phase confirmed)

#### Implementation (GREEN Phase)

- [ ] T029 [US2] Implement Product.in_category scope in app/models/product.rb
- [ ] T030 [US2] Update PagesController#shop to call .in_category(params[:category_id])
- [ ] T031 [US2] Add category filter UI (radio buttons) in app/views/pages/shop.html.erb
- [ ] T032 [US2] Add form with data-turbo-frame="products" and data-turbo-action="replace"
- [ ] T033 [US2] Add "All Products" radio option with empty value
- [ ] T034 [US2] Add category product counts using category.products_count
- [ ] T035 [US2] Add data-action="change->form#submit" to auto-submit on selection
- [ ] T036 [US2] Run model tests - should PASS (GREEN phase)
- [ ] T037 [US2] Run controller tests - should PASS (GREEN phase)
- [ ] T038 [US2] Run system tests - should PASS (GREEN phase)

#### Verification

- [ ] T039 [US2] Manual test: Select category - products filtered
- [ ] T040 [US2] Verify URL parameter: /shop?category_id=3
- [ ] T041 [US2] Verify Turbo Frame updates without full page reload

**Deliverable**: Category filtering with Turbo Frame updates and URL persistence

---

## Phase 5: User Story 3 - Search Products (P2) (Est: 35 minutes)

**User Story**: As a customer, I want to search for products by name or SKU

**Goal**: Add search input with debouncing that filters products

**Independent Test**: Enter search term - matching products shown after 300ms, URL updated

### Tasks

#### Tests (RED Phase)

- [ ] T042 [P] [US3] Write test "search returns products matching name" in test/models/product_test.rb
- [ ] T043 [P] [US3] Write test "search returns products matching SKU" in test/models/product_test.rb
- [ ] T044 [P] [US3] Write test "search is case-insensitive" in test/models/product_test.rb
- [ ] T045 [P] [US3] Write test "search returns all when blank" in test/models/product_test.rb
- [ ] T046 [P] [US3] Write test "shop page searches products" in test/controllers/pages_controller_test.rb
- [ ] T047 [P] [US3] Write system test "searching products" in test/system/shop_page_test.rb
- [ ] T048 [US3] Run tests - should FAIL (RED phase confirmed)

#### Implementation (GREEN Phase)

- [ ] T049 [US3] Implement Product.search scope in app/models/product.rb using ILIKE
- [ ] T050 [US3] Use sanitize_sql_like to prevent SQL injection
- [ ] T051 [US3] Update PagesController#shop to call .search(params[:q])
- [ ] T052 [P] [US3] Create app/frontend/javascript/controllers/search_controller.js
- [ ] T053 [P] [US3] Implement debounce method with 300ms delay in search_controller.js
- [ ] T054 [P] [US3] Register SearchController in app/frontend/entrypoints/application.js
- [ ] T055 [US3] Add search input in app/views/pages/shop.html.erb
- [ ] T056 [US3] Add data-controller="search" and data-action="input->search#debounce"
- [ ] T057 [US3] Add "No products found" empty state in shop.html.erb
- [ ] T058 [US3] Run model tests - should PASS (GREEN phase)
- [ ] T059 [US3] Run controller tests - should PASS (GREEN phase)
- [ ] T060 [US3] Run system tests - should PASS (GREEN phase)

#### Verification

- [ ] T061 [US3] Manual test: Enter "pizza" - matching products shown
- [ ] T062 [US3] Verify 300ms debounce delay (no request on each keystroke)
- [ ] T063 [US3] Verify URL parameter: /shop?q=pizza
- [ ] T064 [US3] Verify empty state shown when no matches

**Deliverable**: Search functionality with debouncing and URL persistence

---

## Phase 6: User Story 4 - Combine Filters (P3) (Est: 15 minutes)

**User Story**: As a customer, I want to combine category and search filters

**Goal**: Enable simultaneous category filter + search query

**Independent Test**: Select category + enter search - only products matching both shown

### Tasks

#### Tests (RED Phase)

- [ ] T065 [P] [US4] Write test "shop page combines filters" in test/controllers/pages_controller_test.rb
- [ ] T066 [P] [US4] Write system test "combining filters and search" in test/system/shop_page_test.rb
- [ ] T067 [US4] Run tests - should FAIL (RED phase confirmed)

#### Implementation (GREEN Phase)

- [ ] T068 [US4] Verify scope chaining works: Product.in_category(id).search(query)
- [ ] T069 [US4] Add "Clear Filters" button in app/views/pages/shop.html.erb
- [ ] T070 [US4] Show clear button only when filters active (if params[:category_id].present? || params[:q].present?)
- [ ] T071 [US4] Run controller tests - should PASS (GREEN phase)
- [ ] T072 [US4] Run system tests - should PASS (GREEN phase)

#### Verification

- [ ] T073 [US4] Manual test: Select category + search - both filters applied
- [ ] T074 [US4] Verify URL: /shop?category_id=3&q=8oz
- [ ] T075 [US4] Verify clearing one filter preserves the other

**Deliverable**: Combined category + search filtering with clear filters button

---

## Phase 7: User Story 5 - Sort Products (P3) (Est: 30 minutes)

**User Story**: As a customer, I want to sort products by price or name

**Goal**: Add sort dropdown with 4 options (relevance, price asc/desc, name)

**Independent Test**: Select sort option - products reordered correctly

### Tasks

#### Tests (RED Phase)

- [ ] T076 [P] [US5] Write test "sorted by relevance uses default order" in test/models/product_test.rb
- [ ] T077 [P] [US5] Write test "sorted by name_asc orders alphabetically" in test/models/product_test.rb
- [ ] T078 [P] [US5] Write test "sorted by price_asc orders by min variant price" in test/models/product_test.rb
- [ ] T079 [P] [US5] Write test "shop page sorts products by price" in test/controllers/pages_controller_test.rb
- [ ] T080 [P] [US5] Write system test "sorting products" in test/system/shop_page_test.rb
- [ ] T081 [US5] Run tests - should FAIL (RED phase confirmed)

#### Implementation (GREEN Phase)

- [ ] T082 [US5] Implement Product.sorted scope in app/models/product.rb
- [ ] T083 [US5] Handle price_asc: JOIN active_variants, MIN(price), ORDER BY min_price ASC
- [ ] T084 [US5] Handle price_desc: JOIN active_variants, MAX(price), ORDER BY max_price DESC
- [ ] T085 [US5] Handle name_asc: ORDER BY name ASC
- [ ] T086 [US5] Handle relevance/default: ORDER BY position ASC, name ASC
- [ ] T087 [US5] Update PagesController#shop to call .sorted(params[:sort])
- [ ] T088 [US5] Add sort dropdown in app/views/pages/shop.html.erb
- [ ] T089 [US5] Add 4 options: Relevance, Price Low-High, Price High-Low, Name A-Z
- [ ] T090 [US5] Add data-action="change->form#submit" for auto-submit
- [ ] T091 [US5] Run model tests - should PASS (GREEN phase)
- [ ] T092 [US5] Run controller tests - should PASS (GREEN phase)
- [ ] T093 [US5] Run system tests - should PASS (GREEN phase)

#### Verification

- [ ] T094 [US5] Manual test: Select "Price: Low to High" - products sorted
- [ ] T095 [US5] Verify URL parameter: /shop?sort=price_asc
- [ ] T096 [US5] Verify alphabetical sort works correctly

**Deliverable**: Product sorting with 4 options and URL persistence

---

## Phase 8: Polish & Performance (Est: 15 minutes)

**Goal**: Verify performance, test coverage, and code quality

### Tasks

#### Performance Verification

- [ ] T097 Start Rails server with `bin/dev`
- [ ] T098 Visit /shop page and check Bullet gem warnings (should be none)
- [ ] T099 Verify database queries count (~5 queries with eager loading)
- [ ] T100 Check browser console for JavaScript errors (should be none)
- [ ] T101 Verify page load time < 2 seconds

#### Test Coverage

- [ ] T102 Run all model tests: `rails test test/models/product_test.rb` - should PASS
- [ ] T103 Run all controller tests: `rails test test/controllers/pages_controller_test.rb` - should PASS
- [ ] T104 Run all system tests: `rails test:system test/system/shop_page_test.rb` - should PASS
- [ ] T105 Run full test suite: `rails test` - should PASS

#### Code Quality

- [ ] T106 Run RuboCop: `rubocop` - should PASS
- [ ] T107 Run Brakeman: `brakeman` - should have no new warnings
- [ ] T108 Verify system test pagination (if 25+ products exist)

#### Final Manual Testing

- [ ] T109 Test mobile responsive design (filters, grid, pagination)
- [ ] T110 Test browser back/forward buttons with filters
- [ ] T111 Test no-JavaScript fallback (form submission works)
- [ ] T112 Verify SEO meta tags present
- [ ] T113 Verify canonical URL correct

**Deliverable**: Verified performance, test coverage, code quality

---

## Dependencies & Execution Strategy

### User Story Dependencies

```
Phase 1 (Setup)
    ↓
Phase 2 (Foundational)
    ↓
Phase 3 (US1 - Browse) ← MUST complete first (MVP)
    ↓
    ├→ Phase 4 (US2 - Category Filter) [P2]
    ├→ Phase 5 (US3 - Search) [P2]
    └→ Phase 6 (US4 - Combined) [P3] (depends on US2 + US3)
    └→ Phase 7 (US5 - Sort) [P3]
    ↓
Phase 8 (Polish)
```

### Parallel Execution Opportunities

**Within Phase 3 (US1)**:
- T010, T011, T017 can run in parallel (tests + partial)

**Within Phase 4 (US2)**:
- T024-T027 (all test tasks) can run in parallel

**Within Phase 5 (US3)**:
- T042-T047 (test tasks) can run in parallel
- T052-T054 (Stimulus controller tasks) can run in parallel with T055-T057 (UI tasks)

**Within Phase 7 (US5)**:
- T076-T080 (all test tasks) can run in parallel

**Between Phases**:
- US2 (Category) and US3 (Search) are independent - can implement in parallel
- US5 (Sort) can be implemented in parallel with US4 (Combined)

### MVP Scope (Minimal Viable Product)

**Recommended MVP**: Phase 1-3 only (Setup + Foundational + US1)
- **Deliverable**: /shop page with all products + pagination
- **Time**: ~55 minutes
- **Value**: Immediate customer value (browse catalog)

**MVP + Core Features**: Phase 1-5 (add US2 + US3)
- **Deliverable**: Browse + Category Filter + Search
- **Time**: ~115 minutes (~2 hours)
- **Value**: Most common user needs covered

**Full Feature**: All phases
- **Deliverable**: Complete shop page with all features
- **Time**: ~2 hours 45 minutes
- **Value**: All user stories implemented

---

## Task Summary

**Total Tasks**: 113 tasks
**Parallelizable Tasks**: 23 tasks (marked with [P])
**Estimated Time**: ~2 hours 45 minutes (all phases), ~2 hours (MVP + Core)

**Tasks by User Story**:
- Setup & Foundational: 9 tasks (~15 min)
- US1 (Browse): 14 tasks (~40 min)
- US2 (Category): 18 tasks (~25 min)
- US3 (Search): 23 tasks (~35 min)
- US4 (Combined): 11 tasks (~15 min)
- US5 (Sort): 21 tasks (~30 min)
- Polish: 17 tasks (~15 min)

**Test Coverage**:
- Model tests: 12 tests across 3 scopes
- Controller tests: 6 tests
- System tests: 7 tests
- **Total**: 25 tests covering all user flows

**Files Modified/Created**:
- 1 gem added (Pagy)
- 1 initializer created
- 1 migration created
- 3 model scopes added
- 1 controller action updated
- 1 view updated
- 1 Stimulus controller created
- 1 partial created (if not exists)
- 3 test files updated/created

---

## Implementation Notes

**TDD Discipline**:
- NEVER skip writing tests first
- Tests must FAIL before writing implementation
- Verify tests PASS after implementation
- Refactor only after tests pass

**Common Pitfalls to Avoid**:
- Forgetting eager loading → N+1 queries
- Missing Turbo Frame ID match → frame not updating
- Skipping sanitize_sql_like → SQL injection vulnerability
- Not testing debounce → excessive server requests
- Missing indexes → slow queries

**Quality Gates**:
- All tests must pass before marking task complete
- RuboCop must pass before committing
- Brakeman must show no new warnings
- Manual testing checklist must be verified

---

## Next Steps After Task Completion

1. **Create Pull Request**: Use `/git-workflow:finish` or manual PR creation
2. **Request Code Review**: Tag appropriate reviewers
3. **Performance Testing**: Load test with 100+ products
4. **Analytics Setup**: Track popular searches and filters
5. **Future Enhancements**:
   - Price range filter
   - Featured products toggle
   - Infinite scroll option
   - Advanced search (fuzzy matching, suggestions)
   - Faceted search (multi-select categories)

---

**Status**: Ready for implementation
**Next Command**: Begin with Phase 1, Task T001
