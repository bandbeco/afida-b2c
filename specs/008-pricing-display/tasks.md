# Tasks: Pricing Display Consolidation

**Input**: Design documents from `/specs/008-pricing-display/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, quickstart.md

**Tests**: Included per constitution requirement (Test-First Development is NON-NEGOTIABLE)

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Exact file paths included in all descriptions

## Path Conventions

This is an existing Rails monolith:
- Models: `app/models/`
- Helpers: `app/helpers/`
- Views: `app/views/`
- Services: `app/services/`
- Tests: `test/`
- Migrations: `db/migrate/`

---

## Phase 1: Setup (Database Schema)

**Purpose**: Add database column required for pricing display feature

- [ ] T001 Generate migration for pac_size column: `rails generate migration AddPacSizeToOrderItems pac_size:integer`
- [ ] T002 Run migration: `rails db:migrate`

---

## Phase 2: Foundational (Shared Infrastructure)

**Purpose**: Create core components that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundational Components

> **TDD**: Write these tests FIRST, ensure they FAIL before implementation

- [ ] T003 [P] Write OrderItem model tests for `pack_priced?`, `pack_price`, `unit_price` methods in `test/models/order_item_test.rb`
- [ ] T004 [P] Write CartItem model tests for `pack_priced?`, `pack_price` methods in `test/models/cart_item_test.rb`
- [ ] T005 [P] Write PricingHelper tests for `format_price_display` in `test/helpers/pricing_helper_test.rb`

### Implementation for Foundational Components

- [ ] T006 [P] Add `pack_priced?`, `pack_price`, `unit_price` methods to OrderItem model in `app/models/order_item.rb`
- [ ] T007 [P] Add `pack_priced?`, `pack_price` methods to CartItem model in `app/models/cart_item.rb`
- [ ] T008 Create PricingHelper with `format_price_display` method in `app/helpers/pricing_helper.rb`
- [ ] T009 Update `OrderItem.create_from_cart_item` to store pack price and pac_size in `app/models/order_item.rb`
- [ ] T010 Verify all foundational tests pass: `rails test test/models/order_item_test.rb test/models/cart_item_test.rb test/helpers/pricing_helper_test.rb`

**Checkpoint**: Foundation ready - all model methods and helper working, tests passing

---

## Phase 3: User Story 1 - Customer Views Order Confirmation (Priority: P1)

**Goal**: Display correct pricing format on order confirmation page for customers

**Independent Test**: Complete checkout with standard products, verify order show page displays "£X.XX / pack (£X.XXXX / unit)" format

### Tests for User Story 1

> **TDD**: Write test FIRST, ensure it FAILS before implementation

- [ ] T011 [US1] Write system test for order confirmation pricing display in `test/system/order_pricing_display_test.rb`

### Implementation for User Story 1

- [ ] T012 [US1] Update order show view to use `format_price_display(item)` in `app/views/orders/show.html.erb` (line 66)
- [ ] T013 [US1] Verify User Story 1 tests pass: `rails test test/system/order_pricing_display_test.rb`

**Checkpoint**: Order confirmation page displays correct pricing for standard and branded products

---

## Phase 4: User Story 2 - Admin Reviews Order Details (Priority: P2)

**Goal**: Display correct pricing format in admin order detail views

**Independent Test**: View order in admin panel, verify pricing matches customer-facing format

### Tests for User Story 2

> **TDD**: Write test FIRST, ensure it FAILS before implementation

- [ ] T014 [US2] Add admin order view test cases to `test/system/order_pricing_display_test.rb`

### Implementation for User Story 2

- [ ] T015 [US2] Update admin order show view to use `format_price_display(item)` in `app/views/admin/orders/show.html.erb` (line 51)
- [ ] T016 [US2] Verify User Story 2 tests pass: `rails test test/system/order_pricing_display_test.rb`

**Checkpoint**: Admin order views display correct pricing format

---

## Phase 5: User Story 3 - PDF Order Summary Generation (Priority: P3)

**Goal**: Display correct pricing format in PDF order summaries

**Independent Test**: Generate PDF summary for order, verify pricing format matches web display

### Tests for User Story 3

> **TDD**: Write test FIRST, ensure it FAILS before implementation

- [ ] T017 [US3] Write service test for PDF pricing display in `test/services/order_pdf_generator_test.rb`

### Implementation for User Story 3

- [ ] T018 [US3] Include PricingHelper in OrderPdfGenerator service in `app/services/order_pdf_generator.rb`
- [ ] T019 [US3] Update `add_items_table` method to use `format_price_display` for Price column in `app/services/order_pdf_generator.rb`
- [ ] T020 [US3] Verify User Story 3 tests pass: `rails test test/services/order_pdf_generator_test.rb`

**Checkpoint**: PDF order summaries display correct pricing format

---

## Phase 6: User Story 4 - Cart Display Consistency (Priority: P2)

**Goal**: Refactor cart to use centralized pricing helper (currently works but has duplicated logic)

**Independent Test**: Add standard and branded products to cart, verify display uses centralized helper

### Tests for User Story 4

> **TDD**: Write test FIRST, ensure it FAILS before implementation

- [ ] T021 [US4] Add cart pricing display test cases to `test/system/order_pricing_display_test.rb`

### Implementation for User Story 4

- [ ] T022 [US4] Refactor cart item partial to use `format_price_display(cart_item)` in `app/views/cart_items/_cart_item.html.erb` (lines 35-50)
- [ ] T023 [US4] Verify User Story 4 tests pass: `rails test test/system/order_pricing_display_test.rb`

**Checkpoint**: Cart uses centralized pricing helper, code duplication eliminated

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup

- [ ] T024 Run full test suite: `rails test`
- [ ] T025 Run RuboCop linter: `rubocop app/helpers/pricing_helper.rb app/models/order_item.rb app/models/cart_item.rb`
- [ ] T026 Run quickstart.md manual testing checklist
- [ ] T027 Verify edge cases: pac_size=1, pac_size=null, branded products

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (migration) - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Phase 2 completion
  - US1 (P1): Can start after Phase 2
  - US2 (P2): Can start after Phase 2 (parallel with US1)
  - US3 (P3): Can start after Phase 2 (parallel with US1, US2)
  - US4 (P2): Can start after Phase 2 (parallel with others)
- **Polish (Phase 7)**: Depends on all user stories complete

### User Story Dependencies

- **User Story 1 (Order Confirmation)**: Independent - requires only foundational components
- **User Story 2 (Admin Orders)**: Independent - requires only foundational components
- **User Story 3 (PDF Summary)**: Independent - requires only foundational components
- **User Story 4 (Cart Refactor)**: Independent - requires only foundational components

### Within Each Phase

- Tests MUST be written and FAIL before implementation (TDD)
- Model methods before views
- Helper methods before views
- Verify tests pass after implementation

### Parallel Opportunities

**Phase 2 (Foundational)**:
```
T003, T004, T005 → Run in parallel (different test files)
T006, T007 → Run in parallel (different model files)
```

**User Stories**:
```
All 4 user stories can be implemented in parallel after Phase 2:
- US1: app/views/orders/show.html.erb
- US2: app/views/admin/orders/show.html.erb
- US3: app/services/order_pdf_generator.rb
- US4: app/views/cart_items/_cart_item.html.erb
```

---

## Parallel Example: Phase 2 Foundational

```bash
# Launch all foundational tests together:
Task: "T003 - Write OrderItem model tests in test/models/order_item_test.rb"
Task: "T004 - Write CartItem model tests in test/models/cart_item_test.rb"
Task: "T005 - Write PricingHelper tests in test/helpers/pricing_helper_test.rb"

# Then launch model implementations together:
Task: "T006 - Add methods to OrderItem in app/models/order_item.rb"
Task: "T007 - Add methods to CartItem in app/models/cart_item.rb"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (migration)
2. Complete Phase 2: Foundational (model methods + helper)
3. Complete Phase 3: User Story 1 (order confirmation)
4. **STOP and VALIDATE**: Order page shows correct pricing
5. Deploy/demo if ready - customers see correct pricing

### Incremental Delivery

1. Setup + Foundational → Core infrastructure ready
2. Add User Story 1 → Customer-facing pricing fixed → Deploy (MVP!)
3. Add User Story 2 → Admin views fixed → Deploy
4. Add User Story 3 → PDF fixed → Deploy
5. Add User Story 4 → Cart refactored, code clean → Deploy

### Parallel Team Strategy

With multiple developers:

1. All team: Phase 1 + Phase 2 together
2. Once foundational is done:
   - Developer A: User Story 1 (order confirmation)
   - Developer B: User Story 2 (admin orders)
   - Developer C: User Story 3 (PDF generator)
   - Developer D: User Story 4 (cart refactor)
3. All stories complete independently, merge together

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- TDD enforced per constitution: tests written before implementation
- Each user story independently testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All file paths are exact - no ambiguity
