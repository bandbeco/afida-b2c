# Tasks: Structured Events Infrastructure

**Input**: Design documents from `/specs/018-structured-events/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Included (Constitution requires Test-First Development)

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Install dependencies and create core event infrastructure

- [ ] T001 Add logtail-rails gem to Gemfile (`gem "logtail-rails", "~> 0.2"`)
- [ ] T002 Run bundle install to install logtail-rails dependency
- [ ] T003 [P] Create Logtail initializer in config/initializers/logtail.rb
- [ ] T004 [P] Create subscribers directory at app/subscribers/
- [ ] T005 Create EventLogSubscriber in app/subscribers/event_log_subscriber.rb
- [ ] T006 Create events initializer to register subscriber in config/initializers/events.rb
- [ ] T007 Create EventContext concern in app/controllers/concerns/event_context.rb
- [ ] T008 Include EventContext in app/controllers/application_controller.rb

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core testing infrastructure that MUST be complete before user story implementation

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T009 Create test helper for event assertions in test/test_helper.rb (verify Rails 8.1 helpers available)
- [ ] T010 Create EventLogSubscriber unit test in test/subscribers/event_log_subscriber_test.rb
- [ ] T011 Run EventLogSubscriber tests to verify subscriber formats events correctly
- [ ] T012 Verify Rails.event.set_context works in test environment with manual console test

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Debug Silent Failures (Priority: P1) 🎯 MVP

**Goal**: Enable developers to trace webhook processing and order creation by emitting structured events for the complete webhook → payment → order flow.

**Independent Test**: Trigger a Stripe webhook in tests, verify all related events (webhook.received, webhook.processed, order.placed) are emitted with correct payloads and can be correlated by stripe_event_id.

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T013 [P] [US1] Test webhook.received event emission in test/controllers/webhooks/stripe_controller_test.rb
- [ ] T014 [P] [US1] Test webhook.processed event emission in test/controllers/webhooks/stripe_controller_test.rb
- [ ] T015 [P] [US1] Test webhook.failed event emission in test/controllers/webhooks/stripe_controller_test.rb
- [ ] T016 [P] [US1] Test checkout.started event emission in test/controllers/checkouts_controller_test.rb
- [ ] T017 [P] [US1] Test checkout.completed event emission in test/controllers/checkouts_controller_test.rb
- [ ] T018 [P] [US1] Test order.placed event emission in test/controllers/checkouts_controller_test.rb

### Implementation for User Story 1

- [ ] T019 [US1] Emit webhook.received event at start of Webhooks::StripeController#create in app/controllers/webhooks/stripe_controller.rb
- [ ] T020 [US1] Emit webhook.processed event on successful webhook handling in app/controllers/webhooks/stripe_controller.rb
- [ ] T021 [US1] Emit webhook.failed event on webhook processing error in app/controllers/webhooks/stripe_controller.rb
- [ ] T022 [US1] Emit checkout.started event in CheckoutsController#create in app/controllers/checkouts_controller.rb
- [ ] T023 [US1] Emit checkout.completed event in CheckoutsController#success in app/controllers/checkouts_controller.rb
- [ ] T024 [US1] Emit order.placed event after order creation in CheckoutsController#success and webhook handler in app/controllers/checkouts_controller.rb
- [ ] T025 [US1] Run all User Story 1 tests to verify events are emitted correctly

**Checkpoint**: User Story 1 complete - developers can trace webhook → order flow in Logtail

---

## Phase 4: User Story 2 - Track Email Signup Funnel (Priority: P2)

**Goal**: Track email signup completion and discount claim to measure funnel conversion.

**Independent Test**: Submit email signup form, verify email_signup.completed event; complete checkout with discount, verify email_signup.discount_claimed event.

### Tests for User Story 2

- [ ] T026 [P] [US2] Test email_signup.completed event emission in test/controllers/email_subscriptions_controller_test.rb
- [ ] T027 [P] [US2] Test email_signup.discount_claimed event emission in test/controllers/checkouts_controller_test.rb

### Implementation for User Story 2

- [ ] T028 [US2] Emit email_signup.completed event in EmailSubscriptionsController#create in app/controllers/email_subscriptions_controller.rb
- [ ] T029 [US2] Emit email_signup.discount_claimed event when discount applied in CheckoutsController#success in app/controllers/checkouts_controller.rb
- [ ] T030 [US2] Run all User Story 2 tests to verify events are emitted correctly

**Checkpoint**: User Story 2 complete - email signup funnel is trackable

---

## Phase 5: User Story 3 - Monitor Payment Issues (Priority: P2)

**Goal**: Track payment success and failure events with detailed error information.

**Independent Test**: Simulate successful payment, verify payment.succeeded event; simulate failed payment via webhook, verify payment.failed event with error code.

### Tests for User Story 3

- [ ] T031 [P] [US3] Test payment.succeeded event emission in test/controllers/webhooks/stripe_controller_test.rb
- [ ] T032 [P] [US3] Test payment.failed event emission in test/controllers/webhooks/stripe_controller_test.rb

### Implementation for User Story 3

- [ ] T033 [US3] Emit payment.succeeded event on successful payment in app/controllers/webhooks/stripe_controller.rb
- [ ] T034 [US3] Emit payment.failed event on payment failure in app/controllers/webhooks/stripe_controller.rb
- [ ] T035 [US3] Run all User Story 3 tests to verify events are emitted correctly

**Checkpoint**: User Story 3 complete - payment issues are trackable

---

## Phase 6: User Story 4 - Track Customer Cart Activity (Priority: P3)

**Goal**: Track cart item additions and removals for behavior analysis.

**Independent Test**: Add item to cart, verify cart.item_added event; remove item, verify cart.item_removed event.

### Tests for User Story 4

- [ ] T036 [P] [US4] Test cart.item_added event emission in test/controllers/cart_items_controller_test.rb
- [ ] T037 [P] [US4] Test cart.item_removed event emission in test/controllers/cart_items_controller_test.rb

### Implementation for User Story 4

- [ ] T038 [US4] Emit cart.item_added event in CartItemsController#create in app/controllers/cart_items_controller.rb
- [ ] T039 [US4] Emit cart.item_removed event in CartItemsController#destroy in app/controllers/cart_items_controller.rb
- [ ] T040 [US4] Run all User Story 4 tests to verify events are emitted correctly

**Checkpoint**: User Story 4 complete - cart activity is trackable

---

## Phase 7: User Story 5 - Track Scheduled Reorder Lifecycle (Priority: P3)

**Goal**: Track the full reorder lifecycle from schedule creation through pending order to confirmation or failure.

**Independent Test**: Create reorder schedule, verify reorder.scheduled event; trigger pending order job, verify pending_order.created event; confirm order, verify reorder.confirmed event.

### Tests for User Story 5

- [ ] T041 [P] [US5] Test reorder.scheduled event emission in test/controllers/reorder_schedules_controller_test.rb
- [ ] T042 [P] [US5] Test pending_order.created event emission in test/jobs/create_pending_orders_job_test.rb
- [ ] T043 [P] [US5] Test reorder.confirmed event emission in test/controllers/pending_orders_controller_test.rb
- [ ] T044 [P] [US5] Test reorder.charge_failed event emission in test/services/pending_order_confirmation_service_test.rb

### Implementation for User Story 5

- [ ] T045 [US5] Emit reorder.scheduled event in ReorderSchedulesController#create in app/controllers/reorder_schedules_controller.rb
- [ ] T046 [US5] Emit pending_order.created event in CreatePendingOrdersJob in app/jobs/create_pending_orders_job.rb
- [ ] T047 [US5] Emit reorder.confirmed event in PendingOrdersController#confirm in app/controllers/pending_orders_controller.rb
- [ ] T048 [US5] Emit reorder.charge_failed event in PendingOrderConfirmationService in app/services/pending_order_confirmation_service.rb
- [ ] T049 [US5] Run all User Story 5 tests to verify events are emitted correctly

**Checkpoint**: User Story 5 complete - reorder lifecycle is fully trackable

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Integration testing, documentation, and verification

- [ ] T050 [P] Create integration test for complete customer journey in test/integration/event_emission_test.rb
- [ ] T051 [P] Add samples.requested event emission for sample-only orders in app/controllers/checkouts_controller.rb
- [ ] T052 Run full test suite to verify all events work together
- [ ] T053 Run RuboCop to verify code quality compliance
- [ ] T054 Verify Logtail credentials are configured in development environment
- [ ] T055 Manual test: trigger event in rails console, verify it appears in Logtail dashboard
- [ ] T056 Run quickstart.md validation checklist

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase completion
  - User stories can proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P2 → P3 → P3)
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational - Uses CheckoutsController (also in US1, but different events)
- **User Story 3 (P2)**: Can start after Foundational - Uses StripeController (also in US1, but different events)
- **User Story 4 (P3)**: Can start after Foundational - No overlap with other stories
- **User Story 5 (P3)**: Can start after Foundational - No overlap with other stories

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Implementation tasks in order listed
- Story complete when all tests pass

### Parallel Opportunities

**Phase 1 (Setup)**:
- T003 and T004 can run in parallel

**Phase 2 (Foundational)**:
- T010 can run after T009

**Phase 3-7 (User Stories)**:
- All test tasks within a story can run in parallel
- Different user stories can be worked on in parallel after Foundational completes

**Phase 8 (Polish)**:
- T050 and T051 can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
# T013, T014, T015, T016, T017, T018 can run in parallel

# After tests exist and fail, implement sequentially:
# T019 → T020 → T021 → T022 → T023 → T024 → T025
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T008)
2. Complete Phase 2: Foundational (T009-T012)
3. Complete Phase 3: User Story 1 (T013-T025)
4. **STOP and VALIDATE**: Test webhook tracing in Logtail
5. Deploy if ready - core debugging capability is live

### Incremental Delivery

1. Complete Setup + Foundational → Infrastructure ready
2. Add User Story 1 → Debug silent failures (MVP!)
3. Add User Story 2 → Email funnel tracking
4. Add User Story 3 → Payment monitoring
5. Add User Story 4 → Cart activity
6. Add User Story 5 → Reorder lifecycle
7. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (webhook/checkout events)
   - Developer B: User Story 4 (cart events) - no overlap
3. After first round:
   - Developer A: User Story 2 + 3 (email/payment - same files as US1)
   - Developer B: User Story 5 (reorder events) - no overlap

---

## Summary

| Metric | Value |
|--------|-------|
| **Total Tasks** | 56 |
| **Setup Tasks** | 8 |
| **Foundational Tasks** | 4 |
| **User Story 1 (P1)** | 13 tasks |
| **User Story 2 (P2)** | 5 tasks |
| **User Story 3 (P2)** | 5 tasks |
| **User Story 4 (P3)** | 5 tasks |
| **User Story 5 (P3)** | 9 tasks |
| **Polish Tasks** | 7 |
| **MVP Scope** | Phases 1-3 (25 tasks) |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Constitution requires TDD - all tests written first
