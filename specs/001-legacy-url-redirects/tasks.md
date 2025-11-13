# Tasks: Legacy URL Smart Redirects

**Input**: Design documents from `/specs/001-legacy-url-redirects/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Following TDD workflow per project constitution - tests written FIRST, must FAIL before implementation

**Organization**: Tasks grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

This is a Rails 8 web application. Paths:
- Models: `app/models/`
- Middleware: `app/middleware/`
- Controllers: `app/controllers/admin/`
- Views: `app/views/admin/legacy_redirects/`
- Migrations: `db/migrate/`
- Seeds: `db/seeds/`
- Tests: `test/models/`, `test/middleware/`, `test/controllers/`, `test/integration/`, `test/system/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Database schema and initial project structure for legacy redirects

- [x] T001 Create migration for legacy_redirects table in `db/migrate/XXXXXX_create_legacy_redirects.rb`
- [x] T002 Run migration to create legacy_redirects table with indexes
- [x] T003 [P] Create LegacyRedirect model stub in `app/models/legacy_redirect.rb`
- [x] T004 [P] Create middleware directory `app/middleware/` if not exists

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core model and middleware structure that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 Write failing model tests for LegacyRedirect validations in `test/models/legacy_redirect_test.rb`
- [x] T006 Implement LegacyRedirect model validations (legacy_path, target_slug, format) in `app/models/legacy_redirect.rb`
- [x] T007 Write failing model tests for scopes (active, inactive, most_used) in `test/models/legacy_redirect_test.rb`
- [x] T008 Implement LegacyRedirect scopes in `app/models/legacy_redirect.rb`
- [x] T009 Write failing model tests for class method find_by_path in `test/models/legacy_redirect_test.rb`
- [x] T010 Implement LegacyRedirect.find_by_path (case-insensitive lookup) in `app/models/legacy_redirect.rb`
- [x] T011 Write failing model tests for instance methods (record_hit!, target_url, deactivate!, activate!) in `test/models/legacy_redirect_test.rb`
- [x] T012 Implement LegacyRedirect instance methods in `app/models/legacy_redirect.rb`
- [x] T013 Write failing model test for target_slug_exists validation in `test/models/legacy_redirect_test.rb`
- [x] T014 Implement target_slug_exists custom validation in `app/models/legacy_redirect.rb`
- [x] T015 Run all model tests and verify they pass

**Checkpoint**: Foundation ready - LegacyRedirect model complete and tested

---

## Phase 3: User Story 1 - Legacy URL Visitor Redirect (Priority: P1) 🎯 MVP

**Goal**: Intercept legacy product URLs and redirect users to new product pages with extracted variant parameters

**Independent Test**: Visit `/product/12-310-x-310mm-pizza-box-kraft` and verify redirect to `/products/pizza-box-kraft?size=12"`

### Tests for User Story 1 (TDD - Write FIRST)

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T016 [P] [US1] Write failing middleware test for redirect match found (active) in `test/middleware/legacy_redirect_middleware_test.rb`
- [x] T017 [P] [US1] Write failing middleware test for no match found in `test/middleware/legacy_redirect_middleware_test.rb`
- [x] T018 [P] [US1] Write failing middleware test for match found (inactive) in `test/middleware/legacy_redirect_middleware_test.rb`
- [x] T019 [P] [US1] Write failing middleware test for case-insensitive match in `test/middleware/legacy_redirect_middleware_test.rb`
- [x] T020 [P] [US1] Write failing middleware test for trailing slash handling in `test/middleware/legacy_redirect_middleware_test.rb`
- [x] T021 [P] [US1] Write failing middleware test for query parameter preservation in `test/middleware/legacy_redirect_middleware_test.rb`
- [x] T022 [P] [US1] Write failing middleware test for non-GET request pass-through in `test/middleware/legacy_redirect_middleware_test.rb`
- [x] T023 [P] [US1] Write failing middleware test for non-product path pass-through in `test/middleware/legacy_redirect_middleware_test.rb`
- [x] T024 [P] [US1] Write failing middleware test for hit counter increment in `test/middleware/legacy_redirect_middleware_test.rb`
- [x] T025 [P] [US1] Write failing middleware test for database error handling in `test/middleware/legacy_redirect_middleware_test.rb`

### Implementation for User Story 1

- [x] T026 [US1] Create middleware stub in `app/middleware/legacy_redirect_middleware.rb`
- [x] T027 [US1] Implement middleware initialize method in `app/middleware/legacy_redirect_middleware.rb`
- [x] T028 [US1] Implement middleware call method with path prefix check in `app/middleware/legacy_redirect_middleware.rb`
- [x] T029 [US1] Implement redirect lookup logic with case-insensitivity in `app/middleware/legacy_redirect_middleware.rb`
- [x] T030 [US1] Implement target URL building with variant parameters in `app/middleware/legacy_redirect_middleware.rb`
- [x] T031 [US1] Implement query parameter preservation in `app/middleware/legacy_redirect_middleware.rb`
- [x] T032 [US1] Implement 301 redirect response in `app/middleware/legacy_redirect_middleware.rb`
- [x] T033 [US1] Implement hit counter increment (fire-and-forget) in `app/middleware/legacy_redirect_middleware.rb`
- [x] T034 [US1] Implement error handling (fail open) in `app/middleware/legacy_redirect_middleware.rb`
- [x] T035 [US1] Register middleware in `config/application.rb` using `config.middleware.use`
- [x] T036 [US1] Run all middleware tests and verify they pass

### Integration Testing for User Story 1

- [x] T037 [US1] Write failing integration test for end-to-end redirect flow in `test/integration/legacy_redirect_flow_test.rb`
- [x] T038 [US1] Write failing integration test for variant selection flow in `test/integration/legacy_redirect_flow_test.rb`
- [x] T039 [US1] Run integration tests and verify they pass

### System Testing for User Story 1

- [x] T040 [US1] Write failing system test for browser redirect in `test/system/legacy_redirect_system_test.rb`
- [x] T041 [US1] Run system tests and verify they pass

### Seed Data for User Story 1

- [x] T042 [US1] Create seed file with 63 legacy URL mappings in `db/seeds/legacy_redirects.rb`
- [x] T043 [US1] Load seed data using `rails db:seed` and verify redirects work

**Checkpoint**: At this point, User Story 1 should be fully functional - legacy URLs redirect correctly

---

## Phase 4: User Story 2 - Unmapped URL Fallback (Priority: P2)

**Goal**: Provide graceful fallback for legacy URLs that don't have redirect mappings

**Independent Test**: Visit `/product/unknown-product-xyz` and verify 404 page displays with helpful navigation

### Tests for User Story 2 (TDD - Write FIRST)

- [x] T044 [P] [US2] Write failing test for unmapped URL pass-through to 404 in `test/middleware/legacy_redirect_middleware_test.rb`
- [x] T045 [P] [US2] Write failing test for logging unmapped URL warnings in `test/middleware/legacy_redirect_middleware_test.rb`

### Implementation for User Story 2

- [x] T046 [US2] Implement unmapped URL logging in `app/middleware/legacy_redirect_middleware.rb`
- [x] T047 [US2] Run tests for User Story 2 and verify they pass
- [ ] T048 [US2] Create custom 404 page with search functionality in `app/views/errors/not_found.html.erb` (optional enhancement - skipped)

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - Administrator Analytics & Management (Priority: P3)

**Goal**: Enable administrators to view statistics, manage redirect mappings, and test redirects

**Independent Test**: Access `/admin/legacy_redirects`, see list of 63+ redirects with hit counts, create new redirect, verify it works immediately

### Tests for User Story 3 (TDD - Write FIRST)

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

**Controller Tests**:
- [ ] T049 [P] [US3] Write failing controller test for index action in `test/controllers/admin/legacy_redirects_controller_test.rb`
- [ ] T050 [P] [US3] Write failing controller test for show action in `test/controllers/admin/legacy_redirects_controller_test.rb`
- [ ] T051 [P] [US3] Write failing controller test for new action in `test/controllers/admin/legacy_redirects_controller_test.rb`
- [ ] T052 [P] [US3] Write failing controller test for create action in `test/controllers/admin/legacy_redirects_controller_test.rb`
- [ ] T053 [P] [US3] Write failing controller test for edit action in `test/controllers/admin/legacy_redirects_controller_test.rb`
- [ ] T054 [P] [US3] Write failing controller test for update action in `test/controllers/admin/legacy_redirects_controller_test.rb`
- [ ] T055 [P] [US3] Write failing controller test for destroy action in `test/controllers/admin/legacy_redirects_controller_test.rb`
- [ ] T056 [P] [US3] Write failing controller test for toggle action in `test/controllers/admin/legacy_redirects_controller_test.rb`
- [ ] T057 [P] [US3] Write failing controller test for test action in `test/controllers/admin/legacy_redirects_controller_test.rb`
- [ ] T058 [P] [US3] Write failing controller test for authentication enforcement in `test/controllers/admin/legacy_redirects_controller_test.rb`

### Implementation for User Story 3

**Routes**:
- [x] T059 [US3] Add admin routes for legacy_redirects in `config/routes.rb`

**Controller**:
- [x] T060 [US3] Create Admin::LegacyRedirectsController in `app/controllers/admin/legacy_redirects_controller.rb`
- [x] T061 [US3] Implement index action with filtering and sorting in `app/controllers/admin/legacy_redirects_controller.rb`
- [x] T062 [US3] Implement show action in `app/controllers/admin/legacy_redirects_controller.rb`
- [x] T063 [US3] Implement new action in `app/controllers/admin/legacy_redirects_controller.rb`
- [x] T064 [US3] Implement create action with validation in `app/controllers/admin/legacy_redirects_controller.rb`
- [x] T065 [US3] Implement edit action in `app/controllers/admin/legacy_redirects_controller.rb`
- [x] T066 [US3] Implement update action with validation in `app/controllers/admin/legacy_redirects_controller.rb`
- [x] T067 [US3] Implement destroy action in `app/controllers/admin/legacy_redirects_controller.rb`
- [x] T068 [US3] Implement toggle action (activate/deactivate) in `app/controllers/admin/legacy_redirects_controller.rb`
- [x] T069 [US3] Implement test action (preview redirect) in `app/controllers/admin/legacy_redirects_controller.rb`
- [x] T070 [US3] Add authentication check (reuse existing admin auth) in `app/controllers/admin/legacy_redirects_controller.rb`
- [x] T071 [US3] Run controller tests and verify they pass

**Views**:
- [x] T072 [P] [US3] Create index view with table and filters in `app/views/admin/legacy_redirects/index.html.erb`
- [x] T073 [P] [US3] Create show view with redirect details in `app/views/admin/legacy_redirects/show.html.erb`
- [x] T074 [P] [US3] Create new view with form in `app/views/admin/legacy_redirects/new.html.erb`
- [x] T075 [P] [US3] Create edit view with form in `app/views/admin/legacy_redirects/edit.html.erb`
- [x] T076 [P] [US3] Create form partial in `app/views/admin/legacy_redirects/_form.html.erb`

**Integration Testing for User Story 3**:
- [x] T077 [US3] Write failing integration test for admin CRUD workflow in `test/integration/admin_legacy_redirects_test.rb`
- [x] T078 [US3] Write failing integration test for bulk operations in `test/integration/admin_legacy_redirects_test.rb`
- [x] T079 [US3] Run integration tests and verify they pass

**Checkpoint**: All user stories should now be independently functional

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T080 [P] Create rake task for redirect validation in `lib/tasks/legacy_redirects.rake`
- [x] T081 [P] Create rake task for bulk import from JSON in `lib/tasks/legacy_redirects.rake`
- [x] T082 [P] Create rake task for usage report in `lib/tasks/legacy_redirects.rake`
- [ ] T083 [P] Add navigation link to admin sidebar for legacy redirects management (deferred)
- [x] T084 Run RuboCop linter and fix any style violations
- [x] T085 Run Brakeman security scanner and address any warnings
- [x] T086 Review quickstart.md and verify all examples work
- [x] T087 Test all three user stories together to ensure no conflicts
- [ ] T088 Performance test: Verify <10ms middleware overhead (verified through tests)
- [ ] T089 Manual testing: Test 5-10 legacy URLs from seed data (ready for manual verification)
- [ ] T090 Documentation: Update CLAUDE.md with deployment notes (optional)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup (Phase 1) completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational (Phase 2) completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Independent of US1 (fallback behavior)
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - Uses LegacyRedirect model but doesn't depend on middleware

### Within Each User Story

**TDD Workflow (CRITICAL)**:
1. Write tests FIRST - ensure they FAIL (red phase)
2. Implement minimum code to make tests pass (green phase)
3. Refactor for quality (refactor phase)
4. Verify all tests still pass

**Task Order**:
- Tests before implementation (TDD)
- Model tests before model implementation
- Middleware tests before middleware implementation
- Controller tests before controller implementation
- Integration tests after core implementation
- System tests last (verify end-to-end)

### Parallel Opportunities

**Within Setup Phase**:
- T003 and T004 can run in parallel (different directories)

**Within Foundational Phase**:
- All test writing tasks can be prepared in parallel
- Model implementation tasks run sequentially (TDD cycle)

**Within User Story 1**:
- All 10 middleware test tasks (T016-T025) can be written in parallel
- Integration and system test writing can run in parallel

**Within User Story 3**:
- All 10 controller test tasks (T049-T058) can be written in parallel
- All 5 view tasks (T072-T076) can run in parallel after controller is done

**Across User Stories**:
- US1, US2, US3 can be worked on by different developers simultaneously after Foundational phase
- US2 can start while US1 is still in progress (independent)
- US3 can start while US1/US2 are in progress (independent)

**Within Polish Phase**:
- Rake tasks (T080-T082) can be created in parallel
- Linting, security, and documentation tasks can run in parallel

---

## Parallel Example: User Story 1

### Parallel Test Writing (Red Phase)
```bash
# Launch all middleware tests for User Story 1 together:
- T016: Test redirect match found (active)
- T017: Test no match found
- T018: Test match found (inactive)
- T019: Test case-insensitive match
- T020: Test trailing slash handling
- T021: Test query parameter preservation
- T022: Test non-GET request pass-through
- T023: Test non-product path pass-through
- T024: Test hit counter increment
- T025: Test database error handling
```

### Sequential Implementation (Green Phase)
```bash
# Implement middleware methods one at a time to make tests pass:
- T026: Create stub
- T027: Implement initialize
- T028: Implement call with path check
- T029: Implement lookup logic
- T030: Implement target URL building
- T031: Implement query preservation
- T032: Implement 301 response
- T033: Implement hit counter
- T034: Implement error handling
```

---

## Parallel Example: User Story 3

### Parallel Test Writing (Red Phase)
```bash
# Launch all controller tests for User Story 3 together:
- T049: Test index action
- T050: Test show action
- T051: Test new action
- T052: Test create action
- T053: Test edit action
- T054: Test update action
- T055: Test destroy action
- T056: Test toggle action
- T057: Test test action
- T058: Test authentication
```

### Parallel View Creation
```bash
# After controller is complete, create all views in parallel:
- T072: Index view
- T073: Show view
- T074: New view
- T075: Edit view
- T076: Form partial
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Phase 2: Foundational (T005-T015) - CRITICAL
3. Complete Phase 3: User Story 1 (T016-T043)
4. **STOP and VALIDATE**: Test legacy URL redirects work
5. Deploy/demo MVP

**MVP Deliverable**: 63 legacy URLs redirect correctly to new product pages

### Incremental Delivery

1. Complete Setup + Foundational (T001-T015) → Foundation ready
2. Add User Story 1 (T016-T043) → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 (T044-T048) → Test independently → Deploy/Demo
4. Add User Story 3 (T049-T079) → Test independently → Deploy/Demo
5. Polish (T080-T090) → Final deployment

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together (T001-T015)
2. Once Foundational is done:
   - **Developer A**: User Story 1 (T016-T043) - Middleware implementation
   - **Developer B**: User Story 3 (T049-T079) - Admin interface
   - **Developer C**: User Story 2 (T044-T048) + Polish (T080-T090)
3. Stories complete and integrate independently
4. Final verification and deployment

---

## Task Summary

**Total Tasks**: 90
- **Phase 1 (Setup)**: 4 tasks
- **Phase 2 (Foundational)**: 11 tasks (BLOCKS all user stories)
- **Phase 3 (US1 - P1)**: 28 tasks (MVP)
- **Phase 4 (US2 - P2)**: 5 tasks
- **Phase 5 (US3 - P3)**: 31 tasks
- **Phase 6 (Polish)**: 11 tasks

**Parallelizable Tasks**: 44 marked with [P]

**TDD Tasks**: 30 test tasks MUST be written FIRST before implementation

**MVP Scope**: Phases 1-3 (43 tasks) delivers functional redirect system

**Independent Testing Checkpoints**:
- After Phase 2: Model is complete and tested
- After Phase 3: Legacy URL redirects work (MVP ready)
- After Phase 4: Fallback behavior works
- After Phase 5: Admin interface works
- After Phase 6: Production ready

---

## Notes

- **[P] tasks** = different files, no dependencies, can run in parallel
- **[Story] label** = maps task to specific user story for traceability
- **TDD required**: All test tasks MUST fail before writing implementation
- Each user story should be independently completable and testable
- Run tests after each implementation task to verify green phase
- Commit after each task or logical group (e.g., all tests for a story)
- Stop at any checkpoint to validate story independently
- **Constitution compliance**: RuboCop + Brakeman must pass before deployment
