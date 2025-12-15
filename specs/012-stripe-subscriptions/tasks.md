# Tasks: Stripe Subscription Checkout

**Input**: Design documents from `/specs/012-stripe-subscriptions/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/api-endpoints.md, quickstart.md

**Tests**: Included (constitution check specifies Test-First Development)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Rails monolith structure per plan.md:
- Controllers: `app/controllers/`
- Services: `app/services/`
- Views: `app/views/`
- JavaScript: `app/frontend/javascript/controllers/`
- Tests: `test/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Database migration and routes configuration

- [ ] T001 Create migration for stripe_invoice_id column in db/migrate/YYYYMMDDHHMMSS_add_stripe_invoice_id_to_orders.rb
- [ ] T002 Run migration and verify schema in db/schema.rb
- [ ] T003 Add stripe_invoice_id uniqueness validation to app/models/order.rb
- [ ] T004 Add subscription_checkouts routes to config/routes.rb

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core service infrastructure that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

- [ ] T005 [P] Create test fixtures for subscriptions in test/fixtures/subscriptions.yml
- [ ] T006 [P] Create SubscriptionCheckoutService test file at test/services/subscription_checkout_service_test.rb
- [ ] T007 Implement SubscriptionCheckoutService in app/services/subscription_checkout_service.rb
- [ ] T008 Add ensure_stripe_customer method to SubscriptionCheckoutService (lazy customer creation)
- [ ] T009 Add build_line_items method with price_data and recurring params
- [ ] T010 Add build_items_snapshot method for JSONB storage
- [ ] T011 Add build_shipping_snapshot method for JSONB storage
- [ ] T012 Add complete_checkout method with subscription and order creation

**Checkpoint**: Foundation ready - SubscriptionCheckoutService functional with tests

---

## Phase 3: User Story 1 - Set Up Recurring Order from Cart (Priority: P1)

**Goal**: Logged-in users can toggle subscription mode in cart, select frequency, complete checkout, and receive first order

**Independent Test**: Log in, add items to cart, toggle "Make this recurring", select frequency, complete checkout, verify subscription created and first order placed

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T013 [P] [US1] Create controller test file at test/controllers/subscription_checkouts_controller_test.rb
- [ ] T014 [P] [US1] Write test: create requires authentication
- [ ] T015 [P] [US1] Write test: create requires non-empty cart
- [ ] T016 [P] [US1] Write test: create rejects samples-only cart
- [ ] T017 [P] [US1] Write test: create redirects to Stripe on success
- [ ] T018 [P] [US1] Write test: success creates subscription and order
- [ ] T019 [P] [US1] Write test: success clears cart
- [ ] T020 [P] [US1] Write test: cancel redirects to cart with flash

### Implementation for User Story 1

- [ ] T021 [US1] Create SubscriptionCheckoutsController in app/controllers/subscription_checkouts_controller.rb
- [ ] T022 [US1] Add require_authentication before_action filter
- [ ] T023 [US1] Add require_cart_with_items before_action filter
- [ ] T024 [US1] Add reject_samples_only_cart before_action filter
- [ ] T025 [US1] Implement create action (validates frequency, calls service, redirects to Stripe)
- [ ] T026 [US1] Implement success action (retrieves session, completes checkout, redirects to order)
- [ ] T027 [US1] Implement cancel action (redirects to cart with flash message)
- [ ] T028 [P] [US1] Create subscription toggle partial at app/views/cart_items/_subscription_toggle.html.erb
- [ ] T029 [P] [US1] Create Stimulus controller at app/frontend/javascript/controllers/subscription_toggle_controller.js
- [ ] T030 [US1] Register subscription_toggle_controller in app/frontend/entrypoints/application.js
- [ ] T031 [US1] Add frequency selector to toggle partial (weekly, every 2 weeks, monthly, every 3 months)
- [ ] T032 [US1] Add "Subscribe & Checkout" button to toggle partial
- [ ] T033 [US1] Update app/views/cart_items/_index.html.erb to render subscription toggle for logged-in users
- [ ] T034 [US1] Add toggle enable/disable behavior via Stimulus (shows/hides frequency selector)
- [ ] T035 [US1] Create system test at test/system/subscription_checkout_test.rb
- [ ] T036 [US1] Run all US1 tests and verify passing

**Checkpoint**: User Story 1 complete - users can set up recurring orders from cart

---

## Phase 4: User Story 2 - Automatic Order Creation on Renewal (Priority: P2)

**Goal**: When subscription renews via Stripe, system automatically creates order and sends email notification

**Independent Test**: Set up subscription, simulate invoice.paid webhook, verify order created and email sent

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T037 [P] [US2] Add webhook tests to test/controllers/webhooks/stripe_controller_test.rb
- [ ] T038 [P] [US2] Write test: invoice.paid creates renewal order
- [ ] T039 [P] [US2] Write test: invoice.paid is idempotent (no duplicate orders)
- [ ] T040 [P] [US2] Write test: invoice.paid skips first invoice (subscription_create)
- [ ] T041 [P] [US2] Write test: invoice.paid sends email notification
- [ ] T042 [P] [US2] Create mailer test at test/mailers/subscription_mailer_test.rb

### Implementation for User Story 2

- [ ] T043 [US2] Add invoice.paid handler to app/controllers/webhooks/stripe_controller.rb
- [ ] T044 [US2] Implement handle_invoice_paid method with billing_reason check
- [ ] T045 [US2] Add idempotency check using stripe_invoice_id
- [ ] T046 [US2] Implement create_renewal_order method from items_snapshot
- [ ] T047 [US2] Create SubscriptionMailer at app/mailers/subscription_mailer.rb
- [ ] T048 [US2] Implement order_placed mailer method
- [ ] T049 [US2] Create email template at app/views/subscription_mailer/order_placed.html.erb
- [ ] T050 [US2] Create text email template at app/views/subscription_mailer/order_placed.text.erb
- [ ] T051 [US2] Add email delivery to handle_invoice_paid (deliver_later)
- [ ] T052 [US2] Run all US2 tests and verify passing

**Checkpoint**: User Story 2 complete - renewal orders created automatically with email notification

---

## Phase 5: User Story 3 - Subscription Status Sync from External Changes (Priority: P3)

**Goal**: When subscription status changes in Stripe (cancelled, paused), local status syncs automatically

**Independent Test**: Cancel subscription in Stripe Dashboard, verify local status updates to cancelled

### Tests for User Story 3

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T053 [P] [US3] Write test: customer.subscription.updated syncs status
- [ ] T054 [P] [US3] Write test: customer.subscription.updated syncs billing period dates
- [ ] T055 [P] [US3] Write test: customer.subscription.deleted marks as cancelled
- [ ] T056 [P] [US3] Write test: invoice.payment_failed logs warning
- [ ] T057 [P] [US3] Write test: status mapping from Stripe to local enum (paused detection)

### Implementation for User Story 3

- [ ] T058 [US3] Add customer.subscription.updated handler to app/controllers/webhooks/stripe_controller.rb
- [ ] T059 [US3] Implement handle_subscription_updated method
- [ ] T060 [US3] Implement map_stripe_status helper (handles pause_collection for paused state)
- [ ] T061 [US3] Add customer.subscription.deleted handler
- [ ] T062 [US3] Implement handle_subscription_deleted method (sets status and cancelled_at)
- [ ] T063 [US3] Add invoice.payment_failed handler with logging
- [ ] T064 [US3] Run all US3 tests and verify passing

**Checkpoint**: User Story 3 complete - subscription status syncs from external changes

---

## Phase 6: User Story 4 - Guest User Subscription Prompt (Priority: P4)

**Goal**: Guest users see disabled subscription toggle with sign-in prompt, encouraging account creation

**Independent Test**: Visit cart as guest, verify disabled toggle shows "Sign in to set up recurring orders"

### Tests for User Story 4

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T065 [P] [US4] Write system test: guest sees disabled toggle with sign-in message
- [ ] T066 [P] [US4] Write system test: sign-in link includes return URL to cart

### Implementation for User Story 4

- [ ] T067 [US4] Update app/views/cart_items/_subscription_toggle.html.erb for guest users
- [ ] T068 [US4] Add conditional rendering: logged-in vs guest state
- [ ] T069 [US4] Add disabled toggle visual state with "Sign in to set up recurring orders" message
- [ ] T070 [US4] Add sign-in link with return_to=cart parameter
- [ ] T071 [US4] Run all US4 tests and verify passing

**Checkpoint**: User Story 4 complete - guest users see subscription prompt

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final integration testing, edge cases, and cleanup

- [ ] T072 [P] Add samples-only cart handling: disable toggle with explanatory message
- [ ] T073 [P] Add error handling for Stripe API failures in controller
- [ ] T074 [P] Add logging for subscription checkout operations
- [ ] T075 Run full test suite: rails test
- [ ] T076 Run RuboCop for code style compliance
- [ ] T077 Manual testing: complete subscription checkout flow per quickstart.md
- [ ] T078 Manual testing: test webhook with Stripe CLI per quickstart.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - US1 (P1): Core checkout flow - should complete first
  - US2 (P2): Renewal webhooks - can start after US1 or in parallel
  - US3 (P3): Status sync webhooks - can start after US1 or in parallel
  - US4 (P4): Guest prompt - can start after US1 or in parallel
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Independent of US1
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - Independent of US1/US2
- **User Story 4 (P4)**: Can start after US1 (extends toggle partial created in US1)

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Service/model before controller
- Controller before views
- Views before Stimulus controllers
- Story complete before moving to next priority

### Parallel Opportunities

**Setup Phase**:
- T001-T004 must run sequentially (migration before routes)

**Foundational Phase**:
- T005 (fixtures) and T006 (test file) can run in parallel
- T007-T012 must run sequentially (building service incrementally)

**User Story Phases**:
- All tests within a story (T013-T020, T037-T042, etc.) can run in parallel
- Different user stories can be worked on in parallel by different developers after US1 toggle is created

---

## Parallel Example: User Story 1 Tests

```bash
# Launch all tests for User Story 1 together:
Task: "Create controller test file at test/controllers/subscription_checkouts_controller_test.rb"
Task: "Write test: create requires authentication"
Task: "Write test: create requires non-empty cart"
Task: "Write test: create rejects samples-only cart"
Task: "Write test: create redirects to Stripe on success"
Task: "Write test: success creates subscription and order"
Task: "Write test: success clears cart"
Task: "Write test: cancel redirects to cart with flash"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational -> Foundation ready
2. Add User Story 1 -> Test independently -> Deploy/Demo (MVP!)
3. Add User Story 2 -> Test independently -> Renewals working
4. Add User Story 3 -> Test independently -> Full status sync
5. Add User Story 4 -> Test independently -> Guest experience
6. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (required first - creates toggle partial)
   - Developer B: Can start US2 webhook handlers once US1 foundational service is done
   - Developer C: Can start US3 webhook handlers once US1 foundational service is done
3. Developer D: User Story 4 after toggle partial exists from US1

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
- Use Stripe CLI for webhook testing: `stripe listen --forward-to localhost:3000/webhooks/stripe`
- Test cards: 4242 4242 4242 4242 (success), 4000 0000 0000 9995 (decline)
