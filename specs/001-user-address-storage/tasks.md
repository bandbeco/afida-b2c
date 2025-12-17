# Tasks: User Address Storage

**Input**: Design documents from `/specs/001-user-address-storage/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: Tests are included per TDD workflow (test-first development)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions (Rails)

- Models: `app/models/`
- Controllers: `app/controllers/`
- Views: `app/views/`
- Tests: `test/`
- Migrations: `db/migrate/`
- Stimulus: `app/frontend/javascript/controllers/`

---

## Phase 1: Setup

**Purpose**: Create database migration and add routes

- [x] T001 Generate migration for addresses table: `rails generate migration CreateAddresses` then update `db/migrate/YYYYMMDDHHMMSS_create_addresses.rb`
- [x] T002 Run migration: `rails db:migrate`
- [x] T003 Add address routes to `config/routes.rb` under account namespace

---

## Phase 2: Foundational (Address Model)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Create Address model in `app/models/address.rb` with validations, callbacks, and scopes
- [x] T005 Extend User model in `app/models/user.rb` with `has_many :addresses` association and helper methods
- [x] T006 Create address fixture in `test/fixtures/addresses.yml`
- [x] T007 Create Address model tests in `test/models/address_test.rb`
- [x] T008 Run model tests to verify: `rails test test/models/address_test.rb`

**Checkpoint**: Address model ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Manage Saved Addresses (Priority: P1) 🎯 MVP

**Goal**: Allow logged-in users to add, edit, delete, and set default addresses in account settings

**Independent Test**: Log in, navigate to /account/addresses, add address with all fields, edit it, set as default, delete it. All CRUD operations work independently.

**Acceptance Criteria**:
- Add new address with required fields (nickname, recipient name, line1, city, postcode)
- Edit existing address
- Set address as default (unsets previous default)
- Delete address (reassigns default if needed)

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T009 [P] [US1] Create controller tests in `test/controllers/account/addresses_controller_test.rb` for index, new, create, edit, update, destroy, set_default actions
- [x] T010 [P] [US1] Create system tests in `test/system/address_management_test.rb` for full CRUD workflow

### Implementation for User Story 1

- [x] T011 [US1] Create AddressesController in `app/controllers/account/addresses_controller.rb` with index, new, create, edit, update, destroy, set_default actions
- [x] T012 [P] [US1] Create address list view in `app/views/account/addresses/index.html.erb`
- [x] T013 [P] [US1] Create address card partial in `app/views/account/addresses/_address.html.erb`
- [x] T014 [P] [US1] Create address form partial in `app/views/account/addresses/_form.html.erb`
- [x] T015 [US1] Create new address view in `app/views/account/addresses/new.html.erb`
- [x] T016 [US1] Create edit address view in `app/views/account/addresses/edit.html.erb`
- [x] T017 [US1] Add Turbo Stream responses for create/update/destroy in `app/views/account/addresses/` (create.turbo_stream.erb, destroy.turbo_stream.erb, set_default.turbo_stream.erb)
- [x] T018 [US1] Add "Addresses" link to account navigation menu
- [x] T019 [US1] Run all US1 tests: `rails test test/controllers/account/addresses_controller_test.rb test/system/address_management_test.rb`

**Checkpoint**: User Story 1 complete - users can manage addresses in account settings

---

## Phase 4: User Story 2 - Select Address at Checkout (Priority: P2)

**Goal**: Show address selection modal when logged-in user with saved addresses clicks checkout; prefill Stripe with selected address

**Independent Test**: Have saved addresses, add items to cart, click checkout, see modal with addresses, select one, proceed to Stripe, verify address is prefilled.

**Depends on**: US1 (addresses must exist to select from)

**Acceptance Criteria**:
- Modal appears for logged-in users with saved addresses
- Default address is pre-selected
- "Enter different address" option bypasses prefill
- Guests and users without addresses go directly to Stripe

### Tests for User Story 2

- [x] T020 [P] [US2] Create integration tests in `test/integration/checkout_address_prefill_test.rb` for checkout with/without address, prefill verification

### Implementation for User Story 2

- [x] T021 [US2] Create checkout address modal partial in `app/views/carts/_checkout_address_modal.html.erb`
- [x] T022 [US2] Create checkout-address Stimulus controller in `app/frontend/javascript/controllers/checkout_address_controller.js`
- [x] T023 [US2] Register Stimulus controller in `app/frontend/entrypoints/application.js`
- [x] T024 [US2] Modify cart view to include address modal in `app/views/cart_items/_index.html.erb`
- [x] T025 [US2] Modify CheckoutsController in `app/controllers/checkouts_controller.rb` to accept address_id and prefill Stripe
- [x] T026 [US2] Run all US2 tests: `rails test test/integration/checkout_address_prefill_test.rb`

**Checkpoint**: User Story 2 complete - checkout modal works and Stripe receives prefilled address

---

## Phase 5: User Story 3 - Save Address After Checkout (Priority: P3)

**Goal**: Prompt users to save new addresses after successful checkout

**Independent Test**: Complete checkout with new address (not matching saved), see save prompt on confirmation, enter nickname, verify address is saved.

**Depends on**: US1 (need address model), US2 (checkout flow modification)

**Acceptance Criteria**:
- Save prompt appears only for new addresses (not matching line1+postcode)
- User can enter nickname and save
- User can dismiss prompt without saving
- Guests don't see prompt

### Tests for User Story 3

- [x] T027 [P] [US3] Create controller tests for create_from_order action in `test/controllers/account/addresses_controller_test.rb`
- [x] T028 [P] [US3] Create system tests in `test/system/save_address_after_checkout_test.rb`

### Implementation for User Story 3

- [x] T029 [US3] Add create_from_order action to AddressesController in `app/controllers/account/addresses_controller.rb` (already implemented)
- [x] T030 [US3] Create save address prompt partial in `app/views/orders/_save_address_prompt.html.erb`
- [x] T031 [US3] Add address matching helper to User model in `app/models/user.rb` (already implemented)
- [x] T032 [US3] Modify order confirmation view to include save prompt in `app/views/orders/confirmation.html.erb`
- [x] T033 [US3] Run all US3 tests: `rails test test/controllers/account/addresses_controller_test.rb test/system/save_address_after_checkout_test.rb`

**Checkpoint**: User Story 3 complete - users can save new addresses from checkout

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, cleanup, and documentation

- [x] T034 Run full test suite: `rails test` (51 tests, 133 assertions, 0 failures)
- [x] T035 Run RuboCop: `rubocop app/models/address.rb app/controllers/account/addresses_controller.rb` (no offenses)
- [x] T036 Run Brakeman security scan: `brakeman` (5 pre-existing warnings, none from address feature)
- [ ] T037 Manual verification of quickstart.md scenarios
- [ ] T038 Update CLAUDE.md if needed with address-related documentation

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational - No dependencies on other stories
- **User Story 2 (Phase 4)**: Depends on Foundational - Uses US1 model but can be tested independently
- **User Story 3 (Phase 5)**: Depends on Foundational and US2 checkout flow modification
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

```
Phase 1: Setup
    ↓
Phase 2: Foundational (Address Model)
    ↓
    ├── Phase 3: US1 - Manage Addresses (MVP) ──────────┐
    │                                                    │
    ├── Phase 4: US2 - Select at Checkout ──────────────┤
    │       (can start in parallel with US1 after       │
    │        model exists, but integrates with cart)    │
    │                                                    │
    └── Phase 5: US3 - Save After Checkout ─────────────┤
            (depends on US2 for checkout integration)   │
                                                        ↓
                                               Phase 6: Polish
```

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Views can be parallelized (different files)
- Controller actions must be complete before Turbo Stream responses
- Run story tests after implementation complete

### Parallel Opportunities

**Phase 2 (Foundational)**:
```bash
# These CAN run in parallel:
T004: Create Address model
T005: Extend User model
T006: Create fixture
```

**Phase 3 (US1 Implementation)**:
```bash
# Tests can run in parallel:
T009: Controller tests
T010: System tests

# Views can run in parallel:
T012: index.html.erb
T013: _address.html.erb
T014: _form.html.erb
```

**Phase 4 (US2)**:
```bash
# T021, T022, T023 can run in parallel (different files)
T021: Modal partial
T022: Stimulus controller
T023: Register controller
```

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task T009: Controller tests in test/controllers/account/addresses_controller_test.rb
Task T010: System tests in test/system/address_management_test.rb

# Launch all views for User Story 1 together (after controller T011):
Task T012: index.html.erb
Task T013: _address.html.erb
Task T014: _form.html.erb
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T008)
3. Complete Phase 3: User Story 1 (T009-T019)
4. **STOP and VALIDATE**: Test address management independently
5. Deploy/demo if ready - users can now manage addresses

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy (MVP!)
3. Add User Story 2 → Test independently → Deploy (checkout integration)
4. Add User Story 3 → Test independently → Deploy (full feature)
5. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (account settings CRUD)
   - Developer B: User Story 2 (checkout modal) - can start after T004-T005
3. US3 depends on US2, so Developer A/B tackles after US1+US2 complete

---

## Summary

| Phase | Task Count | Parallel Opportunities |
|-------|------------|------------------------|
| Setup | 3 | 0 |
| Foundational | 5 | 3 |
| US1 - Manage Addresses | 11 | 5 |
| US2 - Select at Checkout | 7 | 4 |
| US3 - Save After Checkout | 7 | 2 |
| Polish | 5 | 3 |
| **Total** | **38** | **17** |

**MVP Scope**: Complete through Phase 3 (US1) - 19 tasks for basic address management

**Independent Test Criteria**:
- US1: Full CRUD in account settings works standalone
- US2: Modal appears and Stripe receives prefilled address
- US3: Save prompt appears and saves address to account

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
