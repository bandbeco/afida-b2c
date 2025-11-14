# Tasks: Legacy URL Smart Redirects

**Input**: Design documents from `/specs/001-legacy-url-redirects/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Tests already exist for the infrastructure. Additional validation tests will be added for seed data integrity.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Rails app**: Standard Rails structure (`app/`, `db/`, `config/`, `test/`)
- All paths shown are relative to Rails application root

## Phase 1: Setup (Verification & Prerequisites)

**Purpose**: Verify existing infrastructure and ensure prerequisites are met

- [X] T001 [P] Verify database migration exists and schema in db/migrate/20251113195313_create_legacy_redirects.rb
- [X] T002 [P] Verify LegacyRedirect model exists in app/models/legacy_redirect.rb
- [X] T003 [P] Verify middleware exists in app/middleware/legacy_redirect_middleware.rb
- [X] T004 [P] Verify CSV mapping file exists at config/legacy_redirects.csv with 64 mappings
- [X] T005 Run database migration if not already applied: rails db:migrate

---

## Phase 2: Foundational (Seed File Implementation)

**Purpose**: Core seed file implementation that MUST be complete before testing redirects

**⚠️ CRITICAL**: No redirect testing can begin until seed data is loaded

- [X] T006 Update seed file to parse CSV in db/seeds/legacy_redirects.rb (add CSV parsing logic)
- [X] T007 Add URL parsing logic to extract target_slug from target URL in db/seeds/legacy_redirects.rb
- [X] T008 Add variant parameter extraction logic using URI.decode_www_form in db/seeds/legacy_redirects.rb
- [X] T009 Implement idempotent seeding using find_or_create_by! in db/seeds/legacy_redirects.rb
- [X] T010 Add progress output and statistics reporting in db/seeds/legacy_redirects.rb
- [X] T011 Run RuboCop linter on updated seed file: rubocop db/seeds/legacy_redirects.rb

**Checkpoint**: Seed file ready for execution

---

## Phase 3: User Story 1 - Legacy URL Visitor Redirect (Priority: P1) 🎯 MVP

**Goal**: Seed database with all 64 legacy URL redirects and verify they work correctly, redirecting users from legacy URLs to correct product pages with variants pre-selected

**Independent Test**: Visit any legacy URL (e.g., `/product/12-310-x-310mm-pizza-box-kraft`) and verify it redirects to the correct product page with HTTP 301 status and correct variant selected

### Validation Tests for User Story 1

> **NOTE: These tests verify seed data integrity before running seeds**

- [ ] T012 [P] [US1] Add validation test to verify all CSV target slugs exist in products table in test/models/legacy_redirect_test.rb
- [ ] T013 [P] [US1] Add validation test to verify CSV parsing correctness in test/models/legacy_redirect_test.rb

### Implementation for User Story 1

- [X] T014 [US1] Run database seeds to populate redirects: rails runner "load Rails.root.join('db/seeds/legacy_redirects.rb')"
- [X] T015 [US1] Verify seed count matches expected 64 redirects: rails runner "puts LegacyRedirect.count"
- [X] T016 [US1] Verify all target products exist: rails runner "LegacyRedirect.find_each { |r| r.valid? || puts r.errors.full_messages }"

### Integration Testing for User Story 1

- [X] T017 [US1] Run existing redirect integration tests: rails test test/integration/legacy_redirect_flow_test.rb
- [X] T018 [US1] Run existing middleware tests: rails test test/middleware/legacy_redirect_middleware_test.rb
- [X] T019 [US1] Run existing model tests: rails test test/models/legacy_redirect_test.rb

### Manual Browser Testing for User Story 1

- [ ] T020 [US1] Start development server: bin/dev
- [ ] T021 [US1] Test pizza box redirect: Visit http://localhost:3000/product/12-310-x-310mm-pizza-box-kraft and verify 301 to /products/pizza-box?size=12in&colour=kraft
- [ ] T022 [US1] Test hot cup redirect: Visit http://localhost:3000/product/8oz-227ml-single-wall-paper-hot-cup-white and verify 301 to /products/single-wall-paper-hot-cup?size=8oz&colour=white
- [ ] T023 [US1] Test straw redirect: Visit http://localhost:3000/product/6mm-x-200mm-bamboo-fibre-straws-black and verify 301 to /products/bio-fibre-straws?size=6x200mm&colour=black
- [ ] T024 [US1] Test napkin redirect: Visit http://localhost:3000/product/4-fold-white-2ply-dinner-napkins-40cm-x-40cm and verify 301 to /products/dinner-napkins-4-fold-2-ply?size=40x40cm&colour=white
- [ ] T025 [US1] Test bowl redirect: Visit http://localhost:3000/product/rectangular-kraft-food-bowl-500ml and verify 301 to /products/rectangular-kraft-food-bowl?size=500ml&colour=kraft
- [ ] T026 [US1] Verify variant pre-selection works correctly on product pages (check size/colour dropdowns)
- [ ] T027 [US1] Verify add to cart functionality works with redirected variant
- [ ] T028 [US1] Check hit_count increments in database: rails runner "puts LegacyRedirect.find_by_path('/product/12-310-x-310mm-pizza-box-kraft').hit_count"

**Checkpoint**: At this point, all 64 legacy URLs should redirect correctly with HTTP 301 status, and variants should be pre-selected on product pages

---

## Phase 4: User Story 2 - Unmapped URL Fallback (Priority: P2)

**Goal**: Verify graceful fallback behavior for unmapped legacy URLs (404 page with helpful navigation)

**Independent Test**: Visit a legacy URL pattern that doesn't exist in database (e.g., `/product/unknown-product-xyz`) and verify appropriate 404 page appears

### Testing for User Story 2

- [ ] T029 [US2] Test unmapped URL fallback: Visit http://localhost:3000/product/unknown-product-xyz and verify 404 page appears
- [ ] T030 [US2] Verify 404 page contains helpful search functionality or category navigation
- [ ] T031 [US2] Test case-insensitive matching: Visit http://localhost:3000/product/Pizza-Box-Kraft and verify redirect works
- [ ] T032 [US2] Test URL with trailing slash: Visit http://localhost:3000/product/12-310-x-310mm-pizza-box-kraft/ and verify redirect works

**Checkpoint**: Unmapped URLs and edge cases handled gracefully

---

## Phase 5: User Story 3 - Administrator Analytics & Management (Priority: P3)

**Goal**: Verify admin interface works for viewing and managing redirects

**Independent Test**: Access admin interface, view redirect list with hit counts, and verify CRUD operations work

### Testing for User Story 3

- [ ] T033 [US3] Access admin redirect management interface at http://localhost:3000/admin/legacy_redirects
- [ ] T034 [US3] Verify redirect list displays all 64 mappings with hit counts
- [ ] T035 [US3] Verify redirects are sortable by hit count (most used first)
- [ ] T036 [US3] Test creating a new redirect via admin interface
- [ ] T037 [US3] Test editing an existing redirect via admin interface
- [ ] T038 [US3] Test deactivating a redirect and verify it stops working immediately
- [ ] T039 [US3] Test reactivating a redirect and verify it works again
- [ ] T040 [US3] Run existing admin controller tests: rails test test/controllers/admin/legacy_redirects_controller_test.rb
- [ ] T041 [US3] Run existing admin integration tests: rails test test/integration/admin_legacy_redirects_test.rb

**Checkpoint**: Admin interface fully functional for managing redirects

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, performance checks, and documentation

- [X] T042 [P] Run all redirect-related tests together: rails test test/models/legacy_redirect_test.rb test/middleware/legacy_redirect_middleware_test.rb test/controllers/admin/legacy_redirects_controller_test.rb test/integration/legacy_redirect_flow_test.rb test/system/legacy_redirect_system_test.rb
- [X] T043 [P] Run full test suite to ensure no regressions: rails test
- [ ] T044 [P] Benchmark redirect response time and verify <500ms goal: See quickstart.md for benchmark script
- [ ] T045 [P] Verify middleware overhead is <10ms per request
- [ ] T046 [P] Document seed file approach in db/seeds/legacy_redirects.rb comments
- [X] T047 Run RuboCop on all modified files: rubocop db/seeds/legacy_redirects.rb
- [X] T048 Run Brakeman security scanner: brakeman
- [ ] T049 Verify all acceptance scenarios from spec.md are passing
- [ ] T050 Update CLAUDE.md with any learnings or patterns discovered

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup (Phase 1) - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User Story 1 (P1): MUST complete first - core functionality
  - User Story 2 (P2): Can test after User Story 1 complete - validates fallback behavior
  - User Story 3 (P3): Can test after User Story 1 complete - validates admin features
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Should test after User Story 1 to verify fallback behavior works correctly
- **User Story 3 (P3)**: Should test after User Story 1 to verify admin can manage existing redirects

### Within Each User Story

- Validation tests → Seed execution → Integration tests → Manual browser testing
- Core redirect functionality (US1) before edge cases (US2) and admin features (US3)
- All tests should pass before moving to next priority

### Parallel Opportunities

- **Phase 1** (Setup): All verification tasks (T001-T004) can run in parallel
- **Phase 3** (US1 Validation): Tests T012 and T013 can run in parallel
- **Phase 3** (US1 Integration): Tests T017, T018, T019 can run in parallel after seeds complete
- **Phase 6** (Polish): Tasks T042, T043, T044, T045, T046 can run in parallel

---

## Parallel Example: User Story 1 Validation

```bash
# Launch validation tests in parallel:
Task: "Add validation test to verify all CSV target slugs exist in products table in test/models/legacy_redirect_test.rb"
Task: "Add validation test to verify CSV parsing correctness in test/models/legacy_redirect_test.rb"

# Launch integration tests in parallel after seeding:
Task: "Run existing redirect integration tests: rails test test/integration/legacy_redirect_flow_test.rb"
Task: "Run existing middleware tests: rails test test/middleware/legacy_redirect_middleware_test.rb"
Task: "Run existing model tests: rails test test/models/legacy_redirect_test.rb"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (verify infrastructure)
2. Complete Phase 2: Foundational (implement seed file with CSV parsing)
3. Complete Phase 3: User Story 1 (seed data, test redirects)
4. **STOP and VALIDATE**: Test 5-10 sample redirects manually in browser
5. Verify all existing tests pass
6. Consider MVP complete if redirects work correctly

### Incremental Delivery

1. Complete Setup + Foundational → Seeds can be run
2. Add User Story 1 → Test independently → Redirects working (MVP!)
3. Add User Story 2 → Test independently → Edge cases handled
4. Add User Story 3 → Test independently → Admin interface verified
5. Each story adds value without breaking previous stories

### Single Developer Strategy

**Recommended approach** (since infrastructure already exists):

1. **Day 1**: Complete Phases 1-2 (verify infrastructure, implement seed file)
   - Focus: T001-T011 (setup + seed file implementation)
   - Outcome: Seed file ready to run

2. **Day 2**: Complete Phase 3 User Story 1 (core redirect functionality)
   - Focus: T012-T028 (validation, seeding, testing)
   - Outcome: All 64 redirects working, tested, validated

3. **Optional Day 3**: Complete Phases 4-6 (edge cases, admin, polish)
   - Focus: T029-T050 (fallback behavior, admin verification, final polish)
   - Outcome: Complete feature with edge cases and admin features verified

---

## Quick Reference Commands

### Seed and Verify

```bash
# Run seeds
rails runner "load Rails.root.join('db/seeds/legacy_redirects.rb')"

# Verify count
rails runner "puts LegacyRedirect.count"  # Expected: 64

# Verify all valid
rails runner "LegacyRedirect.find_each { |r| r.valid? || puts r.errors.full_messages }"

# Check first 5 redirects
rails runner "puts LegacyRedirect.limit(5).pluck(:legacy_path, :target_slug)"
```

### Run Tests

```bash
# Run all redirect tests
rails test test/models/legacy_redirect_test.rb
rails test test/middleware/legacy_redirect_middleware_test.rb
rails test test/integration/legacy_redirect_flow_test.rb

# Run full test suite
rails test
```

### Manual Browser Testing

```bash
# Start server
bin/dev

# Test sample URLs (open in browser or use curl -I to see 301 status):
curl -I http://localhost:3000/product/12-310-x-310mm-pizza-box-kraft
curl -I http://localhost:3000/product/8oz-227ml-single-wall-paper-hot-cup-white
```

### Admin Interface

```
http://localhost:3000/admin/legacy_redirects
```

---

## Notes

- [P] tasks = different files, no dependencies, can run concurrently
- [Story] label maps task to specific user story for traceability
- Infrastructure already exists - this is primarily a data seeding and testing task
- Most work is in Phase 2 (seed file) and Phase 3 (validation/testing)
- Existing tests should already pass - we're verifying behavior, not writing new tests
- Focus on verifying redirects work correctly with real browser testing
- Commit seed file changes before running seeds
- Stop at any checkpoint to validate independently
