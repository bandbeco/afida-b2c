# Tasks: Order User Association

**Input**: Design documents from `/specs/009-order-user-association/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, quickstart.md

**Tests**: Required per Constitution (Test-First Development is NON-NEGOTIABLE)

**Organization**: Tasks organized by user story. Note: US1 and US2 are already implemented - only US3 requires work.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Rails app**: `app/`, `test/` at repository root
- **Controllers**: `app/controllers/`
- **Tests**: `test/controllers/`, `test/integration/`, `test/system/`
- **Fixtures**: `test/fixtures/`

---

## Phase 1: Setup (Verification)

**Purpose**: Verify existing implementation and prepare test infrastructure

- [x] T001 Verify existing order-user association works by reviewing `app/models/order.rb` and `app/models/user.rb`
- [x] T002 Verify checkout associates orders with users by reviewing `app/controllers/checkouts_controller.rb:150-154`
- [x] T003 Verify order index is scoped to current user in `app/controllers/orders_controller.rb:10`
- [x] T004 Add guest order fixture without user_id in `test/fixtures/orders.yml`

---

## Phase 2: Foundational (Test Fixtures)

**Purpose**: Ensure test fixtures support authorization testing scenarios

**CRITICAL**: These fixtures must exist before authorization tests can run

- [x] T005 Verify fixture `orders(:one)` belongs to `users(:one)` in `test/fixtures/orders.yml`
- [x] T006 Verify fixture `orders(:two)` belongs to `users(:two)` in `test/fixtures/orders.yml`
- [x] T007 Verify guest order fixture exists (order with `user: null`) in `test/fixtures/orders.yml`

**Checkpoint**: Test fixtures ready - authorization tests can now be written

---

## Phase 3: User Story 1 - View Order History (Priority: P1) - ALREADY IMPLEMENTED

**Goal**: Users can see list of their past orders with key information

**Independent Test**: Navigate to /orders as logged-in user and verify order list displays

**Status**: ✅ Already working - order index scoped to `Current.user.orders.recent`

### Verification Tasks Only

- [x] T008 [US1] Verify order history page renders for user with orders by running manual test
- [x] T009 [US1] Verify empty state displays for user with no orders by running manual test

**Checkpoint**: US1 confirmed working - no code changes needed

---

## Phase 4: User Story 2 - Order Associated at Checkout (Priority: P1) - ALREADY IMPLEMENTED

**Goal**: Orders are automatically linked to logged-in users at checkout

**Independent Test**: Complete checkout while logged in, verify order appears in order history

**Status**: ✅ Already working - checkout passes `client_reference_id` to Stripe and creates order with user

### Verification Tasks Only

- [x] T010 [US2] Verify checkout code associates user via `stripe_session.client_reference_id` in `app/controllers/checkouts_controller.rb`
- [x] T011 [US2] Verify guest checkout still works (no user association) by reviewing checkout flow

**Checkpoint**: US2 confirmed working - no code changes needed

---

## Phase 5: User Story 3 - Order Access Authorization (Priority: P1) 🎯 NEEDS IMPLEMENTATION

**Goal**: Users can only view orders that belong to them; unauthorized access is denied

**Independent Test**: Attempt to access another user's order URL and verify redirect with error message

**Status**: ❌ SECURITY VULNERABILITY - `set_order` fetches any order by ID without authorization

### Tests for User Story 3 (REQUIRED - TDD)

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T012 [P] [US3] Write controller test for user viewing own order (allowed) in `test/controllers/orders_controller_test.rb`
- [x] T013 [P] [US3] Write controller test for user viewing another user's order (denied) in `test/controllers/orders_controller_test.rb`
- [x] T014 [P] [US3] Write controller test for user viewing guest order (denied) in `test/controllers/orders_controller_test.rb`
- [x] T015 [US3] Run tests to verify they FAIL (red phase): `rails test test/controllers/orders_controller_test.rb`

### Implementation for User Story 3

- [x] T016 [US3] Update `set_order` method to scope to current user's orders in `app/controllers/orders_controller.rb`
- [x] T017 [US3] Add `rescue ActiveRecord::RecordNotFound` with redirect to orders_path in `app/controllers/orders_controller.rb`

### Verification for User Story 3

- [x] T018 [US3] Run tests to verify they PASS (green phase): `rails test test/controllers/orders_controller_test.rb`
- [x] T019 [US3] Run full test suite to ensure no regressions: `rails test`
- [x] T020 [US3] Run RuboCop linter: `rubocop app/controllers/orders_controller.rb`
- [x] T021 [US3] Run Brakeman security scan: `brakeman`

**Checkpoint**: User Story 3 complete - authorization enforced, tests passing

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final verification and documentation

- [x] T022 Manual verification: Log in as `users(:one)`, access `orders(:one)` - should succeed
- [x] T023 Manual verification: Log in as `users(:one)`, access `orders(:two)` - should redirect with error
- [x] T024 Manual verification: Log in as `users(:one)`, access guest order - should redirect with error
- [x] T025 Update spec.md status from Draft to Complete
- [x] T026 Run quickstart.md verification checklist

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - verification only
- **Foundational (Phase 2)**: Depends on Setup - fixture verification
- **US1 (Phase 3)**: Depends on Foundational - verification only (already implemented)
- **US2 (Phase 4)**: Depends on Foundational - verification only (already implemented)
- **US3 (Phase 5)**: Depends on Foundational - **REQUIRES IMPLEMENTATION**
- **Polish (Phase 6)**: Depends on US3 completion

### User Story Dependencies

- **User Story 1 (P1)**: Already implemented - verification only
- **User Story 2 (P1)**: Already implemented - verification only
- **User Story 3 (P1)**: Depends on fixtures being ready - **PRIMARY WORK**

### Within User Story 3 (TDD Workflow)

1. Write all tests (T012-T014) - can run in parallel [P]
2. Verify tests fail (T015) - MUST happen before implementation
3. Implement fix (T016-T017) - sequential
4. Verify tests pass (T018-T021) - sequential

### Parallel Opportunities

- Tests T012, T013, T014 can all be written in parallel (different test cases, same file)
- Setup verification tasks T001-T004 can run in parallel
- Manual verification tasks T022-T024 can run in parallel

---

## Parallel Example: User Story 3 Tests

```bash
# Launch all authorization tests together (they test different scenarios):
Task: "Write controller test for user viewing own order (allowed)"
Task: "Write controller test for user viewing another user's order (denied)"
Task: "Write controller test for user viewing guest order (denied)"
```

---

## Implementation Strategy

### MVP (User Story 3 Only)

Since US1 and US2 are already implemented, the MVP is:

1. Complete Phase 1-2: Verify existing implementation and fixtures
2. Complete Phase 5: User Story 3 (authorization fix)
3. **STOP and VALIDATE**: All authorization tests passing
4. Complete Phase 6: Manual verification

### TDD Strict Workflow

1. Write failing tests (T012-T014)
2. Confirm tests fail (T015) - **DO NOT SKIP**
3. Implement minimal fix (T016-T017)
4. Confirm tests pass (T018)
5. Run full suite + linters (T019-T021)

### Time Estimate

- Verification (Phases 1-4): ~15 minutes
- Tests (T012-T015): ~30 minutes
- Implementation (T016-T017): ~15 minutes
- Verification (T018-T021): ~10 minutes
- Polish (Phase 6): ~15 minutes
- **Total: ~1.5 hours**

---

## Notes

- [P] tasks = can run in parallel (different test cases)
- [US3] is the only story requiring implementation
- Constitution requires tests written FIRST and FAILING before implementation
- Commit after each logical group (tests, implementation, verification)
- The security fix is minimal - single method change in controller
