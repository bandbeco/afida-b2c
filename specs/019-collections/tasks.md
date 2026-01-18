# Tasks: Collections & Curated Sample Packs

**Input**: Design documents from `/specs/019-collections/`
**Prerequisites**: plan.md (required), spec.md (required for user stories)

**Tests**: Included following existing CLAUDE.md patterns (fixtures-based Minitest)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Database & Models)

**Purpose**: Create database tables and core models

- [ ] T001 Create collections migration in db/migrate/XXXXXX_create_collections.rb
- [ ] T002 Create collection_items migration in db/migrate/XXXXXX_create_collection_items.rb
- [ ] T003 Run migrations with `rails db:migrate`
- [ ] T004 [P] Create Collection model in app/models/collection.rb
- [ ] T005 [P] Create CollectionItem model in app/models/collection_item.rb
- [ ] T006 Add collections association to Product model in app/models/product.rb
- [ ] T007 [P] Create collections fixture in test/fixtures/collections.yml
- [ ] T008 [P] Create collection_items fixture in test/fixtures/collection_items.yml

**Checkpoint**: Models created, migrations run, fixtures ready

---

## Phase 2: Foundational (Model Tests)

**Purpose**: Validate models work correctly before building features

- [ ] T009 [P] Create Collection model test in test/models/collection_test.rb
- [ ] T010 [P] Create CollectionItem model test in test/models/collection_item_test.rb
- [ ] T011 Run model tests with `rails test test/models/collection_test.rb test/models/collection_item_test.rb`
- [ ] T012 Add collection routes to config/routes.rb (public and admin)

**Checkpoint**: Foundation ready - all model tests pass, routes configured

---

## Phase 3: User Story 1 - Browse Products by Audience Type (Priority: P1) 🎯 MVP

**Goal**: Visitors can browse products by audience type on collection pages

**Independent Test**: Navigate to `/collections/coffee-shop` and verify products display in grid

### Tests for User Story 1

- [ ] T013 [P] [US1] Create collections controller test in test/controllers/collections_controller_test.rb

### Implementation for User Story 1

- [ ] T014 [US1] Create CollectionsController in app/controllers/collections_controller.rb
- [ ] T015 [P] [US1] Create collections helper in app/helpers/collections_helper.rb
- [ ] T016 [P] [US1] Create collection card partial in app/views/collections/_card.html.erb
- [ ] T017 [US1] Create collections index view in app/views/collections/index.html.erb
- [ ] T018 [US1] Create collection show view in app/views/collections/show.html.erb
- [ ] T019 [US1] Run controller tests with `rails test test/controllers/collections_controller_test.rb`

**Checkpoint**: User Story 1 complete - visitors can browse collections and view products

---

## Phase 4: User Story 2 - Request Curated Sample Pack (Priority: P2)

**Goal**: Visitors can add all products from a sample pack to cart with one click

**Independent Test**: Navigate to `/samples/pack/coffee-shop-samples` and click "Add All to Cart"

### Tests for User Story 2

- [ ] T020 [P] [US2] Create sample packs controller test in test/controllers/samples_controller_packs_test.rb

### Implementation for User Story 2

- [ ] T021 [US2] Add sample pack routes to config/routes.rb (pack and add_pack actions)
- [ ] T022 [US2] Add pack and add_pack actions to SamplesController in app/controllers/samples_controller.rb
- [ ] T023 [US2] Create sample pack view in app/views/samples/pack.html.erb
- [ ] T024 [US2] Add sample packs section to samples index in app/views/samples/index.html.erb
- [ ] T025 [US2] Run controller tests with `rails test test/controllers/samples_controller_packs_test.rb`

**Checkpoint**: User Story 2 complete - visitors can request curated sample packs

---

## Phase 5: User Story 3 - Manage Collections in Admin (Priority: P3)

**Goal**: Administrators can create, edit, and organise collections

**Independent Test**: Log into admin, create a collection, add products, verify it appears on public site

### Tests for User Story 3

- [ ] T026 [P] [US3] Create admin collections controller test in test/controllers/admin/collections_controller_test.rb

### Implementation for User Story 3

- [ ] T027 [US3] Create Admin::CollectionsController in app/controllers/admin/collections_controller.rb
- [ ] T028 [P] [US3] Create admin collection form partial in app/views/admin/collections/_form.html.erb
- [ ] T029 [P] [US3] Create admin product selector partial in app/views/admin/collections/_product_selector.html.erb
- [ ] T030 [US3] Create admin collections index view in app/views/admin/collections/index.html.erb
- [ ] T031 [P] [US3] Create admin collections new view in app/views/admin/collections/new.html.erb
- [ ] T032 [P] [US3] Create admin collections edit view in app/views/admin/collections/edit.html.erb
- [ ] T033 [US3] Create admin collections order view in app/views/admin/collections/order.html.erb
- [ ] T034 [US3] Run controller tests with `rails test test/controllers/admin/collections_controller_test.rb`

**Checkpoint**: User Story 3 complete - admins can fully manage collections

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Navigation integration, system tests, final polish

- [ ] T035 [P] Add Collections link to site navigation in app/views/shared/_navbar.html.erb or _category_nav.html.erb
- [ ] T036 [P] Add Collections link to admin navigation in app/views/layouts/admin.html.erb
- [ ] T037 [P] Create system tests in test/system/collections_test.rb
- [ ] T038 Run all tests with `rails test`
- [ ] T039 Manual verification: create collection in admin, verify public pages, test sample pack flow

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User stories can proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational - Depends on US1 models being available (they are in Foundational)
- **User Story 3 (P3)**: Can start after Foundational - Uses same models, independent of US1/US2 public features

### Within Each User Story

- Tests written first (TDD approach per CLAUDE.md)
- Controller before views
- Core implementation before integration
- Run tests before marking complete

### Parallel Opportunities

**Phase 1 (Setup)**:
```bash
# After migrations, these can run in parallel:
T004: Create Collection model
T005: Create CollectionItem model
T007: Create collections fixture
T008: Create collection_items fixture
```

**Phase 2 (Foundational)**:
```bash
# Model tests can run in parallel:
T009: Collection model test
T010: CollectionItem model test
```

**Phase 3 (US1)**:
```bash
# These views can be created in parallel:
T015: collections_helper.rb
T016: _card.html.erb
```

**Phase 5 (US3 - Admin)**:
```bash
# These admin views can be created in parallel:
T028: _form.html.erb
T029: _product_selector.html.erb
T031: new.html.erb
T032: edit.html.erb
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T008)
2. Complete Phase 2: Foundational (T009-T012)
3. Complete Phase 3: User Story 1 (T013-T019)
4. **STOP and VALIDATE**: Test collection pages work
5. Deploy/demo if ready - visitors can now browse by audience type

### Incremental Delivery

1. **MVP**: Setup + Foundational + US1 = Collection browsing works
2. **+Sample Packs**: Add US2 = Curated sample packs work
3. **+Admin**: Add US3 = Full admin management
4. **+Polish**: Add Phase 6 = Navigation and final touches

### Parallel Team Strategy

With multiple developers after Foundational is complete:
- **Developer A**: User Story 1 (public collection pages)
- **Developer B**: User Story 2 (sample pack flow)
- **Developer C**: User Story 3 (admin interface)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Use fixtures (not factories) per CLAUDE.md
- Follow existing Category/Product patterns throughout
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
