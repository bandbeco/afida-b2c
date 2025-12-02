# Tasks: Variant-Level Sample Request System

**Input**: Design documents from `/specs/011-variant-samples/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅

**Tests**: TDD is mandated by project constitution. Tests are written FIRST for each story.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1-US6)
- File paths are relative to repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Database migration and route configuration

- [x] T001 [P] Create migration `db/migrate/*_add_sample_fields_to_product_variants.rb` adding `sample_eligible:boolean` (default: false, null: false) and `sample_sku:string` columns with index on `sample_eligible`
- [x] T002 [P] Add sample routes to `config/routes.rb`: `resources :samples, only: [:index]` with `collection { get ":category_slug", action: :category, as: :category }`
- [x] T003 Run migration and verify schema in `db/schema.rb`

**Checkpoint**: Database schema ready, routes defined

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core model methods that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundational Phase

> **Write these tests FIRST, ensure they FAIL before implementation**

- [x] T004 [P] Add test for `ProductVariant.sample_eligible` scope in `test/models/product_variant_test.rb` - returns only variants with `sample_eligible: true`
- [x] T005 [P] Add test for `ProductVariant#effective_sample_sku` in `test/models/product_variant_test.rb` - returns `sample_sku` if present, else `"SAMPLE-#{sku}"`
- [x] T006 [P] Add tests for Cart sample methods in `test/models/cart_test.rb`:
  - `#sample_items` returns cart items for sample-eligible variants
  - `#sample_count` returns count of sample items
  - `#only_samples?` returns true when cart has items but none with price > 0
  - `#at_sample_limit?` returns true when sample_count >= 5
- [x] T007 [P] Add tests for Order sample methods in `test/models/order_test.rb`:
  - `Order.with_samples` scope returns orders containing sample items
  - `#contains_samples?` returns true if any order items are samples
  - `#sample_request?` returns true if samples-only order

### Implementation for Foundational Phase

- [x] T008 [P] Add `scope :sample_eligible, -> { where(sample_eligible: true) }` to `app/models/product_variant.rb`
- [x] T009 [P] Add `effective_sample_sku` method to `app/models/product_variant.rb`: `sample_sku.presence || "SAMPLE-#{sku}"`
- [x] T010 Add sample methods to `app/models/cart.rb`:
  - `SAMPLE_LIMIT = 5` constant
  - `sample_items` - joins cart_items to product_variants, filters sample_eligible
  - `sample_count` - count of sample_items
  - `only_samples?` - cart_items.any? && cart_items.where("price > 0").none?
  - `at_sample_limit?` - sample_count >= SAMPLE_LIMIT
- [x] T011 Add sample methods to `app/models/order.rb`:
  - `scope :with_samples` - joins order_items to sample-eligible product_variants
  - `contains_samples?` - order_items.joins(:product_variant).exists?(product_variants: { sample_eligible: true })
  - `sample_request?` - contains_samples? && order_items.where("price > 0").none?
- [x] T012 Run all model tests: `rails test test/models/product_variant_test.rb test/models/cart_test.rb test/models/order_test.rb`

**Checkpoint**: Foundation ready - all model methods work, tests pass

---

## Phase 3: User Story 1 - Browse and Select Samples (Priority: P1) 🎯 MVP

**Goal**: Visitors can browse sample-eligible variants by category and add them to cart

**Independent Test**: Visit `/samples`, expand a category, click "Add Sample" on a variant card

### Tests for User Story 1

> **Write these tests FIRST, ensure they FAIL before implementation**

- [x] T013 [P] [US1] Create `test/controllers/samples_controller_test.rb` with tests:
  - `GET /samples` returns success and shows categories with sample-eligible variants
  - `GET /samples/:category_slug` returns Turbo Frame with variants for category
  - Categories without sample-eligible variants are not shown
- [x] T014 [P] [US1] Create `test/system/sample_request_flow_test.rb` with tests:
  - Visit `/samples` and see category cards
  - Click category to expand and see variant cards
  - Add sample to cart via Turbo Stream
  - Variant card updates to show "Added" state

### Implementation for User Story 1

- [x] T015 [US1] Create `app/controllers/samples_controller.rb` with:
  - `index` action: load categories with sample-eligible variants
  - `category` action: load variants for a category, respond to Turbo Frame
- [x] T016 [P] [US1] Create `app/views/samples/index.html.erb` - main page with category grid, meta tags, sample_counter partial
- [x] T017 [P] [US1] Create `app/views/samples/_category_card.html.erb` - clickable card with category image, name, sample count, chevron, Turbo Frame target
- [x] T018 [US1] Create `app/views/samples/_category_variants.html.erb` - Turbo Frame response with variant grid
- [x] T019 [US1] Create `app/views/samples/_variant_card.html.erb` - product image, name, size, "Add Sample" button with Turbo Frame wrapper
- [x] T020 [US1] Create `app/views/samples/_sample_counter.html.erb` - sticky counter showing "X of 5 samples selected"
- [x] T021 [P] [US1] Create `app/frontend/javascript/controllers/category_expand_controller.js` - toggle category expansion, load Turbo Frame, rotate chevron
- [x] T022 [P] [US1] Create `app/frontend/javascript/controllers/sample_counter_controller.js` - show/hide counter based on sample count
- [x] T023 [US1] Modify `app/controllers/cart_items_controller.rb` to handle `sample: true` param:
  - New `create_sample_cart_item` method
  - Validate sample_eligible?, not at_sample_limit?, not already in cart
  - Create cart item with price: 0, quantity: 1
  - Respond with Turbo Streams: replace variant card, cart counter, sample counter
- [x] T024 [US1] Run controller and system tests: `rails test test/controllers/samples_controller_test.rb test/system/sample_request_flow_test.rb`

**Checkpoint**: US1 complete - visitors can browse and add samples to cart

---

## Phase 4: User Story 2 - Sample Limit Enforcement (Priority: P1) 🎯 MVP

**Goal**: Visitors are limited to 5 samples per cart

**Independent Test**: Add 5 samples, verify 6th is blocked with "Limit Reached"

### Tests for User Story 2

> **Write these tests FIRST, ensure they FAIL before implementation**

- [x] T025 [P] [US2] Add tests to `test/controllers/cart_items_controller_test.rb`:
  - Adding 5th sample succeeds
  - Adding 6th sample fails with redirect and notice
  - Removing sample recalculates limit (can add new sample)
  - Adding duplicate sample fails with notice
- [x] T026 [P] [US2] Add system tests to `test/system/sample_request_flow_test.rb`:
  - Counter shows "5 of 5" when at limit
  - "Add Sample" buttons become disabled "Limit Reached" at limit
  - Remove sample and add a different one

### Implementation for User Story 2

- [x] T027 [US2] Update `app/views/samples/_variant_card.html.erb` to show three states:
  - Default: "Add Sample" button
  - In cart: "Added" with checkmark, remove button
  - At limit (not in cart): "Limit Reached" disabled button
- [x] T028 [US2] Update `app/views/samples/_sample_counter.html.erb` to show "X of 5 samples" with visual feedback at limit
- [x] T029 [US2] Update `app/controllers/cart_items_controller.rb#destroy` to return Turbo Streams that update sample counter and variant cards
- [x] T030 [US2] Run tests: `rails test test/controllers/cart_items_controller_test.rb test/system/sample_request_flow_test.rb`

**Checkpoint**: US2 complete - sample limit enforced, counter works

---

## Phase 5: User Story 3 - Samples-Only Checkout (Priority: P1) 🎯 MVP

**Goal**: Carts with only samples checkout with £7.50 flat shipping

**Independent Test**: Add only samples, proceed to checkout, verify £7.50 shipping option

### Tests for User Story 3

> **Write these tests FIRST, ensure they FAIL before implementation**

- [x] T031 [P] [US3] Add tests to `test/controllers/checkouts_controller_test.rb`:
  - Samples-only cart gets `Sample Delivery` shipping option at £7.50
  - Sample items have unit_amount: 0 in Stripe line items
  - Order created with sample items after checkout success
- [x] T032 [P] [US3] Add system test to `test/system/sample_request_flow_test.rb`:
  - Complete checkout with samples only, verify £7.50 shipping

### Implementation for User Story 3

- [x] T033 [US3] Add `sample_only_shipping_option` method to `config/initializers/shipping.rb`:
  ```ruby
  def self.sample_only_shipping_option
    {
      shipping_rate_data: {
        type: "fixed_amount",
        fixed_amount: { amount: 750, currency: "gbp" },
        display_name: "Sample Delivery",
        delivery_estimate: {
          minimum: { unit: "business_day", value: 3 },
          maximum: { unit: "business_day", value: 5 }
        }
      }
    }
  end
  ```
- [x] T034 [US3] Modify `app/controllers/checkouts_controller.rb#create` to use conditional shipping:
  - If `Current.cart.only_samples?`, use `[Shipping.sample_only_shipping_option]`
  - Otherwise use `Shipping.stripe_shipping_options`
- [x] T035 [US3] Run tests: `rails test test/controllers/checkouts_controller_test.rb test/system/sample_request_flow_test.rb`

**Checkpoint**: US3 complete - samples-only checkout works with £7.50 shipping

---

## Phase 6: User Story 4 - Mixed Cart (Priority: P2)

**Goal**: Mixed carts (samples + paid products) use standard shipping, samples are free

**Independent Test**: Add samples and paid products, checkout with standard shipping options

### Tests for User Story 4

> **Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T036 [P] [US4] Add tests to `test/controllers/checkouts_controller_test.rb`:
  - Mixed cart gets standard shipping options (not Sample Delivery)
  - Sample items have unit_amount: 0, paid items have their price
- [ ] T037 [P] [US4] Add system test to `test/system/sample_request_flow_test.rb`:
  - Add samples + paid product, verify standard shipping options

### Implementation for User Story 4

- [ ] T038 [US4] Verify `app/controllers/checkouts_controller.rb` handles mixed carts correctly (should already work with conditional logic from US3)
- [ ] T039 [US4] Run tests: `rails test test/controllers/checkouts_controller_test.rb test/system/sample_request_flow_test.rb`

**Checkpoint**: US4 complete - mixed carts work with standard shipping

---

## Phase 7: User Story 5 - Admin Sample Management (Priority: P2)

**Goal**: Admins can mark variants as sample-eligible and see sample badges on orders

**Independent Test**: Edit variant in admin, toggle sample eligibility, verify it appears/disappears from `/samples`

### Tests for User Story 5

> **Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T040 [P] [US5] Add tests to `test/controllers/admin/product_variants_controller_test.rb`:
  - Sample eligibility fields are present in edit form
  - Updating sample_eligible and sample_sku works
- [ ] T041 [P] [US5] Add tests to `test/controllers/admin/orders_controller_test.rb`:
  - Index shows sample badges ("Samples Only", "Contains Samples")
  - Filter by sample status works
  - Show page displays sample indicators on items

### Implementation for User Story 5

- [ ] T042 [P] [US5] Add sample eligibility fields to `app/views/admin/product_variants/_form.html.erb`:
  - Checkbox for "Available as free sample"
  - Text field for "Sample SKU (optional)"
- [ ] T043 [US5] Update `app/controllers/admin/product_variants_controller.rb` to permit `sample_eligible` and `sample_sku` params
- [ ] T044 [P] [US5] Add sample badge to `app/views/admin/orders/index.html.erb`:
  - "Samples Only" badge for `order.sample_request?`
  - "Contains Samples" badge for `order.contains_samples?` (but not sample_request?)
- [ ] T045 [P] [US5] Add sample filter to `app/views/admin/orders/index.html.erb` - dropdown to filter by sample status
- [ ] T046 [US5] Update `app/controllers/admin/orders_controller.rb#index` to handle sample filter param
- [ ] T047 [US5] Add sample indicators to `app/views/admin/orders/show.html.erb`:
  - "(Sample)" label next to sample items
  - Show effective_sample_sku for sample items
- [ ] T048 [US5] Run admin tests: `rails test test/controllers/admin/`

**Checkpoint**: US5 complete - admin can manage sample eligibility and see sample orders

---

## Phase 8: User Story 6 - Cart Display for Samples (Priority: P3)

**Goal**: Samples display distinctively in cart with "Free (Sample)" label

**Independent Test**: Add samples to cart, view cart page, verify "Free (Sample)" display

### Tests for User Story 6

> **Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T049 [P] [US6] Add tests to `test/views/cart_items_test.rb` (or appropriate view test):
  - Sample items show "Free" instead of "£0.00"
  - Sample items show "(Sample)" label
  - Quantity controls are hidden for sample items

### Implementation for User Story 6

- [ ] T050 [US6] Update `app/views/cart_items/_cart_item.html.erb`:
  - If sample item (price == 0 && variant.sample_eligible?), show "Free" with "(Sample)" badge
  - Hide quantity increment/decrement for sample items
  - Show remove button for samples
- [ ] T051 [US6] Add CSS styling for sample items in cart (subtle visual distinction)
- [ ] T052 [US6] Run view tests: `rails test test/views/`

**Checkpoint**: US6 complete - samples display clearly in cart

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup

- [ ] T053 Run full test suite: `rails test && rails test:system`
- [ ] T054 Run RuboCop: `rubocop --autocorrect`
- [ ] T055 Run Brakeman: `brakeman`
- [ ] T056 Run quickstart.md verification checklist manually
- [ ] T057 Test all edge cases from spec.md:
  - Duplicate sample prevention
  - Deactivated variant in cart
  - Remove sample then add different one
  - Cart transitions from samples-only to mixed
  - Multi-variant products with partial sample eligibility

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies - start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1 - BLOCKS all user stories
- **Phases 3-8 (User Stories)**: All depend on Phase 2 completion
  - P1 stories (US1, US2, US3) should be done first
  - P2 stories (US4, US5) can follow
  - P3 story (US6) can be last
- **Phase 9 (Polish)**: Depends on all user stories

### User Story Dependencies

| Story | Depends On | Can Parallel With |
|-------|------------|-------------------|
| US1 (P1) | Phase 2 | None initially |
| US2 (P1) | US1 (shares variant cards) | - |
| US3 (P1) | US1 (needs samples in cart) | - |
| US4 (P2) | US3 (extends checkout logic) | - |
| US5 (P2) | Phase 2 only | US1-US4 |
| US6 (P3) | US1 (needs samples in cart) | US4, US5 |

### Parallel Opportunities

- **Within Phase 1**: T001, T002 can run in parallel
- **Within Phase 2**: All test tasks (T004-T007) can run in parallel; model tasks T008-T009 can run in parallel
- **Within US1**: T013-T014 (tests), T016-T017 (views), T021-T022 (Stimulus) can run in parallel
- **US5** can largely be done in parallel with US1-US4 (separate admin area)

---

## MVP Implementation Strategy

### Minimum Viable Product (US1 + US2 + US3)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T012)
3. Complete Phase 3: US1 - Browse & Select (T013-T024)
4. Complete Phase 4: US2 - Limit Enforcement (T025-T030)
5. Complete Phase 5: US3 - Samples Checkout (T031-T035)
6. **STOP**: MVP is deployable and testable

### Full Feature (Add US4, US5, US6)

7. Complete Phase 6: US4 - Mixed Cart (T036-T039)
8. Complete Phase 7: US5 - Admin Management (T040-T048)
9. Complete Phase 8: US6 - Cart Display (T049-T052)
10. Complete Phase 9: Polish (T053-T057)

---

## Notes

- TDD is mandated: write tests first, verify they fail, then implement
- [P] tasks operate on different files with no dependencies
- [Story] label maps task to user story for traceability
- Commit after each task or logical group
- Verify tests pass before moving to next task
- Constitution checks passed in plan.md - maintain compliance
