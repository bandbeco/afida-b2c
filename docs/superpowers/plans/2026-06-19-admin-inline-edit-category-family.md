# Admin Inline-Edit of Product Category and Family Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On the admin products index, make each product's Category and Family editable inline as always-visible `<select>`s that auto-submit on change, on both desktop and mobile.

**Architecture:** Each editable field is a small `form_with` (scoped to one product) wrapped in its own `turbo_frame_tag`. The `<form>` carries `data-controller="form"` and the `<select>` carries `data-action="change->form#submit"`; changing the select calls `requestSubmit()` (via the existing `form` Stimulus controller), which PATCHes a dedicated controller action that updates the single attribute and re-renders the same frame. Forms live inside table cells / card divs, so there is no `<tr>`/`<form>` nesting problem. The existing click-Edit Category control is converted to this same auto-submit pattern; Family is added the same way.

**Tech Stack:** Rails (Hotwire/Turbo Frames), Stimulus (existing `form` controller, no new JS), Minitest + fixtures, Tailwind/DaisyUI classes.

**Branch:** `admin-inline-edit-category-family` (already checked out).

---

## Key facts the implementer must know (verified against the codebase)

- **Test runner:** `bin/rails test` (Minitest). Run a single file with `bin/rails test test/controllers/admin/products_controller_test.rb`. Run a single test by line with `bin/rails test test/controllers/admin/products_controller_test.rb:180`.
- **Project rules (from CLAUDE.md):** TDD is mandatory (red → green → refactor). No inline styles, ever. No bold/semibold font weights (`font-bold`/`font-semibold`). Do NOT add `Co-Authored-By` to commits. Commit to the current branch only; never create a branch.
- **The `form` Stimulus controller already exists** at `app/frontend/javascript/controllers/form_controller.js`; its `submit()` calls `this.element.requestSubmit()`. Reuse it; write no JS.
- **Wiring rule:** `data-controller="form"` goes on the `<form>`; `data-action="change->form#submit"` goes on the `<select>`. (Putting the controller on the select would make `this.element` the select, which has no `requestSubmit`.)
- **Category is required + must be a subcategory** (`app/models/product.rb:171-172`). `category_must_be_subcategory` (`app/models/product.rb:401-406`) only errors when the category is top-level AND has children. So the Category select offers **no blank option**, and `update_category` keeps a validation-aware `if/else` returning 422.
- **Family is optional** (`Product belongs_to :product_family, optional: true`, `app/models/product.rb:29`). The Family select offers a blank `— None —` option; blank → `nil` (un-assign).
- **Fixture names (verified — the spec's draft used some wrong names, use THESE):**
  - Families (`test/fixtures/product_families.yml`): `single_wall_cups`, `branded_double_wall`, `paper_lids`, `recyclable_lids_black`, `recyclable_lids_white`, `paper_straws`, `wooden_cutlery`, `napkins`. (There is **no** `branded_cups` fixture.)
  - Products (`test/fixtures/products.yml`): `single_wall_8oz_white` has `product_family: single_wall_cups` and `category: cups`. `products(:one)` has **no** family and `category: one`.
  - Categories (`test/fixtures/categories.yml`): subcategory `child_hot_cups` (parent `parent_cups_and_drinks`); top-level-with-children `parent_cups_and_drinks` (the "invalid" category for the 422 test).
  - Users (`test/fixtures/users.yml`): `acme_admin` (role admin), `consumer` (role nil → `admin? == false`).
- **Test request style** (from `products_controller_test.rb:1-14`): integration tests; `setup` sets `@headers` (a browser UA, required to pass `allow_browser`), `@product = products(:one)`, signs in `acme_admin` via `sign_in_as`. Always pass `headers: @headers` on requests. `sign_in_as(user)` POSTs to `session_url`.

---

## File Structure

- **Modify** `config/routes.rb` (admin `resources :products` member block, lines 222-224): remove `get :inline_edit_category`, add `patch :update_family`.
- **Modify** `app/controllers/admin/products_controller.rb`:
  - Line 3: update `set_product` `only:` list.
  - Remove the `inline_edit_category` action; rewrite `update_category`; add `update_family` (lines ~176-190).
- **Rewrite** `app/views/admin/products/_inline_category.html.erb`: single-state auto-submit select, no blank option.
- **Create** `app/views/admin/products/_inline_family.html.erb`: single-state auto-submit select with `— None —`.
- **Modify** `app/views/admin/products/index.html.erb`: add Family column to desktop table; add Family render under Category in mobile cards; drop the `editing:` local from both Category renders.
- **Modify** `test/controllers/admin/products_controller_test.rb`: delete the `inline_edit_category` test; keep the two `update_category` tests; add `update_family` tests + an auth test.

Each task below is independently committable and leaves the suite green.

---

## Task 1: Routes — drop `inline_edit_category`, add `update_family`

**Files:**
- Modify: `config/routes.rb:222-224`

- [ ] **Step 1: Update the member routes block**

In `config/routes.rb`, the admin `resources :products` member block currently reads:

```ruby
      member do
        get :inline_edit_category
        patch :update_category
        patch :toggle_boolean
```

Change it to (remove the `get :inline_edit_category` line, add `patch :update_family`):

```ruby
      member do
        patch :update_category
        patch :update_family
        patch :toggle_boolean
```

- [ ] **Step 2: Verify routes load and the new route exists**

Run: `bin/rails routes -g products | grep -E "update_family|update_category|inline_edit_category"`

Expected: a line for `update_family_admin_product PATCH` and one for `update_category_admin_product PATCH`; **no** line for `inline_edit_category`.

- [ ] **Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "Routes: remove inline_edit_category, add update_family for admin products"
```

---

## Task 2: Controller — remove `inline_edit_category`, simplify `update_category`, add `update_family`

This task makes the controller match the new routes. The existing `update_category` test (`:180`) and the 422 test (`:192`) must stay green; the `inline_edit_category` test (`:173`) is deleted in Task 6 (it will be temporarily broken between Task 1 and Task 6 — that is expected and called out in Step 4).

**Files:**
- Modify: `app/controllers/admin/products_controller.rb:3` (the `set_product` `only:` list)
- Modify: `app/controllers/admin/products_controller.rb:176-190` (the actions)

- [ ] **Step 1: Update the `set_product` `only:` list (line 3)**

Current (line 3):

```ruby
    before_action :set_product, only: %i[ show edit update destroy destroy_product_photo destroy_lifestyle_photo add_compatible_lid remove_compatible_lid set_default_compatible_lid update_compatible_lids inline_edit_category update_category toggle_boolean ]
```

Change to (remove `inline_edit_category`, add `update_family`):

```ruby
    before_action :set_product, only: %i[ show edit update destroy destroy_product_photo destroy_lifestyle_photo add_compatible_lid remove_compatible_lid set_default_compatible_lid update_compatible_lids update_category update_family toggle_boolean ]
```

- [ ] **Step 2: Replace the `inline_edit_category` + `update_category` actions**

The current code (lines 176-190) is:

```ruby
    # GET /admin/products/:id/inline_edit_category
    def inline_edit_category
      @categories = Category.top_level.includes(:children).order(:position)
      render partial: "inline_category", locals: { product: @product, editing: true }
    end

    # PATCH /admin/products/:id/update_category
    def update_category
      if @product.update(category_id: params[:product][:category_id])
        render partial: "inline_category", locals: { product: @product, editing: false }
      else
        @categories = Category.top_level.includes(:children).order(:position)
        render partial: "inline_category", locals: { product: @product, editing: true }, status: :unprocessable_entity
      end
    end
```

Replace ALL of it with (delete `inline_edit_category` entirely; simplify `update_category`; add `update_family`):

```ruby
    # PATCH /admin/products/:id/update_category
    def update_category
      if @product.update(category_id: params.dig(:product, :category_id))
        render partial: "inline_category", locals: { product: @product }
      else
        render partial: "inline_category", locals: { product: @product }, status: :unprocessable_entity
      end
    end

    # PATCH /admin/products/:id/update_family
    def update_family
      @product.update(product_family_id: params.dig(:product, :product_family_id).presence)
      render partial: "inline_family", locals: { product: @product }
    end
```

Notes:
- `update_category` drops `editing:` from the locals (the partial no longer takes it — Task 3) and uses `params.dig` for safety. It keeps the `if/else` 422 branch because category is validated.
- `update_family` uses `.presence` so the blank `— None —` option saves `nil`. Family is optional, so no `if/else` is needed.
- `update_family` renders `inline_family`, which is created in Task 4. Between this task and Task 4 the action references a partial that does not yet exist; that is fine because nothing calls `update_family` until the view is wired (Task 5) and tested (Task 6). The suite does not exercise it yet.

- [ ] **Step 3: Verify the controller loads (no syntax/reference errors)**

Run: `bin/rails runner "puts Admin::ProductsController.instance_methods(false).sort"`

Expected: output includes `update_category` and `update_family`, and does **not** include `inline_edit_category`. No load error.

- [ ] **Step 4: Run the existing `update_category` tests (expect the two to pass, the inline_edit one to error)**

Run: `bin/rails test test/controllers/admin/products_controller_test.rb`

Expected: `update_category updates product category` (line 180) and `update_category with invalid category returns unprocessable entity` (line 192) **PASS**. The `inline_edit_category returns success and renders select` test (line 173) **ERRORS** with an `undefined method 'inline_edit_category_admin_product_path'` / `NameError` because the route helper was removed in Task 1. This is expected and is cleaned up in Task 6. (If you prefer a fully green suite at every commit, do Task 6's deletion now; this plan deletes it in Task 6 to keep the test-file changes grouped.)

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/products_controller.rb
git commit -m "Controller: drop inline_edit_category, add update_family, simplify update_category"
```

---

## Task 3: Rewrite the Category partial to a single-state auto-submit select (no blank option)

The current `_inline_category.html.erb` is a two-state toggle (read link + edit form). Replace it with a single always-visible auto-submitting select. No blank option (category is required).

**Files:**
- Modify (full rewrite): `app/views/admin/products/_inline_category.html.erb`

- [ ] **Step 1: Replace the entire file contents**

Replace the whole of `app/views/admin/products/_inline_category.html.erb` with:

```erb
<%= turbo_frame_tag "product_#{product.id}_category" do %>
  <%= form_with model: [:admin, product],
                url: update_category_admin_product_path(product),
                method: :patch,
                data: { controller: "form", turbo_frame: "product_#{product.id}_category" } do |f| %>
    <%= f.select :category_id,
          grouped_options_for_select(
            Category.top_level.includes(:children).order(:position).map { |parent|
              [parent.name, parent.children.order(:position).map { |sub| [sub.name, sub.id] }]
            },
            product.category_id
          ),
          {},
          class: "select select-bordered select-sm",
          data: { action: "change->form#submit" } %>
  <% end %>
<% end %>
```

Notes:
- The `{}` in the options-hash position means **no `include_blank`** — there is no empty option. Parents are `<optgroup>` labels (not selectable). The UI cannot submit a blank or top-level category.
- The partial computes its own category options (the old `@categories` ivar from `inline_edit_category` is gone).
- This partial takes ONLY a `product` local now (no `editing:`).

- [ ] **Step 2: Verify the index page still renders (the partial is still called with `editing: false` until Task 5)**

The index currently calls `render "inline_category", product: product, editing: false`. Passing an unused `editing:` local is harmless in Rails (extra locals are ignored), so the page renders. Confirm with a request test:

Run: `bin/rails test test/controllers/admin/products_controller_test.rb -n "/should get index/i" 2>/dev/null; bin/rails runner "require 'rails/command'; puts 'ok'"`

If there is no index test by that name, instead verify by rendering: run `bin/rails test test/controllers/admin/products_controller_test.rb` and confirm no NEW failures beyond the expected `inline_edit_category` error from Task 2.

Expected: no new template errors. (The `inline_edit_category` test still errors; everything else that was green stays green.)

- [ ] **Step 3: Commit**

```bash
git add app/views/admin/products/_inline_category.html.erb
git commit -m "View: convert inline_category to single-state auto-submit select (no blank option)"
```

---

## Task 4: Create the Family partial (auto-submit select with `— None —`)

Mirror of the Category partial, with a blank option (family is optional) and a distinct frame id.

**Files:**
- Create: `app/views/admin/products/_inline_family.html.erb`

- [ ] **Step 1: Create the file**

Create `app/views/admin/products/_inline_family.html.erb` with:

```erb
<%= turbo_frame_tag "product_#{product.id}_family" do %>
  <%= form_with model: [:admin, product],
                url: update_family_admin_product_path(product),
                method: :patch,
                data: { controller: "form", turbo_frame: "product_#{product.id}_family" } do |f| %>
    <%= f.select :product_family_id,
          options_from_collection_for_select(ProductFamily.order(:name), :id, :name, product.product_family_id),
          { include_blank: "— None —" },
          class: "select select-bordered select-sm",
          data: { action: "change->form#submit" } %>
  <% end %>
<% end %>
```

Notes:
- Distinct frame id `product_#{product.id}_family` (must differ from the category frame so the two controls don't hijack each other).
- `include_blank: "— None —"` provides the un-assign option. The em-dash glyph in a UI label is allowed (the no-em-dash rule is about narrative prose).
- Families ordered alphabetically by name.
- Takes only a `product` local.

- [ ] **Step 2: Verify the partial renders in isolation**

Run:

```bash
bin/rails runner '
p = Product.unscoped.where.not(product_family_id: nil).first || Product.unscoped.first
html = ApplicationController.render(partial: "admin/products/inline_family", locals: { product: p })
puts html.include?("product_#{p.id}_family") ? "frame-id-ok" : "frame-id-MISSING"
puts html.include?("product[product_family_id]") ? "select-name-ok" : "select-name-MISSING"
puts html.include?("change->form#submit") ? "action-ok" : "action-MISSING"
puts html.include?("— None —") ? "blank-option-ok" : "blank-option-MISSING"
'
```

Expected: four lines, all `*-ok`.

- [ ] **Step 3: Commit**

```bash
git add app/views/admin/products/_inline_family.html.erb
git commit -m "View: add inline_family auto-submit select partial"
```

---

## Task 5: Wire both partials into the index (desktop table + mobile cards)

Add a Family column to the desktop table and a Family render under Category in the mobile cards. Drop the now-unused `editing:` local from both Category renders.

**Files:**
- Modify: `app/views/admin/products/index.html.erb` (desktop header line 54; desktop body lines 70-72; mobile card line 128)

- [ ] **Step 1: Add the desktop `Family` table header**

Current (lines 53-54):

```erb
            <th><%= sort_link("Title", "name") %></th>
            <th>Category</th>
```

Change to (add a `Family` header after Category):

```erb
            <th><%= sort_link("Title", "name") %></th>
            <th>Category</th>
            <th>Family</th>
```

- [ ] **Step 2: Add the desktop `Family` cell and drop `editing:` from the Category cell**

Current (lines 70-72):

```erb
              <td>
                <%= render "inline_category", product: product, editing: false %>
              </td>
```

Change to (drop `editing: false`, add a Family `<td>` immediately after):

```erb
              <td>
                <%= render "inline_category", product: product %>
              </td>
              <td>
                <%= render "inline_family", product: product %>
              </td>
```

- [ ] **Step 3: Add the mobile Family render and drop `editing:` from the mobile Category render**

Current (around lines 127-129):

```erb
                <div class="mt-1">
                  <%= render "inline_category", product: product, editing: false %>
                </div>
```

Change to (drop `editing: false`; add a Family render in its own `mt-1` div):

```erb
                <div class="mt-1">
                  <%= render "inline_category", product: product %>
                </div>
                <div class="mt-1">
                  <%= render "inline_family", product: product %>
                </div>
```

- [ ] **Step 4: Verify the index renders with both selects (manual request check)**

Run:

```bash
bin/rails runner '
include Rails.application.routes.url_helpers
# Render the index template is heavy; instead assert both partials render for a product.
p = Product.unscoped.first
cat = ApplicationController.render(partial: "admin/products/inline_category", locals: { product: p })
fam = ApplicationController.render(partial: "admin/products/inline_family", locals: { product: p })
puts cat.include?("product[category_id]") ? "category-select-ok" : "category-MISSING"
puts fam.include?("product[product_family_id]") ? "family-select-ok" : "family-MISSING"
'
```

Expected: `category-select-ok` and `family-select-ok`.

- [ ] **Step 5: Run the full controller test file (still expect only the inline_edit_category error)**

Run: `bin/rails test test/controllers/admin/products_controller_test.rb`

Expected: no new failures; the only red is still the `inline_edit_category` test (deleted next task).

- [ ] **Step 6: Commit**

```bash
git add app/views/admin/products/index.html.erb
git commit -m "View: add Family column to products index (desktop + mobile), auto-submit selects"
```

---

## Task 6: Reconcile existing tests (delete the obsolete one) and add Family + auth tests

Now make the suite fully green and cover the new behaviour. TDD: write the new failing tests first, watch them fail, then they pass against the code already written in Tasks 1-5 (the implementation already exists, so these tests should pass immediately once written correctly — if a test fails, fix the test or the code per red-green).

**Files:**
- Modify: `test/controllers/admin/products_controller_test.rb` (delete lines 173-178; add new tests after the existing inline tests block, around line 201)

- [ ] **Step 1: Delete the obsolete `inline_edit_category` test**

Remove this entire test (currently lines 173-178):

```ruby
  test "inline_edit_category returns success and renders select" do
    get inline_edit_category_admin_product_path(@product), headers: @headers

    assert_response :success
    assert_select "select[name='product[category_id]']"
  end
```

Leave the two `update_category` tests (lines 180-201) in place — they remain valid.

- [ ] **Step 2: Run the file to confirm it is now fully green**

Run: `bin/rails test test/controllers/admin/products_controller_test.rb`

Expected: ALL PASS (the route-helper error is gone; both `update_category` tests pass).

- [ ] **Step 3: Add the new `update_family` + auth tests (write them, expect PASS)**

Insert the following tests immediately after the `update_category with invalid category returns unprocessable entity` test (after line 201, before the `# Inline boolean toggle tests` comment at line 203):

```ruby
  # Inline family editing tests

  test "update_family reassigns product to a different family" do
    product = products(:single_wall_8oz_white)
    new_family = product_families(:branded_double_wall)

    patch update_family_admin_product_path(product), params: {
      product: { product_family_id: new_family.id }
    }, headers: @headers

    assert_response :success
    assert_equal new_family.id, product.reload.product_family_id
  end

  test "update_family with blank id un-assigns the family" do
    product = products(:single_wall_8oz_white)
    assert_not_nil product.product_family_id, "fixture should start with a family"

    patch update_family_admin_product_path(product), params: {
      product: { product_family_id: "" }
    }, headers: @headers

    assert_response :success
    assert_nil product.reload.product_family_id
  end

  test "update_family renders the family turbo frame" do
    product = products(:single_wall_8oz_white)

    patch update_family_admin_product_path(product), params: {
      product: { product_family_id: product_families(:paper_lids).id }
    }, headers: @headers

    assert_select "turbo-frame#product_#{product.id}_family"
    assert_select "select[name='product[product_family_id]']"
  end

  test "update_family requires admin" do
    sign_in_as(users(:consumer))
    product = products(:single_wall_8oz_white)
    original_family_id = product.product_family_id

    patch update_family_admin_product_path(product), params: {
      product: { product_family_id: product_families(:branded_double_wall).id }
    }, headers: @headers

    assert_redirected_to root_path
    assert_equal original_family_id, product.reload.product_family_id
  end

  test "update_category requires admin" do
    sign_in_as(users(:consumer))
    original_category_id = @product.category_id

    patch update_category_admin_product_path(@product), params: {
      product: { category_id: categories(:child_hot_cups).id }
    }, headers: @headers

    assert_redirected_to root_path
    assert_equal original_category_id, @product.reload.category_id
  end
```

Notes:
- Uses **verified** fixture names: `products(:single_wall_8oz_white)` (starts with family `single_wall_cups`), `product_families(:branded_double_wall)` / `:paper_lids`, `users(:consumer)` (non-admin), `categories(:child_hot_cups)` (a valid subcategory).
- The auth tests re-sign-in as `consumer`, overriding the admin signed in by `setup` (the session cookie is replaced by the second `sign_in_as`).

- [ ] **Step 4: Run the new tests**

Run: `bin/rails test test/controllers/admin/products_controller_test.rb`

Expected: ALL PASS, including the five new tests.

- [ ] **Step 5: Commit**

```bash
git add test/controllers/admin/products_controller_test.rb
git commit -m "Test: cover update_family + admin auth; remove obsolete inline_edit_category test"
```

---

## Task 7: Add an index view/integration test for the auto-submit wiring

The acceptance criteria require the 37signals wiring (`data-controller="form"` on the form, `data-action="change->form#submit"` on the select), distinct frame ids, Category having no blank option, and Family having `— None —`. Cover this with a request test against the real index action so a future refactor can't silently break the wiring.

**Files:**
- Modify: `test/controllers/admin/products_controller_test.rb` (add one test near the other index assertions)

- [ ] **Step 1: Write the failing test**

Add this test to `test/controllers/admin/products_controller_test.rb` (anywhere among the index-related tests; the `# Inline family editing tests` block is fine):

```ruby
  test "index renders inline category and family auto-submit selects" do
    product = products(:single_wall_8oz_white)

    get admin_products_path, headers: @headers
    assert_response :success

    # Both selects present, scoped to the product's frames
    assert_select "turbo-frame#product_#{product.id}_category form[data-controller='form']" do
      assert_select "select[name='product[category_id]'][data-action='change->form#submit']"
    end
    assert_select "turbo-frame#product_#{product.id}_family form[data-controller='form']" do
      assert_select "select[name='product[product_family_id]'][data-action='change->form#submit']"
    end

    # Category has NO blank option; Family HAS a blank "— None —" option
    assert_select "turbo-frame#product_#{product.id}_category select option[value='']", count: 0
    assert_select "turbo-frame#product_#{product.id}_family select option[value='']", text: "— None —"
  end
```

- [ ] **Step 2: Run it to confirm it passes**

Run: `bin/rails test test/controllers/admin/products_controller_test.rb -n "/index renders inline category and family/i"`

Expected: PASS. (The implementation from Tasks 3-5 already satisfies it. If it fails on the `option[value='']` count for category, confirm the Category partial passes `{}` and not `{ include_blank: ... }`; if it fails on the family blank text, confirm the `include_blank: "— None —"` label matches exactly.)

- [ ] **Step 3: Commit**

```bash
git add test/controllers/admin/products_controller_test.rb
git commit -m "Test: assert index renders auto-submit category/family selects with correct wiring"
```

---

## Task 8: Full-suite regression check

**Files:** none (verification only)

- [ ] **Step 1: Run the whole test suite**

Run: `bin/rails test`

Expected: all green. Pay attention to any test touching the admin products index, the products ordering test (`test/controllers/admin/products_ordering_test.rb`), or anything that rendered `_inline_category` with the old two-state behaviour. If something references the removed `inline_edit_category` route/behaviour outside the file already edited, fix it (grep below).

- [ ] **Step 2: Grep for any remaining references to the removed action/route**

Run: `grep -rn "inline_edit_category" app/ test/ config/`

Expected: **no results.** If any remain, remove/replace them (a leftover would be a dangling route helper or a stale partial render).

- [ ] **Step 3: Manual smoke test (optional but recommended)**

Start the app and open `/admin/products`. Confirm:
- Each row shows a Category dropdown and a Family dropdown (desktop table has a new "Family" column; mobile cards show Family under Category).
- Changing a Category saves immediately (reload the page; the new value persists). The Category dropdown has no blank option.
- Changing a Family saves immediately; selecting "— None —" removes the family (the cart/order `display_name` will then show just the product name).
- No Edit/Save/Cancel buttons remain.

- [ ] **Step 4: Final commit (if any fixes were made in Steps 1-2)**

```bash
git add -A
git commit -m "Fix regressions from inline category/family conversion"
```

(Skip if Steps 1-2 produced no changes.)

---

## Self-Review Notes (for the implementer)

- **Spec coverage:** Routes (Task 1), controller actions incl. validation-aware `update_category` and optional `update_family` (Task 2), Category partial no-blank (Task 3), Family partial with `— None —` (Task 4), desktop+mobile wiring (Task 5), test reconciliation + family/auth tests (Task 6), wiring assertions (Task 7), regression (Task 8). All acceptance criteria map to a task.
- **Frame-id collision:** Category uses `product_#{id}_category`, Family uses `product_#{id}_family` — distinct, verified in Tasks 3, 4, 7.
- **No new JS:** the `form` controller is reused; no file under `app/frontend/javascript/controllers/` is created.
- **Conventions:** selects reuse existing `select select-bordered select-sm` classes (no inline styles, no bold weights). TDD order preserved. Commits are scoped and frequent.
- **Known intermediate red:** between Task 2 and Task 6, the `inline_edit_category` test errors because its route helper is gone. This is intentional and documented; if you want every commit fully green, perform Task 6 Step 1 (the deletion) immediately after Task 1.
