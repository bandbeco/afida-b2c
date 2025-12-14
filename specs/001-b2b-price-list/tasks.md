# Tasks: B2B Price List

**Input**: Design documents from `/specs/001-b2b-price-list/`
**Prerequisites**: plan.md (required), spec.md (required for user stories)

**Tests**: Tests are NOT explicitly requested in the spec. Implementation-first approach.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and dependencies

- [x] T001 Add caxlsx gem to `Gemfile` for Excel export (after prawn gems)
- [x] T002 Run `bundle install` to install new dependency

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Add routes for price list in `config/routes.rb` (GET /price-list, GET /price-list/export)
- [x] T004 Create `PriceListController` with base filtering logic in `app/controllers/price_list_controller.rb`
- [x] T005 [P] Verify `form_controller.js` exists in `app/frontend/javascript/controllers/` (creates if missing)
- [x] T006 [P] Verify `search_controller.js` exists in `app/frontend/javascript/controllers/` (creates if missing)
- [x] T007 [P] Register form and search controllers in `app/frontend/entrypoints/application.js` (if not already)

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - View Complete Price List (Priority: P1) 🎯 MVP

**Goal**: Business owners can see all products and pricing in a table format without navigating individual pages

**Independent Test**: Visit /price-list and verify all standard products appear in a table with correct columns

### Implementation for User Story 1

- [x] T008 [US1] Create index view layout in `app/views/price_list/index.html.erb` with header, VAT notice, and Turbo Frame wrapper
- [x] T009 [US1] Create table partial in `app/views/price_list/_table.html.erb` with column headers and empty state
- [x] T010 [US1] Create row partial in `app/views/price_list/_row.html.erb` with product link, SKU, size, material, pack size, price columns
- [x] T011 [US1] Add responsive column hiding in `_table.html.erb` (hide SKU, material, price/unit on mobile)
- [x] T012 [US1] Add "Price List" link to desktop navigation in `app/views/shared/_navbar.html.erb`
- [x] T013 [US1] Add "Price List" link to mobile navigation in `app/views/shared/_navbar.html.erb`

**Checkpoint**: User Story 1 complete - table displays all products, navigation works, responsive layout

---

## Phase 4: User Story 2 - Filter Products (Priority: P1) 🎯 MVP

**Goal**: Procurement managers can filter by category, material, size, or search term

**Independent Test**: Apply filters and verify only matching products appear; clear resets all

### Implementation for User Story 2

- [x] T014 [US2] Add filter form to `app/views/price_list/index.html.erb` with Turbo Frame targeting
- [x] T015 [US2] Add Category dropdown filter to filter form in `app/views/price_list/index.html.erb`
- [x] T016 [US2] Add Material dropdown filter to filter form in `app/views/price_list/index.html.erb`
- [x] T017 [US2] Add Size dropdown filter to filter form in `app/views/price_list/index.html.erb`
- [x] T018 [US2] Add search text field to filter form in `app/views/price_list/index.html.erb`
- [x] T019 [US2] Add Clear button (shown when filters active) in `app/views/price_list/index.html.erb`
- [x] T020 [US2] Add result count display in `app/views/price_list/_table.html.erb`
- [x] T021 [US2] Implement JSONB material filtering in `PriceListController#filter_by_material`
- [x] T022 [US2] Implement JSONB size filtering in `PriceListController#filter_by_size`
- [x] T023 [US2] Implement text search in `PriceListController#search_variants`
- [x] T024 [US2] Add `available_materials` and `available_sizes` methods to controller for dropdown options

**Checkpoint**: User Story 2 complete - all filter types work, instant updates via Turbo Frame

---

## Phase 5: User Story 3 - Add to Cart from Price List (Priority: P2)

**Goal**: Repeat customers can add products to cart directly from price list with quantity selection

**Independent Test**: Select quantity, click Add, verify cart drawer opens with correct item and quantity

### Implementation for User Story 3

- [x] T025 [US3] Add quantity dropdown (1, 2, 3, 5, 10) to row partial in `app/views/price_list/_row.html.erb`
- [x] T026 [US3] Add "Add" button with form posting to `cart_cart_items_path` in `app/views/price_list/_row.html.erb`
- [x] T027 [US3] Add cart drawer markup to `app/views/price_list/index.html.erb` (wrapper with drawer-end class)
- [x] T028 [US3] Verify cart drawer opens on add (existing `cart_drawer_controller.js` handles this)

**Checkpoint**: User Story 3 complete - add to cart works, drawer opens, quantity increments for existing items

---

## Phase 6: User Story 4 - Export to Excel (Priority: P2)

**Goal**: Procurement teams can download filtered price list as .xlsx file for sharing

**Independent Test**: Click Excel button, verify .xlsx downloads with correct columns and filtered data

### Implementation for User Story 4

- [x] T029 [US4] Add export action to `app/controllers/price_list_controller.rb` with xlsx format handling
- [x] T030 [US4] Create Excel template in `app/views/price_list/export.xlsx.axlsx` with header styling and data rows
- [x] T031 [US4] Add Excel download button to header in `app/views/price_list/index.html.erb`
- [x] T032 [US4] Add `export_filename` helper method to controller (includes date and filter category)
- [x] T033 [US4] Verify export respects current filter state (uses same `filtered_variants` query)

**Checkpoint**: User Story 4 complete - Excel exports work with filters, proper filename

---

## Phase 7: User Story 5 - Export to PDF (Priority: P3)

**Goal**: Business owners can print or share a branded PDF price list

**Independent Test**: Click PDF button, verify .pdf downloads with Afida branding, fits A4 landscape

### Implementation for User Story 5

- [x] T034 [US5] Create `PriceListPdf` service class in `app/services/price_list_pdf.rb`
- [x] T035 [US5] Implement header section in PDF service (title, filter description, date, VAT notice)
- [x] T036 [US5] Implement table section in PDF service (styled header row, data rows)
- [x] T037 [US5] Implement footer section in PDF service (page numbers)
- [x] T038 [US5] Add PDF format handling to export action in `app/controllers/price_list_controller.rb`
- [x] T039 [US5] Add PDF download button to header in `app/views/price_list/index.html.erb`
- [x] T040 [US5] Add `filter_description` helper method to controller for PDF header

**Checkpoint**: User Story 5 complete - PDF exports work with branding, proper layout

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T041 Add meta title and description in `app/views/price_list/index.html.erb`
- [x] T042 [P] Verify RuboCop compliance on new controller and service files
- [ ] T043 Manual testing: complete all 14 checklist items (page load, filters, cart, exports, mobile, nav)
- [ ] T044 Commit final polish based on testing feedback

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase completion
  - US1 (View) and US2 (Filter) should be done together for MVP
  - US3 (Cart), US4 (Excel), US5 (PDF) can proceed after US1+US2
- **Polish (Phase 8)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (View, P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 2 (Filter, P1)**: Can start after Foundational - Best done with US1 for complete MVP
- **User Story 3 (Cart, P2)**: Depends on US1 row partial existing - Otherwise independent
- **User Story 4 (Excel, P2)**: Depends on controller and filtering logic from US2 - Otherwise independent
- **User Story 5 (PDF, P3)**: Depends on controller and filtering logic from US2 - Otherwise independent

### Within Each User Story

- View templates before controller helpers
- Controller logic shared across export stories
- Core implementation before polish

### Parallel Opportunities

Within each story, tasks marked [P] can run in parallel:
- Phase 2: T005, T006, T007 (Stimulus controller verification)

---

## Parallel Example: Setup Phase

```bash
# All verification tasks can run in parallel:
Task: "Verify form_controller.js exists in app/frontend/javascript/controllers/"
Task: "Verify search_controller.js exists in app/frontend/javascript/controllers/"
Task: "Register form and search controllers in app/frontend/entrypoints/application.js"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

1. Complete Phase 1: Setup (gem)
2. Complete Phase 2: Foundational (routes, controller, Stimulus)
3. Complete Phase 3: User Story 1 (view table)
4. Complete Phase 4: User Story 2 (filters)
5. **STOP and VALIDATE**: Table displays, filters work
6. Deploy/demo if ready - this is a usable price list!

### Incremental Delivery

1. Setup + Foundational → Framework ready
2. Add US1 + US2 → MVP: viewable, filterable price list
3. Add US3 → Enhancement: rapid ordering from table
4. Add US4 → Enhancement: Excel export for procurement
5. Add US5 → Enhancement: PDF for printing/sharing

---

## Task Summary

| Phase | Story | Task Count | Description |
|-------|-------|------------|-------------|
| 1 | Setup | 2 | Gem installation |
| 2 | Foundational | 5 | Routes, controller, Stimulus |
| 3 | US1 (View) | 6 | Table layout, navigation |
| 4 | US2 (Filter) | 11 | Filter UI and logic |
| 5 | US3 (Cart) | 4 | Add to cart from table |
| 6 | US4 (Excel) | 5 | Excel export |
| 7 | US5 (PDF) | 7 | PDF export |
| 8 | Polish | 4 | Testing, cleanup |
| **Total** | | **44** | |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Exports share `filtered_variants` query from controller - implement once, reuse
