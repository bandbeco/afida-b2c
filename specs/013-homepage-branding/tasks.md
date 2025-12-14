# Tasks: Homepage Branding Section Redesign

**Input**: Design documents from `/specs/013-homepage-branding/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, quickstart.md

**Tests**: System tests are included per Constitution requirement (Test-First Development)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Rails monolith**: `app/views/`, `app/frontend/`, `test/system/`
- Primary file: `app/views/pages/partials/_branding.html.erb`
- Test file: `test/system/homepage_branding_test.rb`

---

## Phase 1: Setup

**Purpose**: Prepare test infrastructure (no project setup needed - existing Rails app)

- [x] T001 Create system test file structure in test/system/homepage_branding_test.rb
- [x] T002 Verify existing branding images are accessible in app/frontend/images/branding/

**Checkpoint**: Test file exists and can be run (will fail with no tests)

---

## Phase 2: Foundational (Section Structure)

**Purpose**: Create the base section container that all user stories will build upon

**⚠️ CRITICAL**: This establishes the section wrapper that US1, US2, US3 all render inside

- [x] T003 Replace existing _branding.html.erb with new section container (pink background, rounded corners, padding) in app/views/pages/partials/_branding.html.erb
- [x] T004 Verify section renders on homepage without errors by visiting root_path

**Checkpoint**: Empty pink section visible on homepage at #branding anchor

---

## Phase 3: User Story 1 - Visual Discovery (Photo Collage) (Priority: P1) 🎯 MVP

**Goal**: Visitors see a visually striking masonry photo collage of real customer-branded products

**Independent Test**: Homepage displays 6 customer photos in masonry layout, adapts to mobile/desktop

### Tests for User Story 1 ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T005 [US1] Write system test for collage image presence (6 images with alt text) in test/system/homepage_branding_test.rb

### Implementation for User Story 1

- [x] T006 [US1] Implement masonry collage container using CSS columns (columns-2 md:columns-3) in app/views/pages/partials/_branding.html.erb
- [x] T007 [US1] Add first 3 photos (DSC_6621, DSC_6736, DSC_6770) with vite_image_tag, alt text, and neobrutalist styling in app/views/pages/partials/_branding.html.erb
- [x] T008 [US1] Add remaining 3 photos (DSC_6872, DSC_7193, DSC_7239) with vite_image_tag, alt text, and neobrutalist styling in app/views/pages/partials/_branding.html.erb
- [x] T009 [US1] Add hover effects (scale transform) to collage photos in app/views/pages/partials/_branding.html.erb
- [x] T010 [US1] Run system test T005 - verify it passes

**Checkpoint**: User Story 1 complete - collage displays correctly on mobile and desktop, tests pass

---

## Phase 4: User Story 2 - Value Proposition (Headline + Trust Badges) (Priority: P2)

**Goal**: Visitors understand the branding service benefits through headline and trust badges

**Independent Test**: Section shows "Your Brand. Your Cup." headline and 4 trust badges with correct values

### Tests for User Story 2 ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T011 [US2] Write system test for headline text presence in test/system/homepage_branding_test.rb
- [x] T012 [P] [US2] Write system test for trust badges (UK, 1,000, 20 days, £0) in test/system/homepage_branding_test.rb

### Implementation for User Story 2

- [x] T013 [US2] Add headline "Your Brand. Your Cup." with gradient text styling below collage in app/views/pages/partials/_branding.html.erb
- [x] T014 [US2] Add supporting text line below headline in app/views/pages/partials/_branding.html.erb
- [x] T015 [US2] Add trust badges container (grid-cols-2 md:grid-cols-4) in app/views/pages/partials/_branding.html.erb
- [x] T016 [P] [US2] Implement UK Production badge (emoji, value, label, mint background) in app/views/pages/partials/_branding.html.erb
- [x] T017 [P] [US2] Implement Minimum Order badge (box SVG, 1,000, label, pink background) in app/views/pages/partials/_branding.html.erb
- [x] T018 [P] [US2] Implement Turnaround badge (clock SVG, 20 days, label, yellow background) in app/views/pages/partials/_branding.html.erb
- [x] T019 [P] [US2] Implement Setup Fees badge (checkmark SVG, £0, label, purple background) in app/views/pages/partials/_branding.html.erb
- [x] T020 [US2] Run system tests T011, T012 - verify they pass

**Checkpoint**: User Story 2 complete - headline and all 4 trust badges visible, tests pass

---

## Phase 5: User Story 3 - Taking Action (CTA Button) (Priority: P3)

**Goal**: Visitors can click CTA button to navigate to branded products page

**Independent Test**: "Start Designing" button is visible and navigates to /branded_products

### Tests for User Story 3 ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T021 [US3] Write system test for CTA button presence and text in test/system/homepage_branding_test.rb
- [x] T022 [US3] Write system test for CTA navigation to branded_products_path in test/system/homepage_branding_test.rb

### Implementation for User Story 3

- [x] T023 [US3] Add CTA button container with centered layout below trust badges in app/views/pages/partials/_branding.html.erb
- [x] T024 [US3] Implement "Start Designing" button with link_to branded_products_path and primary button styling in app/views/pages/partials/_branding.html.erb
- [x] T025 [US3] Run system tests T021, T022 - verify they pass

**Checkpoint**: User Story 3 complete - CTA button works, tests pass

---

## Phase 6: Polish & Verification

**Purpose**: Final cleanup and full test suite verification

- [x] T026 [P] Run full system test suite for branding section (all tests in test/system/homepage_branding_test.rb)
- [ ] T027 [P] Verify responsive behavior at 375px, 768px, 1280px, 1920px viewports
- [x] T028 Run RuboCop linter on modified files
- [x] T029 Manual verification against quickstart.md checklist
- [ ] T030 Commit completed feature with descriptive message

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - establishes section container
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User stories should be implemented in priority order (P1 → P2 → P3)
  - Each story builds visually on the previous (collage → headline → CTA)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Depends on US1 (content appears below collage in layout)
- **User Story 3 (P3)**: Depends on US2 (CTA appears below trust badges in layout)

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Implementation follows visual/structural order
- Story complete when tests pass

### Parallel Opportunities

- T011 and T012 (US2 tests) can run in parallel
- T016, T017, T018, T019 (trust badges) can run in parallel
- T026 and T027 (final verification) can run in parallel

---

## Parallel Example: User Story 2

```bash
# Launch tests in parallel:
Task: "Write system test for headline text presence"
Task: "Write system test for trust badges"

# After test container exists, launch badge implementations in parallel:
Task: "Implement UK Production badge"
Task: "Implement Minimum Order badge"
Task: "Implement Turnaround badge"
Task: "Implement Setup Fees badge"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1 (Photo Collage)
4. **STOP and VALIDATE**: Test collage displays correctly
5. Can deploy - collage alone provides value

### Incremental Delivery

1. Complete Setup + Foundational → Section container ready
2. Add User Story 1 → Test → Deploy (MVP - collage visible!)
3. Add User Story 2 → Test → Deploy (headline + badges add context)
4. Add User Story 3 → Test → Deploy (CTA enables conversion)
5. Each story adds value without breaking previous stories

### Single Developer Flow

1. T001-T004: Setup + Foundational (~15 min)
2. T005-T010: User Story 1 - Collage (~30 min)
3. T011-T020: User Story 2 - Headline + Badges (~30 min)
4. T021-T025: User Story 3 - CTA (~15 min)
5. T026-T030: Polish + Verification (~15 min)

**Estimated Total**: ~2 hours

---

## Notes

- [P] tasks = different files or independent code blocks, no dependencies
- [Story] label maps task to specific user story for traceability
- All tasks modify single file (_branding.html.erb) except tests
- Tests in separate file enable parallel test writing
- Commit after each user story completion for clean history
- Stop at any checkpoint to validate story independently
