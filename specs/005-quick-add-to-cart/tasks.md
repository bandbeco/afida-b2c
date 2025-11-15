# Tasks: Quick Add to Cart

**Input**: Design documents from `/specs/005-quick-add-to-cart/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: This feature follows TDD (Test-Driven Development) as required by the constitution. All test tasks MUST be completed and FAIL before implementation begins.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

This is a Rails monolith with Vite frontend:
- **Backend**: `app/controllers/`, `app/models/`, `app/views/`
- **Frontend**: `app/frontend/javascript/controllers/`, `app/frontend/stylesheets/`
- **Tests**: `test/system/`, `test/controllers/`, `test/models/`
- **Routes**: `config/routes.rb`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and routing setup

- [X] T001 Add route for quick_add action in config/routes.rb
- [X] T002 Create shared modal container partial in app/views/shared/_quick_add_modal.html.erb
- [X] T003 [P] Register Stimulus controller in app/frontend/entrypoints/application.js

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Add quick_add_eligible scope to Product model in app/models/product.rb
- [X] T005 Add ProductsController#quick_add action in app/controllers/products_controller.rb
- [X] T006 Create quick_add view template in app/views/products/quick_add.html.erb
- [X] T007 Create Stimulus controller in app/frontend/javascript/controllers/quick_add_modal_controller.js
- [X] T008 Add shared modal container to application layout in app/views/layouts/application.html.erb

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Quick Add for Standard Products (Priority: P1) 🎯 MVP

**Goal**: Enable users to add single-variant products to cart from shop/category pages via modal without visiting product detail page

**Independent Test**:
1. Navigate to /shop
2. Click "Quick Add" on single-variant product (e.g., "Pizza Box - Kraft")
3. Modal opens with quantity selector
4. Select quantity, click "Add to Basket"
5. Modal closes, cart drawer opens, cart counter updates
6. Verify cart contains correct product and quantity

### Tests for User Story 1 ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T009 [P] [US1] System test for single-variant quick add flow in test/system/quick_add_test.rb
- [X] T010 [P] [US1] Controller test for ProductsController#quick_add in test/controllers/products_controller_test.rb
- [X] T011 [P] [US1] Model test for Product.quick_add_eligible scope in test/models/product_test.rb

**Checkpoint**: All tests written and FAILING - ready for implementation

### Implementation for User Story 1

- [X] T012 [US1] Add Quick Add button to product card partial in app/views/products/_card.html.erb
- [X] T013 [US1] Implement modal content rendering in app/views/products/quick_add.html.erb
- [X] T014 [US1] Create quick add form partial in app/views/products/_quick_add_form.html.erb
- [X] T015 [US1] Implement Stimulus controller open/close methods in app/frontend/javascript/controllers/quick_add_modal_controller.js
- [X] T016 [US1] Implement form submission handling in Stimulus controller (handleSubmitEnd method)
- [X] T017 [US1] Add cart:updated event dispatch in Stimulus controller
- [X] T018 [US1] Update cart_drawer_controller.js to listen for cart:updated event
- [X] T019 [US1] Update CartItemsController#create Turbo Stream response to clear modal

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently. Run `rails test test/system/quick_add_test.rb` - all tests should PASS.

---

## Phase 4: User Story 2 - Multi-Variant Product Support (Priority: P2)

**Goal**: Enable users to select variant (size/option) before adding multi-variant products to cart

**Independent Test**:
1. Navigate to /shop
2. Click "Quick Add" on multi-variant product (e.g., "Single Wall Hot Cup" with 8oz, 12oz, 16oz variants)
3. Modal opens with variant selector AND quantity selector
4. Select variant "12oz", select quantity "2 packs"
5. Price updates to show 12oz price
6. Click "Add to Basket"
7. Modal closes, cart drawer opens
8. Verify cart contains "Single Wall Hot Cup (12oz)" with correct quantity

### Tests for User Story 2 ⚠️

- [X] T020 [P] [US2] System test for multi-variant quick add flow in test/system/quick_add_test.rb
- [X] T021 [P] [US2] System test for price updates on variant change in test/system/quick_add_test.rb
- [X] T022 [P] [US2] System test for cart item quantity increment (existing item) in test/system/quick_add_test.rb

**Checkpoint**: All tests written and FAILING - ready for implementation

### Implementation for User Story 2

- [X] T023 [US2] Add variant selector to modal form in app/views/products/_quick_add_form.html.erb
- [X] T024 [US2] Create Stimulus controller for form updates in app/frontend/javascript/controllers/quick_add_form_controller.js
- [X] T025 [US2] Implement variant selector change handler (updateVariant method)
- [X] T026 [US2] Implement quantity selector change handler (updateQuantity method)
- [X] T027 [US2] Implement price calculation logic in Stimulus controller
- [X] T028 [US2] Add price display element to modal template
- [X] T029 [US2] Update hidden variant_sku input on variant selection

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently. Run full test suite - all tests should PASS.

---

## Phase 5: User Story 3 - Mobile UX & Accessibility (Priority: P3)

**Goal**: Optimize modal for mobile devices (bottom-sheet) and ensure full WCAG 2.1 AA accessibility compliance

**Independent Test**:
1. **Mobile**: Open /shop on mobile device or responsive mode (<768px width)
2. Click Quick Add - modal should slide up from bottom (not center)
3. Modal should not cover entire screen (max 85vh height)
4. Touch targets should be ≥44x44pt
5. **Accessibility**: Test keyboard navigation (Tab, Shift+Tab, ESC, Enter)
6. Test screen reader announcements (VoiceOver/NVDA)
7. Run axe DevTools - 0 violations
8. Run Lighthouse Accessibility - score ≥95

### Tests for User Story 3 ⚠️

- [X] T030 [P] [US3] System test for keyboard navigation in test/system/quick_add_accessibility_test.rb
- [X] T031 [P] [US3] System test for ESC key closing modal in test/system/quick_add_accessibility_test.rb
- [X] T032 [P] [US3] System test for focus management (focus trap, restore) in test/system/quick_add_accessibility_test.rb

**Checkpoint**: All tests written and FAILING - ready for implementation

### Implementation for User Story 3

- [X] T033 [US3] Create modal CSS file in app/frontend/stylesheets/components/quick_add_modal.css
- [X] T034 [US3] Implement mobile bottom-sheet styles (media query <768px)
- [X] T035 [US3] Implement desktop centered modal styles (media query ≥768px)
- [X] T036 [US3] Add ARIA attributes to modal template (role="dialog", aria-modal, aria-labelledby)
- [X] T037 [US3] Implement focus trap in Stimulus controller (trapFocus method)
- [X] T038 [US3] Implement focus management (store and restore previous focus)
- [X] T039 [US3] Add ESC key handler in Stimulus controller (handleEscape method)
- [X] T040 [US3] Add keyboard event listeners (keydown for Tab and ESC)
- [X] T041 [US3] Ensure form labels are properly associated with inputs
- [X] T042 [US3] Import quick_add_modal.css in app/frontend/entrypoints/application.css

**Checkpoint**: All user stories should now be independently functional. Run full test suite - all tests should PASS. Run manual accessibility audit (axe DevTools, Lighthouse, VoiceOver).

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [X] T043 [P] Add Quick Add button only for standard products (conditional rendering in _card.html.erb)
- [X] T044 [P] Disable Quick Add button if product has no active variants
- [X] T045 [P] Add progressive enhancement (href fallback to product page)
- [X] T046 Verify no N+1 queries with Bullet gem (start server, visit /shop, check logs)
- [X] T047 Run RuboCop linter and fix any violations
- [X] T048 Run Brakeman security scanner and address any warnings
- [ ] T049 [P] Manual accessibility audit with axe DevTools (0 violations required)
- [ ] T050 [P] Manual accessibility audit with Lighthouse (score ≥95 required)
- [ ] T051 [P] Manual keyboard navigation testing (follow quickstart.md checklist)
- [ ] T052 [P] Manual screen reader testing with VoiceOver (macOS)
- [ ] T053 Test on mobile Safari iOS (bottom-sheet, touch targets)
- [ ] T054 Test on Chrome Android (bottom-sheet, touch targets)
- [ ] T055 [P] Update CLAUDE.md with Quick Add feature notes (if needed)
- [ ] T056 Run quickstart.md validation (follow developer guide, verify all steps work)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Extends US1 but independently testable
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - Enhances US1/US2 but independently testable

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- All [P] tasks can run in parallel
- Implementation tasks run sequentially or by file (different files = parallelizable)
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks can run in parallel (Phase 1)
- Tasks T004-T005 in Foundational can run in parallel (different files)
- Tasks T006-T008 in Foundational can run in parallel (different files)
- Once Foundational phase completes, all user stories can start in parallel (if team capacity allows)
- All tests for each user story marked [P] can run in parallel
- Different user stories can be worked on in parallel by different team members

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "System test for single-variant quick add flow in test/system/quick_add_test.rb"
Task: "Controller test for ProductsController#quick_add in test/controllers/products_controller_test.rb"
Task: "Model test for Product.quick_add_eligible scope in test/models/product_test.rb"

# After tests fail, launch view/template tasks together (different files):
Task: "Add Quick Add button to product card partial in app/views/products/_card.html.erb"
Task: "Implement modal content rendering in app/views/products/quick_add.html.erb"
Task: "Create quick add form partial in app/views/products/_quick_add_form.html.erb"

# Then implement Stimulus controller methods sequentially (same file):
Task: "Implement Stimulus controller open/close methods"
Task: "Implement form submission handling"
Task: "Add cart:updated event dispatch"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Write tests for User Story 1 (T009-T011) - ensure they FAIL
4. Complete Phase 3: User Story 1 implementation (T012-T019)
5. **STOP and VALIDATE**: Run `rails test` - all User Story 1 tests should PASS
6. Manual test: Visit /shop, click Quick Add on single-variant product, verify flow works
7. Deploy/demo if ready

**This gives you a working MVP**: Quick add functionality for standard products!

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
   - ✅ Quick add works for single-variant products
3. Add User Story 2 → Test independently → Deploy/Demo
   - ✅ Quick add now works for multi-variant products with variant selector
4. Add User Story 3 → Test independently → Deploy/Demo
   - ✅ Mobile optimized, fully accessible
5. Complete Polish → Final validation → Production release

Each story adds value without breaking previous stories.

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (write tests → implement → verify)
   - Developer B: User Story 2 (write tests → implement → verify)
   - Developer C: User Story 3 (write tests → implement → verify)
3. Stories complete and integrate independently

---

## TDD Workflow (CRITICAL)

**This feature MUST follow Test-Driven Development per constitution:**

### Red Phase (Write Failing Tests)
1. Write test first
2. Run test - it MUST fail (red)
3. Confirm test fails for the right reason

### Green Phase (Minimal Implementation)
4. Write minimal code to make test pass
5. Run test - it MUST pass (green)
6. Do not add extra features

### Refactor Phase (Improve Code)
7. Improve code quality (extract methods, remove duplication)
8. Run test - it MUST still pass
9. Commit

**Example for User Story 1**:
```bash
# RED: Write failing test
rails test test/system/quick_add_test.rb
# Expected: FAIL (no Quick Add button exists)

# GREEN: Add Quick Add button to _card.html.erb
rails test test/system/quick_add_test.rb
# Expected: PASS

# REFACTOR: Extract button to helper method (if needed)
rails test test/system/quick_add_test.rb
# Expected: STILL PASS
```

**Never skip the RED phase** - if your test passes immediately, you didn't write a good test!

---

## Performance Checklist

After implementation, verify:

- [ ] Single modal instance in DOM (not per-card)
- [ ] Product cards eager-load variants (`includes(:active_variants)` in controller)
- [ ] No N+1 queries (run Bullet gem check)
- [ ] Modal load time <500ms (Chrome DevTools Network tab)
- [ ] Shop page load time maintained <2s
- [ ] Mobile bottom-sheet uses GPU-accelerated transforms (translate, not top/left)

**Verify with Bullet Gem**:
```bash
# Start development server (Bullet already enabled in development)
bin/dev

# Navigate to http://localhost:3000/shop
# Check Rails logs for Bullet warnings
# Expected: No N+1 query warnings
```

---

## Accessibility Validation Checklist

Before marking US3 complete, ALL of these must pass:

**Automated Tools**:
- [ ] axe DevTools browser extension: 0 violations, 0 serious issues
- [ ] Lighthouse Accessibility audit: Score ≥95
- [ ] WAVE browser extension: No critical errors

**Manual Keyboard Testing**:
- [ ] Tab navigates forward through modal elements
- [ ] Shift+Tab navigates backward
- [ ] ESC closes modal
- [ ] Enter submits form when button focused
- [ ] Focus returns to Quick Add button on close
- [ ] Focus trapped within modal (Tab at last element cycles to first)

**Manual Screen Reader Testing (VoiceOver on macOS)**:
- [ ] Modal open announced ("Dialog opened" or similar)
- [ ] Modal close announced ("Dialog closed" or similar)
- [ ] Form elements announced with labels
- [ ] Error messages announced (if applicable)
- [ ] Button text announced clearly

**Manual Mobile Testing**:
- [ ] Bottom-sheet slides up from bottom on mobile (<768px)
- [ ] Touch targets ≥44x44pt
- [ ] Modal doesn't cover entire screen (max 85vh)
- [ ] Swipe gestures don't interfere with modal

---

## Notes

- **[P] tasks**: Different files, no dependencies - can run in parallel
- **[Story] label**: Maps task to specific user story for traceability
- **TDD is mandatory**: All tests written FIRST, must FAIL before implementation
- **Each user story**: Independently completable and testable
- **Verify tests fail**: Don't skip the RED phase of red-green-refactor
- **Commit frequently**: After each task or logical group
- **Stop at checkpoints**: Validate story independently before proceeding
- **Run full test suite**: After each user story completion

---

## Summary

**Total Tasks**: 56
**Test Tasks**: 9 (T009-T011, T020-T022, T030-T032)
**Implementation Tasks**: 43 (T012-T054)
**Validation Tasks**: 4 (T055-T056)

**Tasks by User Story**:
- Setup (Phase 1): 3 tasks
- Foundational (Phase 2): 5 tasks
- User Story 1 (Phase 3): 11 tasks (3 tests + 8 implementation)
- User Story 2 (Phase 4): 10 tasks (3 tests + 7 implementation)
- User Story 3 (Phase 5): 13 tasks (3 tests + 10 implementation)
- Polish (Phase 6): 14 tasks

**Parallel Opportunities**:
- Setup phase: All 3 tasks can run in parallel
- Foundational phase: 2 groups of parallel tasks
- User Story 1: 3 test tasks in parallel, 3 view tasks in parallel
- User Story 2: 3 test tasks in parallel
- User Story 3: 3 test tasks in parallel, CSS tasks can run parallel to Stimulus tasks
- Polish phase: Most validation tasks can run in parallel

**MVP Scope**: 19 tasks (Setup + Foundational + User Story 1)
**Full Feature**: 56 tasks (all phases)

**Suggested First Milestone**: Complete Phase 1-3 (MVP) = ~19 tasks, delivers working quick add for single-variant products
