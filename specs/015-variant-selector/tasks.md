# Tasks: Unified Variant Selector

**Input**: Design documents from `/specs/015-variant-selector/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Database migration and model foundation for all user stories

- [ ] T001 Create migration for `pricing_tiers` JSONB column in `db/migrate/YYYYMMDDHHMMSS_add_pricing_tiers_to_product_variants.rb`
- [ ] T002 Run `rails db:migrate` and verify schema.rb updated
- [ ] T003 [P] Update `test/fixtures/product_variants.yml` with pricing_tiers fixture data (per data-model.md)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core model methods and validations that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests (TDD - Write First, Ensure Fail)

- [ ] T004 [P] Write model test for `pricing_tiers` validation in `test/models/product_variant_test.rb`:
  - Test valid pricing tiers array passes
  - Test invalid structure fails (not array, missing quantity, invalid price)
  - Test duplicate quantities rejected
  - Test unsorted quantities rejected
  - Test nil/blank allowed (optional field)

- [ ] T005 [P] Write model test for `Product#extract_options_from_variants` in `test/models/product_test.rb`:
  - Test returns only options with multiple values
  - Test sorts by priority order (material → type → size → colour)
  - Test transforms values to arrays

- [ ] T006 [P] Write model test for `Product#variants_for_selector` in `test/models/product_test.rb`:
  - Test returns correct shape with id, sku, price, pac_size, option_values, pricing_tiers, image_url
  - Test only includes active variants

### Implementation

- [ ] T007 Add `pricing_tiers` validation to `app/models/product_variant.rb` (per data-model.md)
- [ ] T008 Add `extract_options_from_variants` method to `app/models/product.rb`
- [ ] T009 Add `variants_for_selector` method to `app/models/product.rb`
- [ ] T010 [P] Create `app/helpers/variant_selector_helper.rb` with `natural_sort_sizes` helper
- [ ] T011 [P] Write helper test for natural sort in `test/helpers/variant_selector_helper_test.rb`

**Checkpoint**: Foundation ready - all model methods tested and working

---

## Phase 3: User Story 1 - Select Product Variant with Multiple Options (Priority: P1) 🎯 MVP

**Goal**: Customers can select product variants using guided accordion steps with auto-collapse and filtering

**Independent Test**: Visit any multi-option product, select options through steps, verify filtering and add to cart

### Tests for User Story 1 (TDD - Write First, Ensure Fail)

- [ ] T012 [US1] Write controller test for `ProductsController#show` in `test/controllers/products_controller_test.rb`:
  - Test sets @options and @variants_json for standard products
  - Test renders variant_selector partial

- [ ] T013 [US1] Write system test for multi-option selection flow in `test/system/variant_selector_test.rb`:
  - Test first step expanded on page load
  - Test selecting option collapses step with checkmark and selection text
  - Test next step auto-expands after selection
  - Test unavailable options appear disabled
  - Test add to cart button disabled until all selections complete

### Implementation for User Story 1

- [ ] T014 [US1] Update `app/controllers/products_controller.rb#show` to set @options and @variants_json
- [ ] T015 [US1] Create `app/views/products/_variant_selector.html.erb` partial (per quickstart.md)
- [ ] T016 [US1] Create `app/frontend/javascript/controllers/variant_selector_controller.js` with:
  - `static targets` for DOM elements
  - `static values` for variants, options, priority
  - `connect()` to initialize selections and load from URL params
  - `selectOption()` to handle option button clicks
  - `updateOptionButtons()` to enable/disable based on valid combinations
  - `updateStepHeaders()` to show selections in collapsed headers
  - `collapseStepAndExpandNext()` for accordion behaviour
  - `updateUrl()` for URL parameter sync
  - `emitVariantChanged()` for compatible lids integration

- [ ] T017 [US1] Register controller in `app/frontend/entrypoints/application.js` lazyControllers
- [ ] T018 [US1] Update `app/views/products/show.html.erb` to render `_variant_selector` partial
- [ ] T019 [US1] Add natural sort for size values in Stimulus controller (per research.md Decision 3)
- [ ] T020 [US1] Implement option filtering logic to disable unavailable combinations

**Checkpoint**: Multi-option product selection fully functional - can select options, see filtering, add to cart

---

## Phase 4: User Story 2 - Select Quantity with Volume Discount Tiers (Priority: P2)

**Goal**: Customers see tier cards with pricing breakdowns when selecting quantity for tiered products

**Independent Test**: Visit a product with pricing_tiers configured, select variant, verify tier cards display

### Tests for User Story 2 (TDD - Write First, Ensure Fail)

- [ ] T021 [US2] Write system test for tier card display in `test/system/variant_selector_test.rb`:
  - Test tier cards appear when variant has pricing_tiers
  - Test tier card shows pack quantity, pack price, total, unit count, unit price, savings %
  - Test selecting tier highlights card
  - Test add to cart button shows correct total

- [ ] T022 [US2] Write system test for quantity dropdown fallback in `test/system/variant_selector_test.rb`:
  - Test dropdown appears when variant has no pricing_tiers
  - Test dropdown shows pack options with standard price

### Implementation for User Story 2

- [ ] T023 [US2] Add `updateQuantityStep()` method to variant_selector_controller.js:
  - Check if selected variant has pricing_tiers
  - If yes: render tier cards with selectTier() action
  - If no: render quantity dropdown

- [ ] T024 [US2] Add `renderTierCards()` method to generate tier card HTML:
  - Pack quantity badge
  - Pack price (per pack)
  - Total price (pack_price × quantity)
  - Unit breakdown (pac_size × quantity units)
  - Unit price (price / pac_size)
  - Savings percentage vs base tier

- [ ] T025 [US2] Add `renderQuantityDropdown()` method for non-tiered variants
- [ ] T026 [US2] Add `selectTier()` action to handle tier card clicks
- [ ] T027 [US2] Update add to cart button total display when tier/quantity changes

**Checkpoint**: Pricing tiers display correctly, dropdown fallback works, quantities submit to cart

---

## Phase 5: User Story 3 - Purchase Single-Option Product (Priority: P3)

**Goal**: Simple products (single option or quantity-only) show streamlined UI without unnecessary steps

**Independent Test**: Visit Pizza Boxes (single size option), verify only Size + Quantity steps shown

### Tests for User Story 3 (TDD - Write First, Ensure Fail)

- [ ] T028 [US3] Write system test for single-option products in `test/system/variant_selector_test.rb`:
  - Test only one option step shown (e.g., just Size)
  - Test Quantity step appears after single option step
  - Test no empty/unnecessary steps

- [ ] T029 [US3] Write system test for quantity-only products in `test/system/variant_selector_test.rb`:
  - Test only Quantity step shown when product has no variant options
  - Test variant auto-selected (single variant)

### Implementation for User Story 3

- [ ] T030 [US3] Verify `extract_options_from_variants` filters single-value options correctly
- [ ] T031 [US3] Update partial to conditionally render option steps only for multi-value options
- [ ] T032 [US3] Add auto-select logic when only one variant matches selections

**Checkpoint**: Simple products show appropriate UI - no unnecessary steps

---

## Phase 6: User Story 4 - Revise Previous Selection (Priority: P4)

**Goal**: Customers can click collapsed steps to revise selections, with downstream clearing when needed

**Independent Test**: Select options, click collapsed step header, change selection, verify downstream clears

### Tests for User Story 4 (TDD - Write First, Ensure Fail)

- [ ] T033 [US4] Write system test for step re-expansion in `test/system/variant_selector_test.rb`:
  - Test clicking collapsed step header expands it
  - Test other steps remain in their state

- [ ] T034 [US4] Write system test for downstream clearing in `test/system/variant_selector_test.rb`:
  - Test changing earlier selection clears invalid downstream selections
  - Test valid downstream selections are preserved

### Implementation for User Story 4

- [ ] T035 [US4] Add `clearDownstreamSelections()` method to variant_selector_controller.js
- [ ] T036 [US4] Implement validation of downstream selections against new option constraints
- [ ] T037 [US4] Update step headers after clearing to reflect removed selections

**Checkpoint**: Selection revision works correctly - can change earlier choices without full restart

---

## Phase 7: Polish & Cleanup

**Purpose**: Remove legacy code, verify migration complete, cross-cutting improvements

### Legacy Code Removal (AFTER all user stories verified)

- [ ] T038 [P] Remove `app/frontend/javascript/controllers/product_options_controller.js`
- [ ] T039 [P] Remove `app/frontend/javascript/controllers/product_configurator_controller.js`
- [ ] T040 [P] Remove `app/views/products/_standard_product.html.erb`
- [ ] T041 [P] Remove `app/views/products/_consolidated_product.html.erb`
- [ ] T042 [P] Remove `app/views/products/_configurator.html.erb`
- [ ] T043 Update lazyControllers in application.js to remove old controller registrations

### Data Migration Cleanup (Phase 3 of migration strategy)

- [ ] T044 Create rake task `lib/tasks/product_options.rake` with `verify_migration` task
- [ ] T045 Run verification and document any issues
- [ ] T046 Create migration to remove ProductOption tables (after verification passes):
  - `product_options`
  - `product_option_values`
  - `product_option_assignments`

- [ ] T047 [P] Remove `app/models/product_option.rb`
- [ ] T048 [P] Remove `app/models/product_option_value.rb`
- [ ] T049 [P] Remove `app/models/product_option_assignment.rb`

### Final Verification

- [ ] T050 Run full test suite: `rails test`
- [ ] T051 Run system tests: `rails test:system`
- [ ] T052 Verify quickstart.md steps work end-to-end
- [ ] T053 Manual testing on all product types (multi-option, single-option, quantity-only)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational completion
  - US1 (P1) can proceed independently after Foundation
  - US2 (P2) builds on US1 Stimulus controller
  - US3 (P3) can proceed in parallel with US2 after US1
  - US4 (P4) builds on US1 Stimulus controller
- **Polish (Phase 7)**: Depends on all user stories being complete and verified

### Within Each User Story

- Tests MUST be written and FAIL before implementation (TDD per constitution)
- Model methods before controller
- Controller before view partial
- View partial before Stimulus controller
- Stimulus controller registration after controller code

### Parallel Opportunities

```bash
# Phase 2 - Foundational tests in parallel:
T004: pricing_tiers validation test
T005: extract_options_from_variants test
T006: variants_for_selector test

# Phase 7 - Legacy removal in parallel:
T038-T042: Remove old controllers and partials
T047-T049: Remove old models
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (migration + fixtures)
2. Complete Phase 2: Foundational (model methods)
3. Complete Phase 3: User Story 1 (multi-option selection)
4. **STOP and VALIDATE**: Test on representative products
5. Deploy if ready - customers get unified selector

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 → Test → Deploy (MVP! Basic selection works)
3. Add US2 → Test → Deploy (Pricing tiers visible)
4. Add US3 → Test → Deploy (Simple products optimized)
5. Add US4 → Test → Deploy (Full revision capability)
6. Polish → Cleanup legacy code

### Key Risk: Legacy Code Removal

- Do NOT remove old controllers/views until ALL user stories verified
- Keep old code in place during incremental delivery
- Phase 7 is the final cleanup after full validation

---

## Notes

- Constitution requires fixtures (not `Model.create!`) - T003 critical
- Constitution requires TDD - all test tasks (T004-T006, T012-T013, etc.) must FAIL before implementation
- Pricing tiers are OPTIONAL per variant - fallback to dropdown is required (US2)
- Natural sort handles: "8oz" < "12oz" < "16oz", "6x140mm" < "8x200mm" (research.md Decision 3)
- Event `variant-selector:variant-changed` needed for compatible lids integration
