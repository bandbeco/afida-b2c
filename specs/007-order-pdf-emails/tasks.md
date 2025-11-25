# Tasks: Order Summary PDF Attachment

**Input**: Design documents from `/specs/007-order-pdf-emails/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests are MANDATORY per project constitution (Principle I: Test-First Development). All tests written BEFORE implementation (RED-GREEN-REFACTOR cycle).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Rails monolith structure:
- **Services**: `app/services/`
- **Controllers**: `app/controllers/admin/`
- **Mailers**: `app/mailers/`
- **Views**: `app/views/admin/orders/`
- **Tests**: `test/services/`, `test/mailers/`, `test/controllers/`, `test/system/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and gem dependencies

- [ ] T001 Add Prawn gem dependencies to Gemfile (prawn ~> 2.5, prawn-table ~> 0.2)
- [ ] T002 Run bundle install to install PDF generation gems
- [ ] T003 Verify logo file exists at app/frontend/images/logo.png
- [ ] T004 [P] Create app/services directory if not exists
- [ ] T005 [P] Create test/services directory if not exists

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T006 Create test fixtures for complete_order in test/fixtures/orders.yml with all required fields
- [ ] T007 [P] Create test fixtures for order_items in test/fixtures/order_items.yml (2+ items for complete_order)
- [ ] T008 Verify existing Order model has all required attributes for PDF generation (order_number, shipping fields, amounts)
- [ ] T009 Verify existing OrderItem model has all required attributes (product_name, quantity, price, total_price)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Customer Receives Order PDF (Priority: P1) 🎯 MVP

**Goal**: Generate PDF order summaries and attach them to order confirmation emails. Customers receive professional PDF receipts automatically.

**Independent Test**: Place test order, complete checkout, verify email contains PDF attachment with correct order details.

### Tests for User Story 1 (Written FIRST - RED Phase)

> **TDD REQUIREMENT**: Write these tests FIRST, ensure they FAIL before implementation

- [ ] T010 [P] [US1] Write unit test for OrderPdfGenerator initialization in test/services/order_pdf_generator_test.rb
- [ ] T011 [P] [US1] Write unit test for PDF generation success with valid order in test/services/order_pdf_generator_test.rb
- [ ] T012 [P] [US1] Write unit test for PDF file size under 500KB limit in test/services/order_pdf_generator_test.rb
- [ ] T013 [P] [US1] Write unit test for PDF generation error with order without items in test/services/order_pdf_generator_test.rb
- [ ] T014 [P] [US1] Write integration test for OrderMailer with PDF attachment in test/mailers/order_mailer_test.rb
- [ ] T015 [P] [US1] Write integration test for OrderMailer sending without PDF on generation failure in test/mailers/order_mailer_test.rb
- [ ] T016 [US1] Run tests to verify they FAIL (RED phase) - rails test test/services/order_pdf_generator_test.rb test/mailers/order_mailer_test.rb

### Implementation for User Story 1 (GREEN Phase)

- [ ] T017 [US1] Create OrderPdfGenerator service class in app/services/order_pdf_generator.rb with initialize method
- [ ] T018 [US1] Implement generate method stub in app/services/order_pdf_generator.rb (returns empty string initially)
- [ ] T019 [US1] Implement validate_order! private method in app/services/order_pdf_generator.rb (checks items, shipping address)
- [ ] T020 [US1] Implement build_header private method with logo and company name in app/services/order_pdf_generator.rb
- [ ] T021 [US1] Implement build_order_info private method with order number and date in app/services/order_pdf_generator.rb
- [ ] T022 [US1] Implement build_shipping_address private method in app/services/order_pdf_generator.rb
- [ ] T023 [US1] Implement build_line_items_table private method using prawn-table in app/services/order_pdf_generator.rb
- [ ] T024 [US1] Implement build_totals private method with subtotal, VAT, shipping, total in app/services/order_pdf_generator.rb
- [ ] T025 [US1] Complete generate method to call all build methods and return PDF data in app/services/order_pdf_generator.rb
- [ ] T026 [US1] Update OrderMailer#confirmation_email to generate PDF in app/mailers/order_mailer.rb
- [ ] T027 [US1] Add PDF attachment to email with correct filename format in app/mailers/order_mailer.rb
- [ ] T028 [US1] Add error handling with rescue block to catch PDF generation failures in app/mailers/order_mailer.rb
- [ ] T029 [US1] Add Rails.logger.error calls for PDF generation failures in app/mailers/order_mailer.rb
- [ ] T030 [US1] Run tests to verify they PASS (GREEN phase) - rails test test/services/order_pdf_generator_test.rb test/mailers/order_mailer_test.rb
- [ ] T031 [US1] Refactor OrderPdfGenerator to extract format_currency helper method (REFACTOR phase)
- [ ] T032 [US1] Run tests again to ensure refactoring didn't break functionality
- [ ] T033 [US1] Manual test: Create test order in console and verify OrderMailer.with(order: order).confirmation_email sends with PDF

**Checkpoint**: At this point, User Story 1 should be fully functional - customers receive order PDFs via email

---

## Phase 4: User Story 2 - PDF Contains Branding (Priority: P2)

**Goal**: Enhance PDFs with professional branding (logo, colors, contact information) for better brand presentation.

**Independent Test**: Review PDF attachment to verify presence of logo, brand colors, and company contact information.

**Note**: This story enhances US1, so US1 must be complete first. However, all changes are in OrderPdfGenerator service.

### Tests for User Story 2 (Written FIRST - RED Phase)

- [ ] T034 [P] [US2] Write unit test verifying PDF contains company contact info (email, phone) in test/services/order_pdf_generator_test.rb
- [ ] T035 [P] [US2] Write unit test verifying build_footer is called during PDF generation in test/services/order_pdf_generator_test.rb
- [ ] T036 [US2] Run tests to verify they FAIL (RED phase) - rails test test/services/order_pdf_generator_test.rb

### Implementation for User Story 2 (GREEN Phase)

- [ ] T037 [US2] Implement build_footer private method with thank you message in app/services/order_pdf_generator.rb
- [ ] T038 [US2] Add company contact information (website, email, phone) to footer in app/services/order_pdf_generator.rb
- [ ] T039 [US2] Add horizontal rule separator before footer in app/services/order_pdf_generator.rb
- [ ] T040 [US2] Add pdf.move_down(40) and call to build_footer in generate method in app/services/order_pdf_generator.rb
- [ ] T041 [US2] Verify logo displays correctly with 150px width in build_header method in app/services/order_pdf_generator.rb
- [ ] T042 [US2] Run tests to verify they PASS (GREEN phase) - rails test test/services/order_pdf_generator_test.rb
- [ ] T043 [US2] Manual test: Generate PDF and verify logo, footer, and contact info appear correctly

**Checkpoint**: At this point, User Stories 1 AND 2 should both work - PDFs include professional branding

---

## Phase 5: User Story 3 - Admin Can Preview PDF (Priority: P3)

**Goal**: Allow administrators to preview order PDFs from admin panel for quality assurance.

**Independent Test**: Login to admin panel, view order, click "Preview PDF", verify PDF opens in new tab with correct content.

### Tests for User Story 3 (Written FIRST - RED Phase)

- [ ] T044 [P] [US3] Write controller test for preview_pdf action success in test/controllers/admin/orders_controller_test.rb
- [ ] T045 [P] [US3] Write controller test for preview_pdf action with non-existent order (404) in test/controllers/admin/orders_controller_test.rb
- [ ] T046 [P] [US3] Write system test for admin preview button click in test/system/admin/order_preview_test.rb
- [ ] T047 [US3] Run tests to verify they FAIL (RED phase) - rails test test/controllers/admin/orders_controller_test.rb test/system/admin/order_preview_test.rb

### Implementation for User Story 3 (GREEN Phase)

- [ ] T048 [US3] Add member route for preview_pdf in config/routes.rb (namespace :admin, resources :orders, member: { get :preview_pdf })
- [ ] T049 [US3] Add preview_pdf to before_action :set_order in app/controllers/admin/orders_controller.rb
- [ ] T050 [US3] Add eager loading of order_items in set_order method (Order.includes(:order_items)) in app/controllers/admin/orders_controller.rb
- [ ] T051 [US3] Implement preview_pdf action with PDF generation in app/controllers/admin/orders_controller.rb
- [ ] T052 [US3] Add send_data call with inline disposition in preview_pdf action in app/controllers/admin/orders_controller.rb
- [ ] T053 [US3] Add error handling with rescue and redirect in preview_pdf action in app/controllers/admin/orders_controller.rb
- [ ] T054 [US3] Add "Preview PDF" button to admin order show page in app/views/admin/orders/show.html.erb
- [ ] T055 [US3] Style preview button with target="_blank" and btn classes in app/views/admin/orders/show.html.erb
- [ ] T056 [US3] Run tests to verify they PASS (GREEN phase) - rails test test/controllers/admin/orders_controller_test.rb test/system/admin/order_preview_test.rb
- [ ] T057 [US3] Manual test: Login to admin, navigate to order, click "Preview PDF", verify PDF opens in new tab

**Checkpoint**: All user stories should now be independently functional - customers receive PDFs, PDFs have branding, admins can preview

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories or overall quality

- [ ] T058 [P] Run RuboCop linter on all modified files - rubocop app/services/order_pdf_generator.rb app/mailers/order_mailer.rb app/controllers/admin/orders_controller.rb
- [ ] T059 [P] Fix any RuboCop violations in modified files
- [ ] T060 [P] Run Brakeman security scanner - brakeman
- [ ] T061 [P] Review and fix any security warnings from Brakeman
- [ ] T062 Run full test suite to ensure no regressions - rails test
- [ ] T063 [P] Add performance logging for PDF generation time in OrderPdfGenerator#generate
- [ ] T064 [P] Add performance logging for PDF file size in OrderPdfGenerator#generate
- [ ] T065 [P] Verify logo file is compressed and under 50KB - ls -lh app/frontend/images/logo.png
- [ ] T066 Manual end-to-end test: Complete full checkout, verify email with PDF, open PDF on multiple devices
- [ ] T067 Update CLAUDE.md to document new OrderPdfGenerator service pattern (if needed)
- [ ] T068 Verify all success criteria from spec.md are met (SC-001 through SC-007)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User Story 1 (P1) can start immediately after Foundational
  - User Story 2 (P2) depends on User Story 1 (enhances PDF generation)
  - User Story 3 (P3) can start after Foundational (independent of US1/US2, but uses same OrderPdfGenerator)
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Depends on User Story 1 completion - Enhances existing PDF generation with branding
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - Independent of US1/US2 (can run in parallel with US2)

### Within Each User Story

- Tests MUST be written and FAIL before implementation (TDD RED phase)
- OrderPdfGenerator service before OrderMailer modification (US1)
- OrderMailer modification before admin controller (US3 can use service directly)
- Controller before view (US3)
- Tests PASS after implementation (GREEN phase)
- Refactor after tests pass (REFACTOR phase)

### Parallel Opportunities

- **Phase 1 Setup**: T001-T005 all marked [P] can run in parallel
- **Phase 2 Foundational**: T006-T007 marked [P] can run in parallel
- **US1 Tests**: T010-T015 all marked [P] can run in parallel (write all tests together)
- **US2 Tests**: T034-T035 marked [P] can run in parallel
- **US3 Tests**: T044-T046 marked [P] can run in parallel
- **Polish**: T058-T061 and T063-T065 marked [P] can run in parallel
- **User Story 3 can run in parallel with User Story 2** (different files, independent functionality)

---

## Parallel Example: User Story 1

```bash
# Launch all test tasks for User Story 1 together (TDD RED phase):
Task: "Write unit test for OrderPdfGenerator initialization in test/services/order_pdf_generator_test.rb"
Task: "Write unit test for PDF generation success in test/services/order_pdf_generator_test.rb"
Task: "Write unit test for PDF file size under 500KB in test/services/order_pdf_generator_test.rb"
Task: "Write unit test for PDF generation error with order without items in test/services/order_pdf_generator_test.rb"
Task: "Write integration test for OrderMailer with PDF attachment in test/mailers/order_mailer_test.rb"
Task: "Write integration test for OrderMailer sending without PDF on failure in test/mailers/order_mailer_test.rb"

# Then after tests fail (RED), implement all private methods in OrderPdfGenerator together:
# (These depend on each other, so sequential execution within the service)
```

---

## Parallel Example: User Story 3

```bash
# Launch all test tasks for User Story 3 together (TDD RED phase):
Task: "Write controller test for preview_pdf action success in test/controllers/admin/orders_controller_test.rb"
Task: "Write controller test for preview_pdf with 404 in test/controllers/admin/orders_controller_test.rb"
Task: "Write system test for admin preview button in test/system/admin/order_preview_test.rb"

# User Story 3 implementation can run in PARALLEL with User Story 2:
# - US2 modifies OrderPdfGenerator service
# - US3 modifies Admin::OrdersController and view
# Different files = no conflicts
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (5 tasks, ~15 minutes)
2. Complete Phase 2: Foundational (4 tasks, ~15 minutes)
3. Complete Phase 3: User Story 1 (23 tasks, ~3-4 hours with TDD)
4. **STOP and VALIDATE**: Test User Story 1 independently
   - Run full test suite for US1
   - Manual email test with real order
   - Verify PDF attachment, content, file size
5. Deploy/demo if ready (MVP functional!)

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready (~30 minutes)
2. Add User Story 1 → Test independently → Deploy/Demo (MVP! ~4 hours)
3. Add User Story 2 → Test independently → Deploy/Demo (~1 hour)
4. Add User Story 3 → Test independently → Deploy/Demo (~1.5 hours)
5. Polish phase → Final quality checks (~1 hour)
6. Total: ~7.5-8 hours for complete feature

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together (~30 minutes)
2. Once Foundational is done:
   - Developer A: User Story 1 (4 hours)
   - Developer B: Can start User Story 3 in parallel (1.5 hours)
3. After US1 complete:
   - Developer A or B: User Story 2 (1 hour)
4. Team: Polish together (1 hour)
5. Total: ~6.5 hours with 2 developers (25% time savings)

---

## Notes

- **TDD MANDATORY**: Constitution Principle I requires all tests BEFORE implementation (RED-GREEN-REFACTOR)
- **[P] tasks**: Different files, no dependencies, can run in parallel
- **[Story] label**: Maps task to specific user story for traceability
- **Each user story**: Independently completable and testable
- **Verify tests FAIL**: Before implementing (RED phase)
- **Verify tests PASS**: After implementing (GREEN phase)
- **Refactor**: After tests pass, improve code quality
- **Commit frequency**: After each logical group or story checkpoint
- **Stop at checkpoints**: Validate story independently before proceeding
- **File paths**: All paths are absolute and specific to this Rails project structure
- **Performance targets**: <3s PDF generation, <500KB file size (measured in tests)
- **Error handling**: Email sends even if PDF fails (graceful degradation)

---

## Task Count Summary

- **Phase 1 (Setup)**: 5 tasks
- **Phase 2 (Foundational)**: 4 tasks
- **Phase 3 (User Story 1 - MVP)**: 24 tasks (7 tests + 17 implementation)
- **Phase 4 (User Story 2)**: 10 tasks (3 tests + 7 implementation)
- **Phase 5 (User Story 3)**: 14 tasks (4 tests + 10 implementation)
- **Phase 6 (Polish)**: 11 tasks

**Total**: 68 tasks

**Parallel opportunities**: 19 tasks marked [P] can run concurrently
**MVP scope**: Phases 1-3 (33 tasks, ~4.5 hours)
**Full feature**: All phases (68 tasks, ~7.5-8 hours)
