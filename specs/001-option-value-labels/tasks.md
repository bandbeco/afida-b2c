# Tasks: Product Option Value Labels

**Input**: Design documents from `/specs/001-option-value-labels/`
**Prerequisites**: plan.md (✓), spec.md (✓), research.md (✓), data-model.md (✓), quickstart.md (✓)

**Tests**: Included per constitution requirement (Test-First Development)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Rails monolith**: `app/`, `db/`, `test/` at repository root
- Models: `app/models/`
- Views: `app/views/`
- Tests: `test/models/`, `test/system/`
- Migrations: `db/migrate/`
- Seeds: `db/seeds/`
- Fixtures: `test/fixtures/`

---

## Phase 1: Setup (Schema & Infrastructure)

**Purpose**: Database schema changes and new model creation

- [ ] T001 Create migration for variant_option_values table in db/migrate/YYYYMMDD_create_variant_option_values.rb
- [ ] T002 Create migration to remove option_values JSONB column in db/migrate/YYYYMMDD_remove_option_values_from_product_variants.rb
- [ ] T003 Run migrations with `rails db:migrate`

---

## Phase 2: Foundational (Core Model & Associations)

**Purpose**: Core model and associations that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundation ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T004 [P] Create test file for VariantOptionValue model in test/models/variant_option_value_test.rb
- [ ] T005 [P] Create fixture file for variant_option_values in test/fixtures/variant_option_values.yml

### Implementation for Foundation

- [ ] T006 Create VariantOptionValue model with associations and validations in app/models/variant_option_value.rb
- [ ] T007 Add has_many :variant_option_values association to ProductVariant in app/models/product_variant.rb
- [ ] T008 Add has_many :option_values through association to ProductVariant in app/models/product_variant.rb
- [ ] T009 Verify all foundation tests pass with `rails test test/models/variant_option_value_test.rb`

**Checkpoint**: Foundation ready - VariantOptionValue model exists with associations. User story implementation can now begin.

---

## Phase 3: User Story 1 & 2 - Display Labels & Variant Selector (Priority: P1) 🎯 MVP

**Goal**: Display human-readable option labels to customers and maintain variant selector sparse matrix filtering

**Independent Test**: View any product page with variants and verify labels display correctly; use variant selector and verify filtering works

> Note: US1 and US2 are combined because they share the same model methods and are both P1 priority. The label display and variant selector both depend on the same underlying data structure.

### Tests for User Stories 1 & 2 ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T010 [P] [US1] Add tests for option_values_hash method in test/models/product_variant_test.rb
- [ ] T011 [P] [US1] Add tests for option_labels_hash method in test/models/product_variant_test.rb
- [ ] T012 [P] [US1] Add tests for options_summary method in test/models/product_variant_test.rb
- [ ] T013 [P] [US2] Add tests for available_options method in test/models/product_test.rb
- [ ] T014 [P] [US2] Add tests for variants_for_selector method in test/models/product_test.rb

### Implementation for User Stories 1 & 2

- [ ] T015 [US1] Implement option_values_hash method on ProductVariant in app/models/product_variant.rb
- [ ] T016 [US1] Implement option_labels_hash method on ProductVariant in app/models/product_variant.rb
- [ ] T017 [US1] Implement options_summary method on ProductVariant in app/models/product_variant.rb
- [ ] T018 [US2] Implement available_options method on Product in app/models/product.rb
- [ ] T019 [US2] Update variants_for_selector method to use option_values_hash in app/models/product.rb
- [ ] T020 [US2] Remove extract_options_from_variants method from Product in app/models/product.rb
- [ ] T021 [US1] Update seed helper to assign options via join table in db/seeds/products_from_csv.rb
- [ ] T022 Verify model tests pass with `rails test test/models/product_variant_test.rb test/models/product_test.rb`
- [ ] T023 Run database reset to apply schema and seeds with `rails db:reset`

### View Updates for User Story 1

- [ ] T024 [P] [US1] Update quick add form to use option_labels_hash in app/views/products/_quick_add_form.html.erb
- [ ] T025 [US1] Remove option_value_label helper method from app/helpers/products_helper.rb
- [ ] T026 [US1] Search for any remaining option_values usage in views and update to use new methods

### System Test for User Stories 1 & 2

- [ ] T027 [US1] [US2] Add system test for variant selector behavior in test/system/variant_selector_test.rb
- [ ] T028 Run system tests with `rails test:system`

**Checkpoint**: At this point, User Stories 1 and 2 should be fully functional. Labels display correctly and variant selector filters properly.

---

## Phase 4: User Story 3 - Admin Manages Option Labels (Priority: P2)

**Goal**: Admin users can manage product option values with both stored values and display labels

**Independent Test**: Edit option values in admin and verify changes appear on product pages

> Note: The ProductOptionValue model already has `value` and `label` columns. This story verifies the admin UI works correctly with the new join table structure.

### Tests for User Story 3 ⚠️

- [ ] T029 [P] [US3] Add integration test for admin option value editing in test/integration/admin_product_options_test.rb

### Implementation for User Story 3

- [ ] T030 [US3] Verify admin product form works with new associations in app/views/admin/products/_form.html.erb
- [ ] T031 [US3] Verify admin product controller loads associations correctly in app/controllers/admin/products_controller.rb
- [ ] T032 Run integration tests with `rails test test/integration/`

**Checkpoint**: Admin can manage option labels, and changes are reflected on public product pages.

---

## Phase 5: User Story 4 - Data Integrity Enforcement (Priority: P2)

**Goal**: System prevents invalid option value assignments (one value per option type, values must exist)

**Independent Test**: Attempt to create invalid variant-option assignments and verify rejection

### Tests for User Story 4 ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T033 [P] [US4] Add test for one-value-per-option constraint in test/models/variant_option_value_test.rb
- [ ] T034 [P] [US4] Add test for referential integrity (non-existent option values rejected) in test/models/variant_option_value_test.rb
- [ ] T035 [P] [US4] Add test for deletion prevention when variants reference option value in test/models/product_option_value_test.rb

### Implementation for User Story 4

- [ ] T036 [US4] Verify database constraints prevent duplicate option type assignments (already in migration T001)
- [ ] T037 [US4] Add dependent: :restrict_with_error to ProductOptionValue for variant_option_values in app/models/product_option_value.rb
- [ ] T038 Run all model tests with `rails test test/models/`

**Checkpoint**: Data integrity is enforced at both database and model levels.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup

- [ ] T039 Run full test suite with `rails test`
- [ ] T040 Run system tests with `rails test:system`
- [ ] T041 Run RuboCop linter with `rubocop`
- [ ] T042 Run Brakeman security scanner with `brakeman`
- [ ] T043 Verify quickstart.md steps work correctly
- [ ] T044 Manual verification: browse product pages and use variant selector
- [ ] T045 Clean up any unused code or comments

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories 1 & 2 (Phase 3)**: Depends on Foundational phase completion
- **User Story 3 (Phase 4)**: Can run after Phase 3 or in parallel if staffed
- **User Story 4 (Phase 5)**: Can run after Phase 2 (foundational) - model-level only
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Stories 1 & 2 (P1)**: Combined - require same model methods, can start after Foundational (Phase 2)
- **User Story 3 (P2)**: Admin interface - can start after Phase 2, but testing benefits from Phase 3 completion
- **User Story 4 (P2)**: Data integrity - can start after Phase 2, independent of other stories

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Model changes before view changes
- Run tests after each implementation task
- Verify independently before moving to next story

### Parallel Opportunities

- T004, T005 can run in parallel (different files)
- T010, T011, T012, T013, T014 can run in parallel (different test files/methods)
- T024 can run in parallel with T025, T026 (different files)
- T029 can run in parallel with US4 tests
- T033, T034, T035 can run in parallel (different test methods)

---

## Parallel Example: Foundation Phase

```bash
# Launch foundation tests in parallel:
Task: "Create test file for VariantOptionValue model in test/models/variant_option_value_test.rb"
Task: "Create fixture file for variant_option_values in test/fixtures/variant_option_values.yml"
```

## Parallel Example: User Story 1 & 2 Tests

```bash
# Launch all model tests in parallel:
Task: "Add tests for option_values_hash method in test/models/product_variant_test.rb"
Task: "Add tests for option_labels_hash method in test/models/product_variant_test.rb"
Task: "Add tests for options_summary method in test/models/product_variant_test.rb"
Task: "Add tests for available_options method in test/models/product_test.rb"
Task: "Add tests for variants_for_selector method in test/models/product_test.rb"
```

---

## Implementation Strategy

### MVP First (User Stories 1 & 2 Only)

1. Complete Phase 1: Setup (migrations)
2. Complete Phase 2: Foundational (VariantOptionValue model)
3. Complete Phase 3: User Stories 1 & 2 (labels + selector)
4. **STOP and VALIDATE**: Test product pages and variant selector
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Stories 1 & 2 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 3 → Test admin interface → Deploy/Demo
4. Add User Story 4 → Verify data integrity → Deploy/Demo
5. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together (1 developer)
2. Once Foundational is done:
   - Developer A: User Stories 1 & 2 (model + views)
   - Developer B: User Story 4 (data integrity constraints)
3. After Phase 3:
   - Developer A: User Story 3 (admin verification)
   - Developer B: Polish phase

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence

## Summary

| Metric | Value |
|--------|-------|
| Total Tasks | 45 |
| Phase 1 (Setup) | 3 tasks |
| Phase 2 (Foundational) | 6 tasks |
| Phase 3 (US1 & US2 - MVP) | 19 tasks |
| Phase 4 (US3) | 4 tasks |
| Phase 5 (US4) | 6 tasks |
| Phase 6 (Polish) | 7 tasks |
| Parallel Opportunities | 15 tasks marked [P] |
| MVP Scope | Phases 1-3 (28 tasks) |
