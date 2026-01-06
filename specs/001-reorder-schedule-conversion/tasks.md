# Tasks: Reorder Schedule Conversion Page Redesign

**Input**: Design documents from `/specs/001-reorder-schedule-conversion/`
**Prerequisites**: plan.md, spec.md, research.md, quickstart.md

**Tests**: Required per constitution (Test-First Development principle)

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1-US5)
- Include exact file paths in descriptions

## Path Conventions

- **Rails app**: `app/` for source, `test/` for tests
- **Frontend**: `app/frontend/javascript/controllers/` for Stimulus
- **Views**: `app/views/reorder_schedules/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create foundational components needed by multiple user stories

- [ ] T001 Create view helper file `app/helpers/reorder_schedules_helper.rb` with `order_items_summary` method
- [ ] T002 [P] Create Stimulus controller file `app/frontend/javascript/controllers/order_summary_toggle_controller.js`
- [ ] T003 Register order-summary-toggle controller in `app/frontend/entrypoints/application.js`

---

## Phase 2: Foundational (Tests)

**Purpose**: Write failing tests FIRST per TDD principle

**Tests MUST fail before implementation begins**

- [ ] T004 [P] Create helper test file `test/helpers/reorder_schedules_helper_test.rb` with tests for `order_items_summary`
- [ ] T005 [P] Create system test file `test/system/reorder_schedule_setup_test.rb` with test scaffolding
- [ ] T006 [US1] Add system test: flexibility messaging visible without scrolling in `test/system/reorder_schedule_setup_test.rb`
- [ ] T007 [US1] Add system test: flexibility reassurance in hero badges AND below CTA in `test/system/reorder_schedule_setup_test.rb`
- [ ] T008 [P] [US2] Add system test: frequency options display with "Most popular" badge in `test/system/reorder_schedule_setup_test.rb`
- [ ] T009 [P] [US2] Add system test: "Every Month" pre-selected by default in `test/system/reorder_schedule_setup_test.rb`
- [ ] T010 [P] [US3] Add system test: compact order summary shows item count and total in `test/system/reorder_schedule_setup_test.rb`
- [ ] T011 [P] [US3] Add system test: order summary expands/collapses on click in `test/system/reorder_schedule_setup_test.rb`
- [ ] T012 [P] [US4] Add system test: "How it works" section displays 3 steps in `test/system/reorder_schedule_setup_test.rb`
- [ ] T013 [P] [US5] Add system test: CTA reads "Set Up Automatic Delivery" in `test/system/reorder_schedule_setup_test.rb`
- [ ] T014 [P] [US5] Add system test: trust messaging below CTA includes Stripe and cancel mention in `test/system/reorder_schedule_setup_test.rb`
- [ ] T015 Run all tests to verify they FAIL (red phase)

**Checkpoint**: All tests written and failing - implementation can begin

---

## Phase 3: User Story 1 - Flexibility Messaging (Priority: P1) 🎯 MVP

**Goal**: Display flexibility badges prominently so users immediately see they can cancel anytime

**Independent Test**: `rails test test/system/reorder_schedule_setup_test.rb -n /flexibility/`

### Implementation for User Story 1

- [ ] T016 [US1] Add hero section with headline "Never Run Out Again" in `app/views/reorder_schedules/setup.html.erb`
- [ ] T017 [US1] Add subhead with flexibility promise in hero section in `app/views/reorder_schedules/setup.html.erb`
- [ ] T018 [US1] Add flexibility badges (Cancel anytime, Skip/pause, Edit items) with checkmark icons in `app/views/reorder_schedules/setup.html.erb`
- [ ] T019 [US1] Run flexibility tests to verify they PASS

**Checkpoint**: Hero with flexibility messaging complete and tested

---

## Phase 4: User Story 2 - Frequency Selection (Priority: P1)

**Goal**: Display frequency options with "Most popular" badge on Every Month

**Independent Test**: `rails test test/system/reorder_schedule_setup_test.rb -n /frequency/`

### Implementation for User Story 2

- [ ] T020 [US2] Update frequency selector with conversational label "How often do you need a refill?" in `app/views/reorder_schedules/setup.html.erb`
- [ ] T021 [US2] Add "Most popular" DaisyUI badge to "Every Month" option in `app/views/reorder_schedules/setup.html.erb`
- [ ] T022 [US2] Add empty placeholder div for future discount banner in `app/views/reorder_schedules/setup.html.erb`
- [ ] T023 [US2] Run frequency tests to verify they PASS

**Checkpoint**: Frequency selector complete with "Most popular" badge

---

## Phase 5: User Story 3 - Order Summary (Priority: P2)

**Goal**: Collapsible order summary showing item count and total

**Independent Test**: `rails test test/system/reorder_schedule_setup_test.rb -n /summary/`

### Implementation for User Story 3

- [ ] T024 [US3] Implement `order_items_summary` helper method in `app/helpers/reorder_schedules_helper.rb`
- [ ] T025 [US3] Run helper tests to verify `order_items_summary` works correctly
- [ ] T026 [US3] Implement Stimulus controller toggle logic in `app/frontend/javascript/controllers/order_summary_toggle_controller.js`
- [ ] T027 [US3] Add compact order summary view with expand button in `app/views/reorder_schedules/setup.html.erb`
- [ ] T028 [US3] Add expanded order summary (line items) with collapse functionality in `app/views/reorder_schedules/setup.html.erb`
- [ ] T029 [US3] Add `<noscript>` fallback to show expanded view when JS disabled in `app/views/reorder_schedules/setup.html.erb`
- [ ] T030 [US3] Run order summary tests to verify expand/collapse works

**Checkpoint**: Collapsible order summary complete with JS fallback

---

## Phase 6: User Story 4 - How It Works (Priority: P2)

**Goal**: Display 3-step visual explanation above CTA

**Independent Test**: `rails test test/system/reorder_schedule_setup_test.rb -n /how_it_works/`

### Implementation for User Story 4

- [ ] T031 [US4] Add "How it works" section with horizontal 3-step layout in `app/views/reorder_schedules/setup.html.erb`
- [ ] T032 [US4] Add numbered icons and brief copy for each step in `app/views/reorder_schedules/setup.html.erb`
- [ ] T033 [US4] Run "How it works" tests to verify they PASS

**Checkpoint**: 3-step explanation complete and positioned above CTA

---

## Phase 7: User Story 5 - CTA & Trust (Priority: P1)

**Goal**: Strong CTA with trust messaging

**Independent Test**: `rails test test/system/reorder_schedule_setup_test.rb -n /cta/`

### Implementation for User Story 5

- [ ] T034 [US5] Update CTA button text to "Set Up Automatic Delivery" in `app/views/reorder_schedules/setup.html.erb`
- [ ] T035 [US5] Add trust line below CTA with lock icon, Stripe mention, and "Cancel anytime" in `app/views/reorder_schedules/setup.html.erb`
- [ ] T036 [US5] Run CTA and trust messaging tests to verify they PASS

**Checkpoint**: CTA section complete with trust messaging

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup and validation

- [ ] T037 Run full test suite `rails test test/system/reorder_schedule_setup_test.rb`
- [ ] T038 Run helper tests `rails test test/helpers/reorder_schedules_helper_test.rb`
- [ ] T039 Run RuboCop linter `rubocop app/helpers/reorder_schedules_helper.rb app/views/reorder_schedules/setup.html.erb`
- [ ] T040 Manual browser testing: verify page responsive on 320px+ screens
- [ ] T041 Manual browser testing: verify page works with JavaScript disabled
- [ ] T042 Manual browser testing: verify form submission works correctly

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies - can start immediately
- **Phase 2 (Tests)**: Depends on Phase 1 (need helper file to exist)
- **Phase 3-7 (User Stories)**: Depend on Phase 2 (tests must exist and fail first)
- **Phase 8 (Polish)**: Depends on all user story phases

### User Story Dependencies

All user stories modify the same view file (`setup.html.erb`), so they must be implemented **sequentially** to avoid conflicts:

- **US1 (Flexibility)**: First - creates hero structure
- **US2 (Frequency)**: After US1 - adds to page below hero
- **US3 (Summary)**: After US2 - needs Stimulus controller from Phase 1
- **US4 (How it works)**: After US3 - positions above CTA
- **US5 (CTA)**: Last - finalizes bottom of page

### Within Each User Story

1. Implementation tasks in order (top to bottom)
2. Run story-specific tests to verify PASS
3. Commit before moving to next story

### Parallel Opportunities

**Phase 1**: T002 can run in parallel with T001 (different files)
**Phase 2**: T004-T014 tests (marked [P]) can be written in parallel
**Phase 3-7**: NOT parallelizable (same view file)
**Phase 8**: Some manual tests can run in parallel

---

## Parallel Example: Phase 2 (Tests)

```bash
# Launch all test-writing tasks together:
Task: "Create helper test file test/helpers/reorder_schedules_helper_test.rb"
Task: "Create system test file test/system/reorder_schedule_setup_test.rb"

# Then add all system tests in parallel (different test methods):
Task: "Add system test: flexibility messaging visible"
Task: "Add system test: frequency options display"
Task: "Add system test: compact order summary shows item count"
Task: "Add system test: How it works section displays 3 steps"
Task: "Add system test: CTA reads Set Up Automatic Delivery"
```

---

## Implementation Strategy

### MVP First (User Stories 1, 2, 5 Only - All P1)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Tests for P1 stories only (T004-T009, T013-T015)
3. Complete Phase 3: US1 Flexibility (T016-T019)
4. Complete Phase 4: US2 Frequency (T020-T023)
5. Complete Phase 7: US5 CTA (T034-T036)
6. **STOP and VALIDATE**: Core conversion messaging complete
7. Deploy/demo if ready

### Full Implementation

1. Complete MVP above
2. Add Phase 5: US3 Order Summary (T024-T030)
3. Add Phase 6: US4 How it works (T031-T033)
4. Complete Phase 8: Polish (T037-T042)

---

## Notes

- Constitution requires TDD: All tests written and failing BEFORE implementation
- All user stories share single view file - implement sequentially
- Helper and Stimulus controller can be built in parallel (Phase 1)
- Run `rails test` after each user story phase to verify progress
- Commit after each checkpoint for easy rollback
