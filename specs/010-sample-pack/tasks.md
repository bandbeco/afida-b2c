# Tasks: Sample Pack Feature

**Input**: Design documents from `/specs/010-sample-pack/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included per constitution principle I (Test-First Development - NON-NEGOTIABLE)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

- **Rails app**: `app/` for source, `test/` for tests at repository root

---

## Phase 1: Setup

**Purpose**: Verify environment and create test fixtures

- [ ] T001 Run existing test suite to verify baseline (`rails test`)
- [ ] T002 Create sample pack test fixture in `test/fixtures/products.yml` (add sample-pack product entry)
- [ ] T003 Create sample pack variant test fixture in `test/fixtures/product_variants.yml`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add Product model methods that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundation

- [ ] T004 Write failing test for `Product::SAMPLE_PACK_SLUG` constant in `test/models/product_test.rb`
- [ ] T005 [P] Write failing test for `Product#sample_pack?` method in `test/models/product_test.rb`
- [ ] T006 [P] Write failing test for `Product.shoppable` scope in `test/models/product_test.rb`

### Implementation for Foundation

- [ ] T007 Add `SAMPLE_PACK_SLUG = "sample-pack".freeze` constant to `app/models/product.rb`
- [ ] T008 Add `sample_pack?` instance method to `app/models/product.rb`
- [ ] T009 Add `shoppable` scope to `app/models/product.rb`
- [ ] T010 Run tests to verify foundation passes (`rails test test/models/product_test.rb`)

**Checkpoint**: Foundation ready - `sample_pack?` and `shoppable` scope work correctly

---

## Phase 3: User Story 1 - Add Sample Pack to Cart (Priority: P1) 🎯 MVP

**Goal**: Visitors can add sample pack to cart from landing page and product page with "Free — just pay shipping" display

**Independent Test**: Visit `/samples`, click "Add to Cart", verify item appears in cart with "Free" price display

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T011 [P] [US1] Write failing test for `PagesController#samples` loading sample pack in `test/controllers/pages_controller_test.rb`
- [ ] T012 [P] [US1] Write failing system test for samples landing page in `test/system/sample_pack_test.rb`
- [ ] T013 [P] [US1] Write failing system test for product page quantity hidden in `test/system/sample_pack_product_page_test.rb`

### Implementation for User Story 1

- [ ] T014 [US1] Update `samples` action in `app/controllers/pages_controller.rb` to load sample pack product
- [ ] T015 [US1] Redesign samples landing page in `app/views/pages/samples.html.erb` with hero, "What's Included", and CTA
- [ ] T016 [US1] Add conditional to hide quantity selector for sample pack in `app/views/products/_standard_product.html.erb`
- [ ] T017 [US1] Add "Free — just pay shipping" price display for sample pack in product views
- [ ] T018 [US1] Add "Free" display for sample pack in `app/views/carts/_cart_item.html.erb`
- [ ] T019 [US1] Run US1 tests to verify implementation (`rails test test/system/sample_pack_test.rb test/system/sample_pack_product_page_test.rb`)

**Checkpoint**: User Story 1 complete - visitors can add sample pack from landing page with proper display

---

## Phase 4: User Story 2 - Limit Sample Pack Quantity (Priority: P2)

**Goal**: Only one sample pack allowed per order, with friendly message if trying to add second

**Independent Test**: Add sample pack to cart, try to add again, verify flash message "Sample pack already in your cart"

### Tests for User Story 2

- [ ] T020 [P] [US2] Write failing test for `Cart#has_sample_pack?` in `test/models/cart_test.rb`
- [ ] T021 [P] [US2] Write failing test for `Cart#sample_pack_quantity_limit` validation in `test/models/cart_test.rb`
- [ ] T022 [P] [US2] Write failing test for CartItemsController redirect when sample pack in cart in `test/controllers/cart_items_controller_test.rb`

### Implementation for User Story 2

- [ ] T023 [US2] Add `has_sample_pack?` method to `app/models/cart.rb`
- [ ] T024 [US2] Add `sample_pack_quantity_limit` validation to `app/models/cart.rb`
- [ ] T025 [US2] Add guard clause in `create` action of `app/controllers/cart_items_controller.rb` for sample pack check
- [ ] T026 [US2] Run US2 tests to verify implementation (`rails test test/models/cart_test.rb test/controllers/cart_items_controller_test.rb`)

**Checkpoint**: User Story 2 complete - sample pack limited to 1 per order with friendly message

---

## Phase 5: User Story 3 - Mix Samples with Products (Priority: P3)

**Goal**: Sample pack can coexist with regular products in cart, checkout works unchanged

**Independent Test**: Add sample pack AND regular product to cart, complete checkout, verify order shows both items

### Tests for User Story 3

- [ ] T027 [P] [US3] Write system test for mixed cart checkout in `test/system/sample_pack_checkout_test.rb`

### Implementation for User Story 3

- [ ] T028 [US3] Verify cart displays mixed items correctly (sample pack "Free" + regular items priced)
- [ ] T029 [US3] Verify checkout creates order with sample pack at £0.00 line item
- [ ] T030 [US3] Run US3 tests to verify implementation (`rails test test/system/sample_pack_checkout_test.rb`)

**Checkpoint**: User Story 3 complete - sample pack works alongside regular products through checkout

---

## Phase 6: User Story 4 - Exclude Sample Pack from Shop (Priority: P4)

**Goal**: Sample pack hidden from shop listings, only discoverable via /samples or direct URL

**Independent Test**: Visit `/shop`, verify sample pack not visible; visit `/samples`, verify it IS visible

### Tests for User Story 4

- [ ] T031 [P] [US4] Write system test verifying sample pack excluded from shop in `test/system/sample_pack_visibility_test.rb`
- [ ] T032 [P] [US4] Write system test verifying sample pack excluded from category pages in `test/system/sample_pack_visibility_test.rb`

### Implementation for User Story 4

- [ ] T033 [US4] Update `ProductsController#index` to use `shoppable` scope in `app/controllers/products_controller.rb`
- [ ] T034 [US4] Update category page queries to use `shoppable` scope (if not already using)
- [ ] T035 [US4] Run US4 tests to verify implementation (`rails test test/system/sample_pack_visibility_test.rb`)

**Checkpoint**: User Story 4 complete - sample pack hidden from shop, visible only on /samples and direct URL

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final verification and cleanup

- [ ] T036 Run full test suite (`rails test`)
- [ ] T037 Run RuboCop linter (`rubocop`)
- [ ] T038 Run Brakeman security scanner (`brakeman`)
- [ ] T039 Create sample pack product via admin (manual setup step)
- [ ] T040 Run quickstart.md verification checklist manually
- [ ] T041 [P] Update CLAUDE.md if any new patterns established

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - US1 and US4 can run in parallel (no dependencies on each other)
  - US2 depends on US1 (needs sample pack in cart to test limit)
  - US3 depends on US1 and US2 (needs working cart with sample pack)
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

```
Foundational (Phase 2)
        │
        ├──► User Story 1 (P1) ──► User Story 2 (P2) ──► User Story 3 (P3)
        │
        └──► User Story 4 (P4) [can run in parallel with US1]
```

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Models/methods before controllers
- Controllers before views
- Story complete before moving to next priority

### Parallel Opportunities

- All tests within a phase marked [P] can run in parallel
- US1 and US4 can be worked on in parallel after Foundational
- Foundation tests T004, T005, T006 can run in parallel

---

## Parallel Example: Foundational Phase

```bash
# Launch all foundation tests together:
Task: "Write failing test for Product::SAMPLE_PACK_SLUG constant"
Task: "Write failing test for Product#sample_pack? method"
Task: "Write failing test for Product.shoppable scope"
```

## Parallel Example: User Story 1 Tests

```bash
# Launch all US1 tests together:
Task: "Write failing test for PagesController#samples loading sample pack"
Task: "Write failing system test for samples landing page"
Task: "Write failing system test for product page quantity hidden"
```

---

## Implementation Strategy

### MVP First (User Story 1 + Foundation Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo if ready - visitors can add sample pack!

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test → Deploy (MVP - can add sample pack!)
3. Add User Story 2 → Test → Deploy (quantity limits enforced)
4. Add User Story 3 → Test → Deploy (mixed carts work)
5. Add User Story 4 → Test → Deploy (shop listings clean)

### Full Feature Delivery

Complete all phases in order, running tests at each checkpoint.

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Constitution mandates TDD - all tests must fail before implementation
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Sample pack product must be created via admin after code deployment (T039)
