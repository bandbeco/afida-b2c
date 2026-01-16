# Tasks: Email Signup Discount

**Input**: Design documents from `/specs/001-email-signup-discount/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included per constitution (TDD is NON-NEGOTIABLE)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

This is a Rails 8 monolith with Vite frontend:
- Backend: `app/models/`, `app/controllers/`, `app/views/`
- Frontend: `app/frontend/javascript/controllers/`
- Tests: `test/models/`, `test/controllers/`, `test/system/`
- Fixtures: `test/fixtures/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create Stripe coupon and database infrastructure

- [ ] T001 Create `WELCOME5` coupon in Stripe (5% off, once duration) via Dashboard or Rails console
- [ ] T002 Generate migration for email_subscriptions table in `db/migrate/XXXXXX_create_email_subscriptions.rb`
- [ ] T003 Run migration with `rails db:migrate`
- [ ] T004 [P] Create test fixtures in `test/fixtures/email_subscriptions.yml`
- [ ] T005 [P] Add route `resources :email_subscriptions, only: [:create]` in `config/routes.rb`

**Checkpoint**: Database and routing ready

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core model and eligibility logic that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundational (TDD - write first, must fail)

- [ ] T006 [P] Write model tests for EmailSubscription validations in `test/models/email_subscription_test.rb`
- [ ] T007 [P] Write model tests for `eligible_for_discount?` class method in `test/models/email_subscription_test.rb`

### Implementation for Foundational

- [ ] T008 Create EmailSubscription model with validations and normalization in `app/models/email_subscription.rb`
- [ ] T009 Implement `eligible_for_discount?(email)` class method in `app/models/email_subscription.rb`
- [ ] T010 Verify model tests pass with `rails test test/models/email_subscription_test.rb`

**Checkpoint**: Foundation ready - EmailSubscription model complete with eligibility logic

---

## Phase 3: User Story 1 - Guest Visitor Claims Discount (Priority: P1) 🎯 MVP

**Goal**: Guest visitor can enter email on cart page, see discount applied, and have it apply at checkout

**Independent Test**: Add items to cart as guest → enter email → verify success message → checkout → verify 5% discount in Stripe

### Tests for User Story 1 (TDD - write first, must fail)

- [ ] T011 [P] [US1] Write controller test for successful signup in `test/controllers/email_subscriptions_controller_test.rb`
- [ ] T012 [P] [US1] Write controller test for session discount_code storage in `test/controllers/email_subscriptions_controller_test.rb`
- [ ] T013 [P] [US1] Write system test for guest discount flow in `test/system/email_signup_discount_test.rb`

### Implementation for User Story 1

- [ ] T014 [US1] Create EmailSubscriptionsController with `create` action in `app/controllers/email_subscriptions_controller.rb`
- [ ] T015 [P] [US1] Create signup form partial in `app/views/email_subscriptions/_cart_signup_form.html.erb`
- [ ] T016 [P] [US1] Create success state partial in `app/views/email_subscriptions/_success.html.erb`
- [ ] T017 [US1] Create Turbo Stream response in `app/views/email_subscriptions/create.turbo_stream.erb`
- [ ] T018 [US1] Add `show_discount_signup?` helper method to CartsHelper in `app/helpers/carts_helper.rb`
- [ ] T019 [US1] Render signup form partial in cart page `app/views/carts/show.html.erb`
- [ ] T020 [US1] Modify CheckoutsController to apply coupon from session in `app/controllers/checkouts_controller.rb`
- [ ] T021 [US1] Clear discount from session after successful order in `app/controllers/checkouts_controller.rb`
- [ ] T022 [P] [US1] Create Stimulus controller for form UX in `app/frontend/javascript/controllers/discount_signup_controller.js`
- [ ] T023 [US1] Register Stimulus controller in `app/frontend/entrypoints/application.js`
- [ ] T024 [US1] Verify all US1 tests pass with `rails test test/controllers/email_subscriptions_controller_test.rb test/system/email_signup_discount_test.rb`

**Checkpoint**: Guest visitors can claim discount and have it applied at checkout

---

## Phase 4: User Story 2 - Logged-in New Customer Claims Discount (Priority: P1)

**Goal**: Logged-in user with no orders sees the same signup form and can claim discount

**Independent Test**: Log in with user who has no orders → view cart → enter email → verify discount applies

### Tests for User Story 2 (TDD - write first, must fail)

- [ ] T025 [P] [US2] Write controller test for logged-in user eligibility in `test/controllers/email_subscriptions_controller_test.rb`
- [ ] T026 [P] [US2] Write system test for logged-in new customer flow in `test/system/email_signup_discount_test.rb`

### Implementation for User Story 2

- [ ] T027 [US2] Update `show_discount_signup?` to check `!Current.user.orders.exists?` in `app/helpers/carts_helper.rb`
- [ ] T028 [US2] Verify all US2 tests pass

**Checkpoint**: Logged-in new customers can claim discount

---

## Phase 5: User Story 3 - Returning Customer Excluded (Priority: P2)

**Goal**: Logged-in user with order history does NOT see the signup form

**Independent Test**: Log in with user who has orders → view cart → verify form is NOT displayed

### Tests for User Story 3 (TDD - write first, must fail)

- [ ] T029 [P] [US3] Write system test verifying form hidden for returning customers in `test/system/email_signup_discount_test.rb`

### Implementation for User Story 3

- [ ] T030 [US3] Verify `show_discount_signup?` returns false for users with orders (already implemented in US2)
- [ ] T031 [US3] Verify US3 tests pass

**Checkpoint**: Returning customers don't see discount form

---

## Phase 6: User Story 4 - Previously Subscribed Email Rejected (Priority: P2)

**Goal**: Visitors who enter an already-used email see appropriate error messages

**Independent Test**: Enter email that's already subscribed → verify "already claimed" message

### Tests for User Story 4 (TDD - write first, must fail)

- [ ] T032 [P] [US4] Write controller test for "already claimed" response in `test/controllers/email_subscriptions_controller_test.rb`
- [ ] T033 [P] [US4] Write controller test for "not eligible" (has orders) response in `test/controllers/email_subscriptions_controller_test.rb`
- [ ] T034 [P] [US4] Write system test for rejection messages in `test/system/email_signup_discount_test.rb`

### Implementation for User Story 4

- [ ] T035 [P] [US4] Create "already claimed" partial in `app/views/email_subscriptions/_already_claimed.html.erb`
- [ ] T036 [P] [US4] Create "not eligible" partial in `app/views/email_subscriptions/_not_eligible.html.erb`
- [ ] T037 [US4] Update controller to render appropriate error partials in `app/controllers/email_subscriptions_controller.rb`
- [ ] T038 [US4] Verify all US4 tests pass

**Checkpoint**: Ineligible visitors see appropriate rejection messages

---

## Phase 7: User Story 5 - Email List Captured for Marketing (Priority: P3)

**Goal**: Emails are stored with timestamp and source for future marketing

**Independent Test**: Sign up for discount → query database → verify email stored with `discount_claimed_at` and `source`

### Tests for User Story 5 (TDD - write first, must fail)

- [ ] T039 [P] [US5] Write model test verifying `discount_claimed_at` is set on creation in `test/models/email_subscription_test.rb`
- [ ] T040 [P] [US5] Write model test verifying `source` defaults to "cart_discount" in `test/models/email_subscription_test.rb`

### Implementation for User Story 5

- [ ] T041 [US5] Verify controller sets `discount_claimed_at: Time.current` on creation (already implemented)
- [ ] T042 [US5] Verify US5 tests pass

**Checkpoint**: Email subscriptions stored with marketing-relevant metadata

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and code quality

- [ ] T043 [P] Run RuboCop linter and fix any issues
- [ ] T044 [P] Run full test suite with `rails test`
- [ ] T045 [P] Manual test: Complete end-to-end flow in development
- [ ] T046 Verify Stripe coupon exists in production (create if not)
- [ ] T047 Run quickstart.md validation checklist

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies - can start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 - BLOCKS all user stories
- **Phases 3-7 (User Stories)**: All depend on Phase 2 completion
  - US1 and US2 are both P1 priority - implement in order (US1 first for MVP)
  - US3, US4, US5 can proceed after US1/US2
- **Phase 8 (Polish)**: Depends on all user stories complete

### User Story Dependencies

| Story | Depends On | Can Run Parallel With |
|-------|------------|----------------------|
| US1 (Guest Discount) | Phase 2 only | None (MVP, do first) |
| US2 (Logged-in New Customer) | Phase 2 only | US1 (after US1 for shared helper) |
| US3 (Returning Excluded) | US2 (uses same helper) | US4, US5 |
| US4 (Email Rejected) | US1 (uses controller) | US3, US5 |
| US5 (Marketing Capture) | Phase 2 only | US3, US4 |

### Within Each User Story

1. Tests MUST be written and FAIL before implementation
2. Fixtures before model tests
3. Model before controller
4. Controller before views
5. Views before integration

### Parallel Opportunities

**Phase 1 (Setup)**:
```bash
# T004 and T005 can run in parallel
```

**Phase 2 (Foundational)**:
```bash
# T006 and T007 can run in parallel (different test files conceptually)
```

**Phase 3 (User Story 1)**:
```bash
# Tests T011, T012, T013 can run in parallel
# Partials T015, T016 can run in parallel
# T022 (Stimulus) can run in parallel with backend work
```

**Phase 6 (User Story 4)**:
```bash
# Tests T032, T033, T034 can run in parallel
# Partials T035, T036 can run in parallel
```

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together (must fail first):
Task: "Write controller test for successful signup in test/controllers/email_subscriptions_controller_test.rb"
Task: "Write controller test for session discount_code storage in test/controllers/email_subscriptions_controller_test.rb"
Task: "Write system test for guest discount flow in test/system/email_signup_discount_test.rb"

# After tests fail, launch partials in parallel:
Task: "Create signup form partial in app/views/email_subscriptions/_cart_signup_form.html.erb"
Task: "Create success state partial in app/views/email_subscriptions/_success.html.erb"

# Stimulus can be developed in parallel with backend:
Task: "Create Stimulus controller for form UX in app/frontend/javascript/controllers/discount_signup_controller.js"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T005)
2. Complete Phase 2: Foundational (T006-T010)
3. Complete Phase 3: User Story 1 (T011-T024)
4. **STOP and VALIDATE**: Test guest discount flow end-to-end
5. Deploy if ready - guests can now get 5% off

### Incremental Delivery

1. Setup + Foundational → Database and model ready
2. Add US1 → Guest visitors can claim discount (MVP!)
3. Add US2 → Logged-in new customers can claim discount
4. Add US3 → Returning customers excluded
5. Add US4 → Error messages for ineligible emails
6. Add US5 → Marketing metadata captured
7. Polish → Code quality and final validation

---

## Task Summary

| Phase | Task Count | Stories Covered |
|-------|------------|-----------------|
| Phase 1: Setup | 5 | - |
| Phase 2: Foundational | 5 | - |
| Phase 3: US1 (Guest) | 14 | P1 MVP |
| Phase 4: US2 (Logged-in New) | 4 | P1 |
| Phase 5: US3 (Returning Excluded) | 3 | P2 |
| Phase 6: US4 (Email Rejected) | 7 | P2 |
| Phase 7: US5 (Marketing) | 4 | P3 |
| Phase 8: Polish | 5 | - |
| **Total** | **47** | **5 stories** |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Constitution requires TDD: tests written first, must fail before implementation
- Constitution requires fixtures: use `email_subscriptions(:claimed_discount)` syntax
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
