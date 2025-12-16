# Tasks: Scheduled Reorder with Review

**Input**: Design documents from `/specs/014-scheduled-reorder/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/api-endpoints.md

**Tests**: Included per constitution (TDD is NON-NEGOTIABLE)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Database schema and project structure

- [x] T001 Create migration for reorder_schedules table in db/migrate/YYYYMMDDHHMMSS_create_reorder_schedules.rb
- [x] T002 Create migration for reorder_schedule_items table in db/migrate/YYYYMMDDHHMMSS_create_reorder_schedule_items.rb
- [x] T003 Create migration for pending_orders table in db/migrate/YYYYMMDDHHMMSS_create_pending_orders.rb
- [x] T004 Create migration to add stripe_customer_id to users in db/migrate/YYYYMMDDHHMMSS_add_stripe_customer_id_to_users.rb
- [x] T005 Create migration to add reorder_schedule_id to orders in db/migrate/YYYYMMDDHHMMSS_add_reorder_schedule_id_to_orders.rb
- [x] T006 Run migrations and verify schema in db/schema.rb
- [x] T007 Add routes for reorder_schedules and pending_orders in config/routes.rb
- [x] T008 [P] Add recurring job configuration in config/recurring.yml for CreatePendingOrdersJob and ExpirePendingOrdersJob

---

## Phase 2: Foundational (Core Models & Services)

**Purpose**: Core models that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundational

- [x] T009 [P] Write failing tests for ReorderSchedule model in test/models/reorder_schedule_test.rb
- [x] T010 [P] Write failing tests for ReorderScheduleItem model in test/models/reorder_schedule_item_test.rb
- [x] T011 [P] Write failing tests for PendingOrder model in test/models/pending_order_test.rb

### Implementation for Foundational

- [x] T012 [P] Implement ReorderSchedule model in app/models/reorder_schedule.rb (enums, validations, scopes, state methods)
- [x] T013 [P] Implement ReorderScheduleItem model in app/models/reorder_schedule_item.rb (validations, availability check)
- [x] T014 [P] Implement PendingOrder model in app/models/pending_order.rb (enums, validations, token generation, snapshot accessors)
- [x] T015 [P] Add has_many :reorder_schedules association to User model in app/models/user.rb
- [x] T016 [P] Add belongs_to :reorder_schedule association to Order model in app/models/order.rb
- [x] T017 Add stripe_customer method to User model in app/models/user.rb (get or create Stripe Customer)
- [x] T018 Run model tests and verify all pass

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Set Up Reorder Schedule (Priority: P1) 🎯 MVP

**Goal**: Customers can set up reorder schedules from past orders with saved payment method

**Independent Test**: Log in, view order, click "Schedule this order", select frequency, save payment method via Stripe, verify schedule created with correct items

### Tests for User Story 1

- [ ] T019 [P] [US1] Write failing tests for ReorderScheduleSetupService in test/services/reorder_schedule_setup_service_test.rb
- [ ] T020 [P] [US1] Write failing tests for ReorderSchedulesController in test/controllers/reorder_schedules_controller_test.rb
- [ ] T021 [P] [US1] Write failing system test for schedule setup flow in test/system/reorder_schedule_setup_test.rb

### Implementation for User Story 1

- [ ] T022 [US1] Implement ReorderScheduleSetupService in app/services/reorder_schedule_setup_service.rb (create Stripe session, create schedule from order)
- [ ] T023 [US1] Implement ReorderSchedulesController#setup action in app/controllers/reorder_schedules_controller.rb (start setup flow)
- [ ] T024 [US1] Implement ReorderSchedulesController#create action in app/controllers/reorder_schedules_controller.rb (redirect to Stripe)
- [ ] T025 [US1] Implement ReorderSchedulesController#setup_success action in app/controllers/reorder_schedules_controller.rb (complete setup after Stripe)
- [ ] T026 [US1] Implement ReorderSchedulesController#setup_cancel action in app/controllers/reorder_schedules_controller.rb
- [ ] T027 [US1] Implement ReorderSchedulesController#index action in app/controllers/reorder_schedules_controller.rb
- [ ] T028 [US1] Implement ReorderSchedulesController#show action in app/controllers/reorder_schedules_controller.rb
- [ ] T029 [P] [US1] Create schedule setup view (frequency selection) in app/views/reorder_schedules/new.html.erb
- [ ] T030 [P] [US1] Create schedule index view (list all schedules) in app/views/reorder_schedules/index.html.erb
- [ ] T031 [P] [US1] Create schedule show view (schedule details) in app/views/reorder_schedules/show.html.erb
- [ ] T032 [US1] Add "Set up reorder schedule" button to order confirmation in app/views/orders/confirmation.html.erb
- [ ] T033 [US1] Add "Schedule this order" button to order show page in app/views/orders/show.html.erb
- [ ] T034 [US1] Add "My Reorder Schedules" link to account navigation in app/views/layouts/_account_nav.html.erb
- [ ] T035 [US1] Run US1 tests and verify all pass

**Checkpoint**: User Story 1 complete - customers can set up reorder schedules

---

## Phase 4: User Story 2 - One-Click Confirmation (Priority: P2)

**Goal**: Customers receive reminder email and can confirm with one click

**Independent Test**: With active schedule, trigger pending order creation, verify email sent, click confirm button, verify order created and charged

### Tests for User Story 2

- [ ] T036 [P] [US2] Write failing tests for CreatePendingOrdersJob in test/jobs/create_pending_orders_job_test.rb
- [ ] T037 [P] [US2] Write failing tests for PendingOrderConfirmationService in test/services/pending_order_confirmation_service_test.rb
- [ ] T038 [P] [US2] Write failing tests for PendingOrdersController#confirm in test/controllers/pending_orders_controller_test.rb
- [ ] T039 [P] [US2] Write failing tests for ReorderMailer in test/mailers/reorder_mailer_test.rb
- [ ] T040 [P] [US2] Write failing system test for one-click confirmation in test/system/pending_order_confirmation_test.rb

### Implementation for User Story 2

- [ ] T041 [US2] Implement CreatePendingOrdersJob in app/jobs/create_pending_orders_job.rb (find due schedules, create pending orders)
- [ ] T042 [US2] Implement pending order snapshot builder (build items_snapshot with current prices, handle unavailable items)
- [ ] T043 [US2] Implement ReorderMailer#order_ready in app/mailers/reorder_mailer.rb
- [ ] T044 [US2] Create order_ready email template in app/views/reorder_mailer/order_ready.html.erb (summary, confirm/edit buttons)
- [ ] T045 [US2] Implement PendingOrderConfirmationService in app/services/pending_order_confirmation_service.rb (charge payment, create order)
- [ ] T046 [US2] Implement PendingOrdersController#confirm action in app/controllers/pending_orders_controller.rb (one-click confirmation)
- [ ] T047 [US2] Add token-based authentication to PendingOrdersController (verify signed SGID tokens)
- [ ] T048 [US2] Run US2 tests and verify all pass

**Checkpoint**: User Story 2 complete - one-click confirmation works

---

## Phase 5: User Story 3 - Edit Order Before Confirmation (Priority: P3)

**Goal**: Customers can edit pending order items before confirming

**Independent Test**: Receive reminder email, click "Edit Order", change quantities, add/remove items, confirm edited order

### Tests for User Story 3

- [ ] T049 [P] [US3] Write failing tests for PendingOrdersController#edit in test/controllers/pending_orders_controller_test.rb
- [ ] T050 [P] [US3] Write failing tests for PendingOrdersController#update in test/controllers/pending_orders_controller_test.rb
- [ ] T051 [P] [US3] Write failing system test for edit-then-confirm flow in test/system/pending_order_edit_test.rb

### Implementation for User Story 3

- [ ] T052 [US3] Implement PendingOrdersController#edit action in app/controllers/pending_orders_controller.rb
- [ ] T053 [US3] Implement PendingOrdersController#update action in app/controllers/pending_orders_controller.rb (update snapshot)
- [ ] T054 [US3] Create pending order edit view in app/views/pending_orders/edit.html.erb (editable items, totals)
- [ ] T055 [US3] Add Stimulus controller for dynamic quantity updates in app/frontend/javascript/controllers/pending_order_edit_controller.js
- [ ] T056 [US3] Register pending_order_edit controller in app/frontend/entrypoints/application.js
- [ ] T057 [US3] Run US3 tests and verify all pass

**Checkpoint**: User Story 3 complete - edit-then-confirm works

---

## Phase 6: User Story 4 - Manage Schedule (Priority: P4)

**Goal**: Customers can pause, resume, change frequency, edit items, and cancel schedules

**Independent Test**: View schedule, pause it, resume it, change frequency, edit items, cancel it

### Tests for User Story 4

- [ ] T058 [P] [US4] Write failing tests for pause/resume/cancel actions in test/controllers/reorder_schedules_controller_test.rb
- [ ] T059 [P] [US4] Write failing tests for schedule update (frequency, items) in test/controllers/reorder_schedules_controller_test.rb
- [ ] T060 [P] [US4] Write failing system test for schedule management in test/system/reorder_schedule_management_test.rb

### Implementation for User Story 4

- [ ] T061 [US4] Implement ReorderSchedulesController#pause action in app/controllers/reorder_schedules_controller.rb
- [ ] T062 [US4] Implement ReorderSchedulesController#resume action in app/controllers/reorder_schedules_controller.rb
- [ ] T063 [US4] Implement ReorderSchedulesController#destroy action in app/controllers/reorder_schedules_controller.rb (cancel)
- [ ] T064 [US4] Implement ReorderSchedulesController#edit action in app/controllers/reorder_schedules_controller.rb
- [ ] T065 [US4] Implement ReorderSchedulesController#update action in app/controllers/reorder_schedules_controller.rb (frequency, items)
- [ ] T066 [US4] Create schedule edit view in app/views/reorder_schedules/edit.html.erb (frequency selector, nested items form)
- [ ] T067 [US4] Add nested_attributes for reorder_schedule_items in ReorderSchedule model
- [ ] T068 [US4] Add Turbo Stream responses for pause/resume/cancel actions
- [ ] T069 [US4] Run US4 tests and verify all pass

**Checkpoint**: User Story 4 complete - full schedule management works

---

## Phase 7: User Story 5 - Skip Next Delivery (Priority: P5)

**Goal**: Customers can skip next delivery without cancelling

**Independent Test**: View active schedule, click "Skip Next", verify pending order cancelled, next date advanced

### Tests for User Story 5

- [ ] T070 [P] [US5] Write failing tests for skip_next action in test/controllers/reorder_schedules_controller_test.rb
- [ ] T071 [P] [US5] Write failing system test for skip delivery in test/system/reorder_schedule_skip_test.rb

### Implementation for User Story 5

- [ ] T072 [US5] Implement ReorderSchedulesController#skip_next action in app/controllers/reorder_schedules_controller.rb
- [ ] T073 [US5] Add "Skip Next" button to schedule show view in app/views/reorder_schedules/show.html.erb
- [ ] T074 [US5] Run US5 tests and verify all pass

**Checkpoint**: User Story 5 complete - skip delivery works

---

## Phase 8: Edge Cases & Expiration

**Purpose**: Handle expiration, payment failures, product unavailability

### Tests for Edge Cases

- [ ] T075 [P] Write failing tests for ExpirePendingOrdersJob in test/jobs/expire_pending_orders_job_test.rb
- [ ] T076 [P] Write failing tests for payment failure handling in test/services/pending_order_confirmation_service_test.rb

### Implementation for Edge Cases

- [ ] T077 Implement ExpirePendingOrdersJob in app/jobs/expire_pending_orders_job.rb
- [ ] T078 Implement ReorderMailer#order_expired in app/mailers/reorder_mailer.rb
- [ ] T079 Create order_expired email template in app/views/reorder_mailer/order_expired.html.erb
- [ ] T080 Implement ReorderMailer#payment_failed in app/mailers/reorder_mailer.rb
- [ ] T081 Create payment_failed email template in app/views/reorder_mailer/payment_failed.html.erb
- [ ] T082 Add payment retry flow to PendingOrdersController
- [ ] T083 Run edge case tests and verify all pass

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup, validation, and documentation

- [ ] T084 Run RuboCop and fix any linting issues
- [ ] T085 Run Brakeman security scanner and address any warnings
- [ ] T086 Run full test suite (rails test && rails test:system)
- [ ] T087 Update CLAUDE.md if any new patterns established
- [ ] T088 Validate quickstart.md instructions work end-to-end
- [ ] T089 Manual testing: complete full user journey (setup → reminder → confirm → manage)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Phase 2 - MVP milestone
- **User Story 2 (Phase 4)**: Depends on Phase 2, integrates with US1 models
- **User Story 3 (Phase 5)**: Depends on Phase 4 (builds on pending orders)
- **User Story 4 (Phase 6)**: Depends on Phase 2, can parallel with US2/US3
- **User Story 5 (Phase 7)**: Depends on Phase 6 (uses schedule management)
- **Edge Cases (Phase 8)**: Depends on Phase 4
- **Polish (Phase 9)**: Depends on all previous phases

### User Story Dependencies

| Story | Depends On | Can Parallel With |
|-------|-----------|-------------------|
| US1 (P1) | Foundational | - |
| US2 (P2) | Foundational | US1 (different controllers) |
| US3 (P3) | US2 | US4 (different features) |
| US4 (P4) | Foundational | US2, US3 (different features) |
| US5 (P5) | US4 | - |

### Within Each User Story

1. Tests MUST be written and FAIL before implementation
2. Models/services before controllers
3. Controllers before views
4. Core implementation before integration
5. Run story tests before marking complete

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Launch all model tests in parallel:
rails test test/models/reorder_schedule_test.rb &
rails test test/models/reorder_schedule_item_test.rb &
rails test test/models/pending_order_test.rb &

# After tests fail, launch all model implementations in parallel:
# T012: ReorderSchedule model
# T013: ReorderScheduleItem model
# T014: PendingOrder model
```

## Parallel Example: User Story 1

```bash
# Launch all US1 tests in parallel:
rails test test/services/reorder_schedule_setup_service_test.rb &
rails test test/controllers/reorder_schedules_controller_test.rb &
rails test:system test/system/reorder_schedule_setup_test.rb &

# After tests fail, launch view tasks in parallel:
# T029: new.html.erb
# T030: index.html.erb
# T031: show.html.erb
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (migrations, routes)
2. Complete Phase 2: Foundational (models)
3. Complete Phase 3: User Story 1 (schedule setup)
4. **STOP and VALIDATE**: Test schedule creation end-to-end
5. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 → Deploy (customers can set up schedules)
3. Add US2 → Deploy (reminder emails and one-click confirm)
4. Add US3 → Deploy (edit before confirm)
5. Add US4 → Deploy (full management)
6. Add US5 → Deploy (skip delivery)
7. Edge cases + Polish → Production ready

---

## Summary

| Phase | Task Count | Description |
|-------|------------|-------------|
| Phase 1: Setup | 8 | Migrations, routes, config |
| Phase 2: Foundational | 10 | Core models |
| Phase 3: US1 | 17 | Schedule setup (MVP) |
| Phase 4: US2 | 13 | One-click confirmation |
| Phase 5: US3 | 9 | Edit before confirm |
| Phase 6: US4 | 12 | Schedule management |
| Phase 7: US5 | 5 | Skip delivery |
| Phase 8: Edge Cases | 9 | Expiration, failures |
| Phase 9: Polish | 6 | Cleanup, validation |
| **Total** | **89** | |

### Parallel Opportunities

- Phase 2: 6 tasks can run in parallel (T009-T016)
- US1: 3 tests + 3 views can run in parallel
- US2: 5 tests can run in parallel
- US3: 3 tests can run in parallel
- US4: 3 tests can run in parallel
- US5: 2 tests can run in parallel

### MVP Scope

**User Story 1 only** (35 tasks through Phase 3):
- Customers can set up reorder schedules from orders
- Schedules are stored with saved payment method
- Schedules appear in "My Reorder Schedules"

This delivers core value while deferring the recurring order flow to US2+.
