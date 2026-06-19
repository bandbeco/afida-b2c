# Admin inline-edit of product Category and Family on the index

**Date:** 2026-06-19
**Status:** Approved (design)

## Problem

Admins cannot reassign a product to a different product **family** from the UI at
all, and the existing **category** inline-edit on the products index uses a
click-Edit → Save → Cancel toggle that we want to simplify. The original ask was
"let admins move a product between families." Through design we widened it
slightly: do both Category and Family inline on the products **index** page, using
a single consistent, idiomatic pattern.

Goal: on the admin products index, let an admin change a product's Category and its
Family inline, with the change saved immediately, on both desktop and mobile.

## Background (current state)

### Data model
- `Product belongs_to :product_family, optional: true` (`app/models/product.rb:29`).
  FK column `products.product_family_id` is nullable; **no presence validation** —
  family is genuinely optional and may be `nil`.
- `Product belongs_to :category` (category inline-edit already exists on the index).
  **Category is required and constrained**: `validates :category, presence: true`
  (`app/models/product.rb:171`) and `validate :category_must_be_subcategory`
  (`:172`). A product must always have a category, and it must be a subcategory
  (not a top-level/parent category). This asymmetry with family drives the design:
  the Category select offers **no blank option**, the Family select does.
- `ProductFamily has_many :products, dependent: :nullify`
  (`app/models/product_family.rb:2`). No counter cache. `ProductFamily` has `name`
  and a generated `slug`; `to_param` returns the slug.
- Changing either association overwrites the FK with no side effects: no slug
  regeneration, no search reindex, no counter updates, no `touch`. No callbacks fire
  on Product or ProductFamily for these changes.
- `:product_family_id` and `:category_id` are both already permitted in
  `product_params` (`app/controllers/admin/products_controller.rb:261-262`).

### Customer-visible effect of a family change
`Product#display_name` (`app/models/product.rb:218-223`) renders as
`"<Family Name> (<Product Name>)"` when a family is present, else just the product
name. It is used in cart messages, order displays, and product cards. So moving a
product between families changes how it is labelled to customers. The change is
reversible and low-stakes. (Decision: no confirmation; silent save.)

### Existing index page and the category precedent
The products index (`app/views/admin/products/index.html.erb`) renders two layouts
inside a `turbo_frame_tag "products"`:
- **Desktop** `<table>` (`.hidden md:block`), lines 49-113. Category is a column
  rendered via `render "inline_category"` at line 71. There is **no Family column**.
- **Mobile** card list (`.md:hidden`), lines 116-168. Category rendered via
  `render "inline_category"` at line 128.

The current category control (`app/views/admin/products/_inline_category.html.erb`)
is a Turbo frame `"product_#{product.id}_category"` with two states: a read link
("Edit") and an edit `form_with` containing a grouped `select` plus Save/Cancel.
Backed by:
- Routes `get :inline_edit_category` and `patch :update_category`
  (`config/routes.rb:223-224`), member routes on `resources :products` in the
  `admin` namespace.
- Controller actions `inline_edit_category` / `update_category`
  (`app/controllers/admin/products_controller.rb:176-190`), which `render partial:`
  the frame's two states.
- `set_product` before_action (`only:` list at
  `app/controllers/admin/products_controller.rb:3`) currently includes
  `inline_edit_category update_category`; loads `@product` via
  `Product.unscoped.find_by!(slug: params.expect(:id))` (`:241-243`).

### Existing reusable auto-submit Stimulus controller (matches 37signals idiom)
`app/frontend/javascript/controllers/form_controller.js` already exists and is an
"auto-submit on change" controller: its `submit()` calls
`this.element.requestSubmit()`. This is the **same controller name and mechanism**
used by the canonical Hotwire apps fizzy and once-campfire (a `form` Stimulus
controller whose `submit()` calls `requestSubmit()`, wired with
`data: { action: "change->form#submit" }`). Stimulus controllers live in
`app/frontend/javascript/controllers/`. **We reuse this controller; no new JS.**

The existing index search box already demonstrates the correct wiring split:
`data: { controller: "debounced-submit ..." }` on the `form_with`, and
`data: { action: "input->debounced-submit#submit" }` on the input
(`app/views/admin/products/index.html.erb:22-28`).

### Authorization
Single `require_admin` before_action in `Admin::ApplicationController` (redirects to
`root_path` unless `Current.user&.admin?`). No per-resource policies.

### Why this design (real-world Rails survey)
Two surveys of production Rails apps in `real-world-rails`:
1. The click-Edit → Save toggle is **not** the common idiom for inline table
   editing. Spree (import mappings, stock items) uses an **always-visible `select`
   that auto-submits on change**, wrapped in a Turbo frame, with the form **inside a
   cell** (never wrapping `<tr>`).
2. fizzy and once-campfire (37signals/DHH, the most canonical Hotwire apps)
   auto-submit via a `form` Stimulus controller calling `requestSubmit()`, with
   `data: { controller: "form" }` on the `<form>` and
   `data: { action: "change->form#submit" }` on the field. **No debounce for a
   discrete `change` on a select** (debounce is reserved for high-frequency `input`
   events on text fields).

This design follows both: always-visible auto-submitting selects, using the
existing `form` controller, wired the 37signals way.

## Decisions (settled during brainstorming)

1. **Edit on the index page**, not the product edit page. (Reassigning is list-level
   curation; the edit page's Category control is a plain in-form select and would
   require nested forms to do immediate-save there.)
2. **Pattern: always-visible selects that auto-submit on change** (Spree / 37signals
   way), each in its own Turbo frame. No Edit/Save/Cancel.
3. **Convert the existing Category control to the same auto-submit pattern**, so
   Category and Family behave identically. The old `inline_edit_category` toggle
   action, its route, and the toggle behaviour in `_inline_category.html.erb` are
   replaced.
4. **Both desktop table and mobile cards** get Category + Family editing (parity
   with today's Category).
5. **Silent save**: on change, PATCH and re-render the select in its frame with the
   new value selected. No toast/flash (no toast component exists; not worth adding).
   The selected value persisting is the confirmation.
6. **Family dropdown: alphabetical + a blank "— None —" option** so a product can be
   un-assigned (valid: FK is optional). Blank persists as `nil`.
7. **Category dropdown: NO blank option** (category is required). Parents render as
   non-selectable `<optgroup>` labels and only subcategories are real options, so the
   UI cannot produce an invalid (blank or top-level) category. Model validations and
   the controller's existing `unprocessable_entity` branch remain as a non-UI
   backstop (e.g. for hand-crafted requests).
8. **Reuse the existing `form` Stimulus controller**; write no new JS.
9. **No family-management UI** (no index/create/rename/delete of families). Family
   creation/renaming stays console-managed.

## Design

### Overview
Each editable field becomes a small `form_with` (scoped to that product) wrapped in
its own `turbo_frame_tag`. The **form** carries `data-controller="form"`; the
**select** carries `data-action="change->form#submit"`. Changing the select submits
the form via Turbo (`requestSubmit()`). The controller action updates the single
attribute and re-renders the same frame (the select, now showing the new value).
Because each form sits inside a table cell / card element, there is no `<tr>`/
`<form>` nesting problem.

> Wiring note (caught from the fizzy/campfire reference): `data-controller="form"`
> MUST be on the `<form>`, and `data-action="change->form#submit"` on the
> `<select>`. Stimulus resolves `form#submit` to the nearest ancestor `form`
> controller, and `this.element` is then the form, so `requestSubmit()` is valid.
> Putting the controller on the select would make `this.element` the select (which
> has no `requestSubmit`).

### Routes (`config/routes.rb`)
Within the existing `admin` namespace `resources :products` member block (currently
lines 222-224):
- **Remove** `get :inline_edit_category`.
- **Keep** `patch :update_category`.
- **Add** `patch :update_family`.

### Controller (`app/controllers/admin/products_controller.rb`)
- **`set_product` `only:` list (line 3):** remove `inline_edit_category`; keep
  `update_category`; **add `update_family`**.
- **Remove** the `inline_edit_category` GET action (lines 177-180); its only job
  was to render the edit state of the old toggle, which no longer exists.
- **Simplify `update_category`** to re-render the single-state frame partial, but
  KEEP it validation-aware (category is required + subcategory-constrained, so the
  update can genuinely fail and must surface 422):
  ```ruby
  # PATCH /admin/products/:id/update_category
  def update_category
    if @product.update(category_id: params.dig(:product, :category_id))
      render partial: "inline_category", locals: { product: @product }
    else
      render partial: "inline_category", locals: { product: @product }, status: :unprocessable_entity
    end
  end
  ```
  - **No `.presence`** on `category_id`: blanking is not a valid operation for a
    required field, and the UI never offers a blank option (see Views). If a blank
    arrives anyway (non-UI request), the model's `presence` validation rejects it and
    the `else` branch returns 422 with the frame re-rendered showing the still-saved
    value. This preserves the existing
    `update_category with invalid category returns unprocessable entity` test
    (`test/controllers/admin/products_controller_test.rb:192`).
- **Add `update_family`** — family is optional, so blank means "un-assign" and the
  update cannot fail validation at this layer:
  ```ruby
  # PATCH /admin/products/:id/update_family
  def update_family
    @product.update(product_family_id: params.dig(:product, :product_family_id).presence)
    render partial: "inline_family", locals: { product: @product }
  end
  ```
  - `.presence` maps the blank "— None —" option to `nil` (un-assign).
- `params.dig` avoids a `NoMethodError` if `params[:product]` is absent.
- Both actions set a single attribute directly (like the old `update_category`), so
  no `product_params` change is needed.

### Views

**1. `app/views/admin/products/_inline_category.html.erb` (rewrite, single state)**
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
- **No `include_blank`**: category is required, every product already has one, so the
  select always has a valid preselected value and offers no empty option. Parents are
  `<optgroup>` labels (not selectable). Result: the UI cannot submit a blank or a
  top-level category.
- Removes the dependency on `@categories` (previously set by `inline_edit_category`);
  options are computed in the partial as the index/edit form already do.

**2. `app/views/admin/products/_inline_family.html.erb` (new, mirror)**
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
- `include_blank: "— None —"` lets the admin un-assign; the literal em-dash glyph in a
  UI label is fine (the no-em-dash rule is about narrative prose).
- `ProductFamily.order(:name)` is queried per row. Acceptable for the admin index
  (small family count). If N+1 cost matters later, the index action can memoize the
  list and pass it as a local. Not optimised in v1.

**3. `app/views/admin/products/index.html.erb` (edit)**
- **Desktop table:** add a `Family` column — `<th>Family</th>` after the Category
  `<th>` (line 54), and `<td><%= render "inline_family", product: product %></td>`
  after the Category `<td>` (line 71). Update the category render to drop the
  `editing:` local (line 71 → `render "inline_category", product: product`).
- **Mobile cards:** beneath the existing category render (line 128), add
  `<%= render "inline_family", product: product %>`; update the category render to
  drop `editing:`.

### Data flow
1. Index renders → each row shows a Category select and a Family select, each in its
   own Turbo frame, each pre-selected to the current value.
2. Admin changes a select → `change->form#submit` → `requestSubmit()` → Turbo issues
   `PATCH update_category` / `update_family`.
3. Action updates the one attribute and re-renders that frame's partial → the frame
   swaps in place, select reflecting the saved value. No page reload; other cells
   untouched.
4. Selecting the Family "— None —" option saves `nil` (un-assign). The Category
   select has no blank option, so it always submits a valid subcategory id.

### Error handling
- `params.dig(:product, <key>)` guards a missing `product` param.
- **Category** is validated (`presence` + subcategory). The UI cannot produce an
  invalid value (no blank option; parents non-selectable), but `update_category`
  keeps the `if/else` and returns **422** with the frame re-rendered (showing the
  still-saved value) for any non-UI request that submits a blank or top-level id.
  This is a real, reachable branch only outside the dropdown, and it preserves the
  existing unprocessable-entity test.
- **Family** is optional, so `update_family` cannot fail this validation; the frame
  always re-renders with the persisted value. Blank → `nil` (un-assign).
- A since-deleted family/category simply won't be an option; a hand-crafted request
  with an unknown id would, for family, set an FK with no matching record
  (`belongs_to optional: true` allows it) and, for category, be rejected by the
  presence/subcategory validation. Options are server-rendered per request, so risk
  is low. No extra guarding in v1.

## Out of scope (explicitly not building)
- No `Admin::ProductFamilies` index/create/edit/delete UI. Families stay
  console-managed.
- No family editing on the product **edit** page (its Category control stays a plain
  in-form select; unchanged).
- No confirmation dialog; no toast/flash.
- No audit trail of category/family changes.
- No new Stimulus controller (reuse `form`).
- No model, schema, or `product_params` changes.

## Testing

Test-driven, Minitest + fixtures. Existing assets:
`test/controllers/admin/products_controller_test.rb` (signs in `users(:acme_admin)`
in `setup`), `test/fixtures/product_families.yml` (families incl. `single_wall_cups`,
`branded_cups`, `lids`, `straws`), `test/fixtures/products.yml` (products assigned to
families, e.g. `single_wall_8oz_white` → `single_wall_cups`),
`test/fixtures/users.yml` (non-admin fixtures: `users(:consumer)` has `role: nil`,
`users(:acme_member)` has `role: "member"`; both `admin? == false`).
`test/fixtures/categories.yml` has subcategories (e.g. `child_hot_cups`) and
top-level categories (e.g. `parent_cups_and_drinks`).

**Existing tests that MUST be reconciled** (`products_controller_test.rb:173-201`):
- `test "inline_edit_category returns success and renders select"` (line 173) —
  **DELETE.** It `get`s `inline_edit_category_admin_product_path`, a route this
  feature removes; it would otherwise raise on path-helper resolution.
- `test "update_category updates product category"` (line 180) — **KEEP** (still
  valid; the happy path still returns success and reassigns). Our new "reassign"
  test below would duplicate it, so do NOT add a separate one — extend/rename this if
  needed.
- `test "update_category with invalid category returns unprocessable entity"`
  (line 192) — **KEEP.** The validation-aware `update_category` still returns 422 for
  a top-level category id. This is why `update_category` retains its `if/else`.

Write failing tests first, then implement:

**Controller tests (`products_controller_test.rb`)**
1. `PATCH update_family` reassigns a product to a different family —
   `params: { product: { product_family_id: product_families(:branded_cups).id } }`;
   assert `product.reload.product_family` is the new family; response success.
2. `PATCH update_family` with blank id un-assigns —
   `params: { product: { product_family_id: "" } }`; assert
   `product.reload.product_family_id` is `nil`; response success.
3. (Covered by existing line-180 test — do not duplicate.) Category happy-path
   reassignment already tested.
4. (Covered by existing line-192 test — do not duplicate.) Invalid category → 422
   already tested; it remains green because `update_category` keeps `if/else`.
5. **Auth:** `update_family` (and, as a regression guard, `update_category`) require
   admin. Add a test that signs in `users(:consumer)` (non-admin) — or omits sign-in
   — and asserts `assert_redirected_to root_path` (per
   `Admin::ApplicationController#require_admin`).
6. (Optional) Assert the removed `inline_edit_category` route no longer resolves.

**View/integration (recommended)**
7. Index renders a Family select and a Category select per product row, each
   pre-selected to current value, in both desktop and mobile markup. Assert the body
   contains `select[name='product[product_family_id]']` and
   `select[name='product[category_id]']`, the two frame ids
   (`product_<id>_family`, `product_<id>_category`), and the auto-submit wiring
   (`data-action="change->form#submit"` on the selects, `data-controller="form"` on
   the forms) so the 37signals wiring in the acceptance criteria is actually covered.
   Also assert the Category select has **no** blank option and the Family select
   **does** (`— None —`).

## Acceptance criteria
- On the admin products index (desktop table and mobile cards), each product row
  shows a Category select and a Family select, pre-selected to current values.
- Changing the Category select immediately saves the new category (no Save button)
  and the select reflects it after the Turbo frame re-render.
- Changing the Family select immediately saves the new family; choosing "— None —"
  removes the product from its family.
- No Edit/Save/Cancel buttons remain for Category; the two controls behave
  identically except that Category offers no blank option (required) and Family
  offers "— None —" (optional).
- The Category select cannot submit a blank or top-level category (no blank option;
  parents are non-selectable optgroups). The model validations and the
  `update_category` 422 branch remain as a non-UI backstop.
- `data-controller="form"` sits on the form and `data-action="change->form#submit"`
  on the select (37signals wiring), reusing the existing `form` controller.
- The existing `inline_edit_category` GET test is removed; the `update_category`
  happy-path and unprocessable-entity tests remain green.
- The product **edit** page is unchanged.
- No regression to the index search, sorting, toggles, or reorder.
