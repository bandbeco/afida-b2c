# Tasks: Sign-Up & Account Experience

**Input**: Design documents from `/specs/001-sign-up-accounts/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: TDD approach required per constitution. Tests written FIRST, must FAIL before implementation.

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Rails monolith structure per plan.md:
- Controllers: `app/controllers/`
- Models: `app/models/`
- Services: `app/services/`
- Views: `app/views/`
- Tests: `test/`
- Frontend: `app/frontend/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Database migrations and route configuration needed by all user stories

- [X] T001 Create subscriptions table migration in db/migrate/YYYYMMDDHHMMSS_create_subscriptions.rb
- [X] T002 Create add_subscription_to_orders migration in db/migrate/YYYYMMDDHHMMSS_add_subscription_to_orders.rb
- [X] T003 Run migrations: `rails db:migrate`
- [X] T004 Add new routes to config/routes.rb (account, subscriptions, subscription_checkouts, reorder, post_checkout_registration, webhooks)
- [X] T005 [P] Register new Stimulus controllers in app/frontend/entrypoints/application.js (account_dropdown, subscription_toggle)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core model and shared components that MUST be complete before user story work

**CRITICAL**: No user story work can begin until this phase is complete

- [X] T006 Create Subscription model in app/models/subscription.rb with validations and enums (frequency, status)
- [X] T007 Add `has_many :subscriptions` association to app/models/user.rb
- [X] T008 Add `belongs_to :subscription, optional: true` to app/models/order.rb
- [X] T009 [P] Create test fixtures for subscriptions in test/fixtures/subscriptions.yml
- [X] T010 Write Subscription model tests in test/models/subscription_test.rb (validations, enums, associations)
- [X] T011 Run and verify Subscription model tests pass: `rails test test/models/subscription_test.rb`

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Reorder Previous Order (Priority: P1) MVP

**Goal**: Let logged-in users copy a past order to their cart with one click

**Independent Test**: Place an order, log in, view order history, click "Reorder", verify items in cart

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T012 [P] [US1] Write ReorderService unit tests in test/services/reorder_service_test.rb
- [ ] T013 [P] [US1] Write orders#reorder controller tests in test/controllers/orders_controller_test.rb
- [ ] T014 [P] [US1] Write reorder system test in test/system/reorder_test.rb
- [ ] T015 [US1] Run tests and verify they FAIL: `rails test test/services/reorder_service_test.rb test/controllers/orders_controller_test.rb test/system/reorder_test.rb`

### Implementation for User Story 1

- [ ] T016 [US1] Create ReorderService in app/services/reorder_service.rb (availability checks, cart merging, result object)
- [ ] T017 [US1] Add `reorder` action to app/controllers/orders_controller.rb
- [ ] T018 [US1] Update order history view app/views/orders/index.html.erb with Reorder buttons
- [ ] T019 [US1] Update individual order view app/views/orders/show.html.erb with Reorder button
- [ ] T020 [US1] Run tests and verify they PASS: `rails test test/services/reorder_service_test.rb test/controllers/orders_controller_test.rb test/system/reorder_test.rb`

**Checkpoint**: Reorder functionality complete and independently testable

---

## Phase 4: User Story 2 - Guest-to-Account Conversion (Priority: P2)

**Goal**: Convert guests to accounts on order confirmation page with minimal friction

**Independent Test**: Complete guest checkout, see conversion prompt, enter password, verify order linked to new account

### Tests for User Story 2

- [ ] T021 [P] [US2] Write PostCheckoutRegistrationsController tests in test/controllers/post_checkout_registrations_controller_test.rb
- [ ] T022 [P] [US2] Write account conversion system test in test/system/account_conversion_test.rb
- [ ] T023 [US2] Run tests and verify they FAIL: `rails test test/controllers/post_checkout_registrations_controller_test.rb test/system/account_conversion_test.rb`

### Implementation for User Story 2

- [ ] T024 [US2] Create PostCheckoutRegistrationsController in app/controllers/post_checkout_registrations_controller.rb
- [ ] T025 [US2] Create account conversion partial in app/views/orders/_account_conversion_form.html.erb
- [ ] T026 [US2] Update app/views/orders/confirmation.html.erb to include conversion form for guests
- [ ] T027 [US2] Handle edge case: email already registered (show login link)
- [ ] T028 [US2] Run tests and verify they PASS: `rails test test/controllers/post_checkout_registrations_controller_test.rb test/system/account_conversion_test.rb`

**Checkpoint**: Guest-to-account conversion complete and independently testable

---

## Phase 5: User Story 3 - Sign-Up Page with Value Messaging (Priority: P3)

**Goal**: Communicate account benefits on sign-up page to drive conversions

**Independent Test**: Visit sign-up page, see value proposition, complete registration

### Tests for User Story 3

- [ ] T029 [P] [US3] Write sign-up page system test in test/system/sign_up_page_test.rb
- [ ] T030 [US3] Run tests and verify they FAIL: `rails test test/system/sign_up_page_test.rb`

### Implementation for User Story 3

- [ ] T031 [US3] Update app/views/registrations/new.html.erb with tagline "Reorder in seconds. Your order history, saved and ready."
- [ ] T032 [US3] Add benefits list below form (order history, one-click reorder, recurring orders coming soon)
- [ ] T033 [US3] Run tests and verify they PASS: `rails test test/system/sign_up_page_test.rb`

**Checkpoint**: Sign-up page messaging complete and independently testable

---

## Phase 6: User Story 4 - Account Navigation & Settings (Priority: P4)

**Goal**: Provide clear navigation for logged-in users to access account features

**Independent Test**: Log in, click account dropdown, navigate to each section, change settings

### Tests for User Story 4

- [ ] T034 [P] [US4] Write AccountsController tests in test/controllers/accounts_controller_test.rb
- [ ] T035 [P] [US4] Write account navigation system test in test/system/account_navigation_test.rb
- [ ] T036 [US4] Run tests and verify they FAIL: `rails test test/controllers/accounts_controller_test.rb test/system/account_navigation_test.rb`

### Implementation for User Story 4

- [ ] T037 [US4] Create AccountsController in app/controllers/accounts_controller.rb (show, update actions)
- [ ] T038 [US4] Create account settings view in app/views/accounts/show.html.erb
- [ ] T039 [US4] Create account dropdown Stimulus controller in app/frontend/javascript/controllers/account_dropdown_controller.js
- [ ] T040 [US4] Update header partial (app/views/layouts/_header.html.erb or similar) with account dropdown for logged-in users
- [ ] T041 [US4] Run tests and verify they PASS: `rails test test/controllers/accounts_controller_test.rb test/system/account_navigation_test.rb`

**Checkpoint**: Account navigation and settings complete and independently testable

---

## Phase 7: User Story 5 - Set Up Recurring Order (Priority: P5)

**Goal**: Let logged-in users create fixed-schedule subscriptions from cart

**Independent Test**: Add items to cart, enable subscription, checkout, verify subscription created

### Tests for User Story 5

- [ ] T042 [P] [US5] Write SubscriptionService unit tests in test/services/subscription_service_test.rb
- [ ] T043 [P] [US5] Write SubscriptionsController tests in test/controllers/subscriptions_controller_test.rb
- [ ] T044 [P] [US5] Write SubscriptionCheckoutsController tests in test/controllers/subscription_checkouts_controller_test.rb
- [ ] T045 [P] [US5] Write subscription system test in test/system/subscription_test.rb
- [ ] T046 [US5] Run tests and verify they FAIL: `rails test test/services/subscription_service_test.rb test/controllers/subscriptions_controller_test.rb test/controllers/subscription_checkouts_controller_test.rb test/system/subscription_test.rb`

### Implementation for User Story 5

- [ ] T047 [US5] Create SubscriptionService in app/services/subscription_service.rb (create, cancel, Stripe integration)
- [ ] T048 [US5] Create SubscriptionsController in app/controllers/subscriptions_controller.rb (index, destroy)
- [ ] T049 [US5] Create SubscriptionCheckoutsController in app/controllers/subscription_checkouts_controller.rb (create, success, cancel)
- [ ] T050 [US5] Create subscriptions index view in app/views/subscriptions/index.html.erb
- [ ] T051 [US5] Create subscription toggle Stimulus controller in app/frontend/javascript/controllers/subscription_toggle_controller.js
- [ ] T052 [US5] Update cart view (app/views/carts/show.html.erb or drawer) with subscription checkbox and frequency selector
- [ ] T053 [US5] Create/update Stripe webhook handler in app/controllers/webhooks/stripe_controller.rb for subscription events
- [ ] T054 [US5] Create SubscriptionMailer in app/mailers/subscription_mailer.rb for order notifications
- [ ] T055 [US5] Run tests and verify they PASS: `rails test test/services/subscription_service_test.rb test/controllers/subscriptions_controller_test.rb test/controllers/subscription_checkouts_controller_test.rb test/system/subscription_test.rb`

**Checkpoint**: Subscription functionality complete and independently testable

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Quality assurance, security, and final validation

- [ ] T056 Run full test suite: `rails test`
- [ ] T057 Run RuboCop linter: `rubocop`
- [ ] T058 Run Brakeman security scanner: `brakeman`
- [ ] T059 [P] Verify SEO meta tags on sign-up page
- [ ] T060 [P] Verify rate limiting on post_checkout_registration endpoint
- [ ] T061 [P] Test Stripe webhook signature verification
- [ ] T062 Run quickstart.md validation (test each flow manually)
- [ ] T063 Code cleanup and remove any commented code

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase completion
  - User stories can proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3 → P4 → P5)
- **Polish (Phase 8)**: Depends on desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Reorder - No dependencies on other stories
- **User Story 2 (P2)**: Guest Conversion - No dependencies (uses existing Order model)
- **User Story 3 (P3)**: Sign-Up Messaging - No dependencies (view-only changes)
- **User Story 4 (P4)**: Account Navigation - No dependencies (standalone feature)
- **User Story 5 (P5)**: Subscriptions - Depends on Phase 2 Subscription model, but no user story dependencies

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Services before controllers
- Controllers before views
- Core implementation before integration
- All story tests pass before moving to next story

### Parallel Opportunities

**Phase 1 (Setup)**:
- T001, T002 can run in parallel (separate migrations)
- T005 can run in parallel with migrations

**Phase 2 (Foundational)**:
- T009, T010 can run in parallel (fixtures and tests)

**Phase 3-7 (User Stories)**:
- Test tasks within each story can run in parallel
- Different user stories can be worked on in parallel by different developers

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "Write ReorderService unit tests in test/services/reorder_service_test.rb"
Task: "Write orders#reorder controller tests in test/controllers/orders_controller_test.rb"
Task: "Write reorder system test in test/system/reorder_test.rb"
```

---

## Parallel Example: User Story 5

```bash
# Launch all tests for User Story 5 together:
Task: "Write SubscriptionService unit tests in test/services/subscription_service_test.rb"
Task: "Write SubscriptionsController tests in test/controllers/subscriptions_controller_test.rb"
Task: "Write SubscriptionCheckoutsController tests in test/controllers/subscription_checkouts_controller_test.rb"
Task: "Write subscription system test in test/system/subscription_test.rb"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (migrations, routes)
2. Complete Phase 2: Foundational (Subscription model - needed for complete schema)
3. Complete Phase 3: User Story 1 (Reorder)
4. **STOP and VALIDATE**: Test reorder independently
5. Deploy/demo if ready - delivers core value proposition

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add User Story 1 (Reorder) → Test → Deploy (MVP!)
3. Add User Story 2 (Guest Conversion) → Test → Deploy
4. Add User Story 3 (Sign-Up Messaging) → Test → Deploy
5. Add User Story 4 (Account Navigation) → Test → Deploy
6. Add User Story 5 (Subscriptions) → Test → Deploy
7. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (Reorder) - Most valuable
   - Developer B: User Story 3 (Sign-Up Messaging) - Simple, view-only
   - Developer C: User Story 4 (Account Navigation) - Standalone
3. Then:
   - Developer A: User Story 2 (Guest Conversion)
   - Developer B: User Story 5 (Subscriptions) - Most complex
4. Stories complete and integrate independently

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Tests must fail before implementing (TDD per constitution)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- RuboCop and Brakeman must pass before PR (per constitution)
