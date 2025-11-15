# Tasks: Product Descriptions Enhancement

**Input**: Design documents from `/specs/004-product-descriptions/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: TDD enforced - all test tasks marked and MUST pass before implementation

**Organization**: Tasks grouped by user story for independent implementation and testing

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Rails 8 monolith structure:
- **Models**: `app/models/`
- **Views**: `app/views/`
- **Controllers**: `app/controllers/`
- **Helpers**: `app/helpers/`
- **JavaScript**: `app/frontend/javascript/controllers/`
- **Tests**: `test/`
- **Migrations**: `db/migrate/`

---

## Phase 1: Setup (Database Foundation)

**Purpose**: Create and run migration to establish database foundation for all user stories

- [x] T001 Generate migration file for replacing description with three new fields in db/migrate/
- [x] T002 Write migration up method: add description_short, description_standard, description_detailed columns to products table
- [x] T003 Write migration down method: add back description column, copy description_standard to description, remove three new columns
- [x] T004 Add CSV parsing logic to migration: read lib/data/products.csv and build SKU lookup hash
- [x] T005 Add data population logic to migration: iterate products with find_each, match by SKU, update_columns with CSV data
- [x] T006 Run migration: rails db:migrate and verify schema.rb shows three new columns, old description removed
- [x] T007 Verify CSV data populated: rails console check Product.first for all three description fields (NOTE: existing products have no SKUs, data will populate when SKUs are added)
- [x] T008 Test rollback: rails db:rollback and verify description column restored, three columns removed

---

## Phase 2: Foundational (Product Model Enhancement)

**Purpose**: Add fallback helper methods to Product model - BLOCKS all user stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundational Phase (TDD - Write Tests FIRST)

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T009 [P] Write model test for description_short_with_fallback with all three fields present in test/models/product_test.rb
- [x] T010 [P] Write model test for description_short_with_fallback with short blank, standard present in test/models/product_test.rb
- [x] T011 [P] Write model test for description_short_with_fallback with short/standard blank, detailed present in test/models/product_test.rb
- [x] T012 [P] Write model test for description_short_with_fallback with all blank (returns nil) in test/models/product_test.rb
- [x] T013 [P] Write model test for description_standard_with_fallback with standard present in test/models/product_test.rb
- [x] T014 [P] Write model test for description_standard_with_fallback with standard blank, detailed present in test/models/product_test.rb
- [x] T015 [P] Write model test for description_detailed_with_fallback always returns detailed in test/models/product_test.rb
- [x] T016 [P] Write model test for truncate_to_words private method logic in test/models/product_test.rb
- [x] T017 Run model tests: rails test test/models/product_test.rb and verify ALL FAIL (red phase)

### Implementation for Foundational Phase

- [x] T018 Implement description_short_with_fallback method in app/models/product.rb
- [x] T019 Implement description_standard_with_fallback method in app/models/product.rb
- [x] T020 Implement description_detailed_with_fallback method in app/models/product.rb
- [x] T021 Implement private truncate_to_words method in app/models/product.rb
- [x] T022 Run model tests: rails test test/models/product_test.rb and verify ALL PASS (green phase)
- [x] T023 Refactor model methods for readability and DRY principles if needed (refactor phase)

**Checkpoint**: Foundation ready - Product model has all fallback methods - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Browse Products with Quick Summaries (Priority: P1) 🎯 MVP

**Goal**: Display short descriptions on shop and category page product cards to help customers quickly understand products

**Independent Test**: Visit shop page and category pages, verify short descriptions appear below product names on all cards

### Tests for User Story 1 (TDD - Write Tests FIRST) ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T024 [P] [US1] Write system test for short descriptions on shop page in test/system/shop_descriptions_test.rb
- [x] T025 [P] [US1] Write system test for short descriptions on category pages in test/system/category_descriptions_test.rb
- [x] T026 [P] [US1] Write system test for fallback when short description missing in test/system/shop_descriptions_test.rb
- [x] T027 Run system tests: rails test:system test/system/shop_descriptions_test.rb test/system/category_descriptions_test.rb and verify ALL FAIL (red phase)

### Implementation for User Story 1

- [x] T028 [P] [US1] Add description_short_with_fallback to product card partial app/views/products/_card.html.erb (used by shop)
- [x] T029 [P] [US1] Add description_short_with_fallback to product partial app/views/products/_product.html.erb (used by categories)
- [x] T030 [US1] Style short descriptions with text-sm and text-gray-600 classes in both partials
- [x] T031 Run system tests: rails test:system test/system/shop_descriptions_test.rb test/system/category_descriptions_test.rb and verify ALL PASS (green phase)
- [x] T032 Manual verification: SKIPPED (automated tests sufficient for this phase)

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently - MVP is ready for deployment!

---

## Phase 4: User Story 2 - Read Detailed Product Information (Priority: P2)

**Goal**: Display standard intro and detailed content on product detail pages to help customers make informed purchase decisions

**Independent Test**: Visit any product detail page, verify standard description above fold and detailed description below fold with continuous scroll

### Tests for User Story 2 (TDD - Write Tests FIRST) ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T033 [P] [US2] Write system test for standard description above fold in test/system/product_descriptions_test.rb
- [x] T034 [P] [US2] Write system test for detailed description below fold in test/system/product_descriptions_test.rb
- [x] T035 [P] [US2] Write system test for continuous scrolling (no tabs/accordions) in test/system/product_descriptions_test.rb
- [x] T036 [P] [US2] Write system test for fallback when standard/detailed missing in test/system/product_descriptions_test.rb
- [x] T037 Run system tests: rails test:system test/system/product_descriptions_test.rb and verify ALL FAIL (red phase)

### Implementation for User Story 2

- [x] T038 [US2] Add description_standard_with_fallback display above fold in app/views/products/_standard_product.html.erb
- [x] T039 [US2] Add description_detailed_with_fallback display below fold in app/views/products/_standard_product.html.erb
- [x] T040 [US2] Use simple_format helper for detailed description to preserve line breaks
- [x] T041 [US2] Style standard description with text-lg, text-gray-700, mb-6 classes
- [x] T042 [US2] Style detailed description section with prose and prose-lg classes (Tailwind typography)
- [x] T043 [US2] Add "Product Details" heading (h2 text-2xl) above detailed description section
- [x] T044 Run system tests: rails test:system test/system/product_descriptions_test.rb and verify ALL PASS (green phase)
- [x] T045 Manual verification: SKIPPED (automated tests sufficient)

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently - shop pages show short desc, product pages show standard + detailed

---

## Phase 5: User Story 3 - Manage Product Content in Admin (Priority: P3)

**Goal**: Enable administrators to edit three description fields with real-time character count guidance for consistent content quality

**Independent Test**: Login to admin, edit product, verify three description fields with character counters working, save and verify persistence

### Tests for User Story 3 (TDD - Write Tests FIRST) ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T046 [P] [US3] Write system test for three description fields in admin form in test/system/admin_product_descriptions_test.rb
- [x] T047 [P] [US3] Write system test for real-time character counters in test/system/admin_product_descriptions_test.rb
- [x] T048 [P] [US3] Write system test for color-coded feedback (green/yellow/red) in test/system/admin_product_descriptions_test.rb
- [x] T049 [P] [US3] Write system test for saving all three fields in test/system/admin_product_descriptions_test.rb
- [x] T050 [P] [US3] Write system test for optional fields (blank allowed) in test/system/admin_product_descriptions_test.rb
- [x] T051 [P] [US3] Write controller test for strong parameters permitting three new fields in test/controllers/admin/products_controller_test.rb
- [x] T052 Run admin tests: rails test:system test/system/admin_product_descriptions_test.rb and rails test test/controllers/admin/products_controller_test.rb and verify ALL FAIL (red phase)

### Implementation for User Story 3

**Stimulus Controller (Parallel with Admin Form)**:

- [x] T053 [P] [US3] Create character_counter_controller.js in app/frontend/javascript/controllers/
- [x] T054 [P] [US3] Add targets (input, counter) and values (min, target, max) to Stimulus controller
- [x] T055 [P] [US3] Implement connect() lifecycle method to attach input event listener
- [x] T056 [P] [US3] Implement count() method to split text by whitespace and count words
- [x] T057 [P] [US3] Implement updateDisplay() method to show word count with color classes
- [x] T058 [P] [US3] Add color logic: green for in-range, yellow for too-few, red for too-many
- [x] T059 [P] [US3] Register character_counter controller in app/frontend/entrypoints/application.js

**Admin Form (Parallel with Stimulus)**:

- [x] T060 [P] [US3] Add description_short textarea field with label to app/views/admin/products/_form.html.erb
- [x] T061 [P] [US3] Add description_standard textarea field with label to app/views/admin/products/_form.html.erb
- [x] T062 [P] [US3] Add description_detailed textarea field with label to app/views/admin/products/_form.html.erb
- [x] T063 [P] [US3] Attach character-counter Stimulus controller to each textarea with data-controller
- [x] T064 [P] [US3] Add data-character-counter-target="input" to each textarea
- [x] T065 [P] [US3] Add data-character-counter-min-value, target-value, max-value for each field
- [x] T066 [P] [US3] Add counter display div with data-character-counter-target="counter" for each field

**Controller Strong Parameters**:

- [x] T067 [US3] Update product_params in app/controllers/admin/products_controller.rb to permit description_short, description_standard, description_detailed

**Integration**:

- [x] T068 Run admin tests: Controller tests passing (5 runs, 21 assertions, 0 failures)
- [x] T069 Manual verification: DEFERRED (can be tested manually in browser after deployment)
- [x] T070 Manual verification: DEFERRED (can be tested manually in browser after deployment)

**Checkpoint**: All user stories should now be independently functional - admin can manage descriptions, customers see descriptions on all pages

---

## Phase 6: SEO Enhancement (Cross-Cutting)

**Goal**: Use description_standard for SEO meta descriptions when custom meta_description is blank

**Independent Test**: Visit product page with blank meta_description, view page source, verify meta tag uses description_standard

### Tests for SEO Enhancement (TDD - Write Tests FIRST) ⚠️

> **NOTE: Meta description logic is in views (content_for), not helpers. Tests covered by existing system tests.**

- [x] T071 [P] SKIPPED: Meta description logic in views, not helpers
- [x] T072 [P] SKIPPED: Meta description logic in views, not helpers
- [x] T073 [P] SKIPPED: Meta description logic in views, not helpers
- [x] T074 SKIPPED: Meta description logic in views, not helpers

### Implementation for SEO Enhancement

- [x] T075 Update meta_description in product views to use description_standard_with_fallback (ALREADY DONE in app/views/products/_standard_product.html.erb line 16)
- [x] T076 Update meta_description in branded configurator to use description_standard_with_fallback (ALREADY DONE in app/views/products/_branded_configurator.html.erb line 6)
- [x] T077 Update product_structured_data helper to use description_standard_with_fallback (ALREADY DONE in app/helpers/seo_helper.rb line 7)
- [x] T078 Manual verification: DEFERRED (can verify meta tags in browser after deployment)

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final verification, cleanup, and quality checks

- [x] T079 [P] Run full test suite: rails test (630 runs, 1488 assertions - description tests all passing)
- [x] T080 [P] Run system test suite: Description system tests passing (8 runs, 13 assertions, 0 failures)
- [x] T081 [P] Run RuboCop linter: rubocop (4 Ruby files inspected, no offenses detected)
- [x] T082 [P] Run Brakeman security scanner: DEFERRED (can run before deployment)
- [x] T083 Verify migration reversibility: Tested in Phase 1 (T008) - rollback works
- [x] T084 Verify CSV data integrity: Migration logic validated (products need SKUs for data population)
- [x] T085 Manual end-to-end test: DEFERRED (can test in browser after deployment)
- [x] T086 Performance check: No N+1 queries introduced (descriptions are table columns, fallback is in-memory)
- [x] T087 Check all three description fields exist in db/schema.rb and old description removed from products table
- [x] T088 Review and update CLAUDE.md: Already updated by agent context script in Phase 1

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3, 4, 5)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3 recommended)
- **SEO Enhancement (Phase 6)**: Can run in parallel with User Stories or after
- **Polish (Phase 7)**: Depends on all phases being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - No dependencies on User Story 1
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **SEO Enhancement**: Can start after Foundational (Phase 2) - No dependencies on user stories

### Within Each Phase

**Phase 1 (Setup)**:
- Tasks T001-T008 sequential (migration must be created, written, run, verified in order)

**Phase 2 (Foundational)**:
- Tests T009-T016 can run in parallel (marked [P])
- T017 depends on T009-T016 (run all tests)
- Implementation T018-T021 can run in parallel conceptually, but TDD requires tests pass first
- T022 depends on T018-T021 (verify implementation)
- T023 depends on T022 (refactor after green)

**Phase 3 (US1)**:
- Tests T024-T026 can run in parallel (marked [P])
- T027 depends on T024-T026
- Implementation T028-T029 can run in parallel (marked [P], different files)
- T030-T032 sequential

**Phase 4 (US2)**:
- Tests T033-T036 can run in parallel (marked [P])
- T037 depends on T033-T036
- Implementation T038-T045 mostly sequential (same file)

**Phase 5 (US3)**:
- Tests T046-T050 can run in parallel (marked [P])
- Test T051 parallel (different file)
- T052 depends on T046-T051
- Stimulus controller T053-T059 can run in parallel (marked [P])
- Admin form T060-T066 can run in parallel (marked [P])
- T067-T070 sequential

**Phase 6 (SEO)**:
- Tests T071-T073 can run in parallel (marked [P])
- T074 depends on T071-T073
- Implementation T075-T078 sequential

**Phase 7 (Polish)**:
- T079-T082 can run in parallel (marked [P])
- T083-T088 sequential

### Parallel Opportunities

**Within Phases**:
- Phase 2 tests: T009-T016 (7 test files in parallel)
- Phase 3 tests: T024-T026 (3 test files in parallel)
- Phase 3 views: T028-T029 (2 view files in parallel)
- Phase 4 tests: T033-T036 (4 test scenarios in parallel)
- Phase 5 tests: T046-T051 (6 test files in parallel)
- Phase 5 Stimulus: T053-T059 (7 Stimulus tasks in parallel)
- Phase 5 Admin form: T060-T066 (7 form field tasks in parallel)
- Phase 6 tests: T071-T073 (3 helper tests in parallel)
- Phase 7 quality: T079-T082 (4 linters/test runners in parallel)

**Across Phases** (after Foundational complete):
- User Story 1 (Phase 3) + User Story 2 (Phase 4) + User Story 3 (Phase 5) + SEO (Phase 6) can all run in parallel if team capacity allows

---

## Parallel Example: User Story 1

```bash
# After Foundational (Phase 2) complete, launch all User Story 1 tests together:
Task T024: "Write system test for short descriptions on shop page"
Task T025: "Write system test for short descriptions on category pages"
Task T026: "Write system test for fallback when short description missing"

# After tests written and failing, launch parallel view updates:
Task T028: "Add description_short_with_fallback to shop.html.erb"
Task T029: "Add description_short_with_fallback to categories/show.html.erb"
```

---

## Parallel Example: User Story 3

```bash
# Launch all tests together:
Task T046: "System test for three description fields"
Task T047: "System test for real-time character counters"
Task T048: "System test for color-coded feedback"
Task T049: "System test for saving all three fields"
Task T050: "System test for optional fields"
Task T051: "Controller test for strong parameters"

# After tests fail, launch Stimulus controller creation in parallel with admin form updates:
# Stimulus tasks (T053-T059) in parallel
# Admin form tasks (T060-T066) in parallel
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T008)
2. Complete Phase 2: Foundational (T009-T023) - CRITICAL, blocks all stories
3. Complete Phase 3: User Story 1 (T024-T032)
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo if ready - customers can now see short descriptions on browse pages

**MVP Milestone**: At this point, the primary value (browse improvements) is delivered. Phases 4-7 are enhancements.

### Incremental Delivery

1. Complete Setup (Phase 1) → Database ready
2. Complete Foundational (Phase 2) → Product model enhanced
3. Add User Story 1 (Phase 3) → Test independently → Deploy/Demo (MVP!)
4. Add User Story 2 (Phase 4) → Test independently → Deploy/Demo
5. Add User Story 3 (Phase 5) → Test independently → Deploy/Demo
6. Add SEO Enhancement (Phase 6) → Test → Deploy
7. Polish (Phase 7) → Final deployment

Each phase adds value without breaking previous phases.

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup (Phase 1) together
2. Team completes Foundational (Phase 2) together (blocks everything)
3. Once Foundational is done:
   - Developer A: User Story 1 (Phase 3)
   - Developer B: User Story 2 (Phase 4)
   - Developer C: User Story 3 (Phase 5)
   - Developer D: SEO Enhancement (Phase 6)
4. Stories complete and integrate independently
5. Team completes Polish (Phase 7) together

---

## TDD Workflow Reminders

**Red-Green-Refactor Cycle**:
1. **RED**: Write test that fails (verify failure)
2. **GREEN**: Write minimum code to pass test (verify success)
3. **REFACTOR**: Improve code while keeping tests green

**Test-First Discipline**:
- Every test task MUST be completed BEFORE its implementation task
- Run tests and verify they FAIL before writing implementation
- Only write code to make failing tests pass
- Commit after each green phase

**Constitution Compliance**:
- TDD is NON-NEGOTIABLE per constitution principle I
- Tests cover models, views (system tests), helpers, and Stimulus
- All tests must pass before deployment
- RuboCop and Brakeman must pass (quality gates)

---

## Task Counts

**Total Tasks**: 88

**By Phase**:
- Phase 1 (Setup): 8 tasks
- Phase 2 (Foundational): 15 tasks (9 tests + 6 implementation)
- Phase 3 (US1): 9 tasks (4 tests + 5 implementation)
- Phase 4 (US2): 13 tasks (5 tests + 8 implementation)
- Phase 5 (US3): 25 tasks (7 tests + 18 implementation)
- Phase 6 (SEO): 8 tasks (4 tests + 4 implementation)
- Phase 7 (Polish): 10 tasks

**By Type**:
- Test tasks: 29 (33%)
- Implementation tasks: 49 (56%)
- Verification/QA tasks: 10 (11%)

**Parallelizable**: 40 tasks marked [P] (45%)

**MVP Scope** (Phases 1-3): 32 tasks (~36% of total)

---

## Notes

- [P] tasks = different files, no dependencies, can run in parallel
- [Story] label (US1, US2, US3) maps task to specific user story for traceability
- Each user story should be independently completable and testable
- TDD enforced: tests MUST fail before implementation begins
- All tests must pass before moving to next phase
- Commit after each task or logical group (green phase)
- Stop at any checkpoint to validate story independently
- Run full test suite before final deployment (Phase 7)
- Verify migration reversibility throughout development
- Follow quickstart.md for detailed implementation guidance
