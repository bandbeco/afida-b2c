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
  FK column `products.product_family_id` is nullable; no presence validation.
- `Product belongs_to :category` (category inline-edit already exists on the index).
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
7. **Reuse the existing `form` Stimulus controller**; write no new JS.
8. **No family-management UI** (no index/create/rename/delete of families). Family
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
- **Remove** the `inline_edit_category` action (lines 176-180).
- **Rewrite `update_category`** to re-render the single-state frame partial:
  ```ruby
  # PATCH /admin/products/:id/update_category
  def update_category
    @product.update(category_id: params.dig(:product, :category_id).presence)
    render partial: "inline_category", locals: { product: @product }
  end
  ```
- **Add `update_family`**, symmetric:
  ```ruby
  # PATCH /admin/products/:id/update_family
  def update_family
    @product.update(product_family_id: params.dig(:product, :product_family_id).presence)
    render partial: "inline_family", locals: { product: @product }
  end
  ```
- `.presence` maps the blank option to `nil` (un-assign). `params.dig` avoids a
  `NoMethodError` if `params[:product]` is absent.
- These actions set a single attribute directly (like the old `update_category`), so
  no `product_params` change is needed.
- The update cannot fail model validation here (category and family are
  unconstrained at this layer), so re-rendering the frame is acceptable on both
  paths; no separate error partial is introduced. (A future `unprocessable_entity`
  branch can re-render the same partial if validations are added.)

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
          { include_blank: "—" },
          class: "select select-bordered select-sm",
          data: { action: "change->form#submit" } %>
  <% end %>
<% end %>
```
This removes the dependency on `@categories` (previously set by `inline_edit_category`);
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
4. Selecting the blank option saves `nil` (un-assign).

### Error handling
- `params.dig(:product, <key>)` guards a missing `product` param.
- Update cannot fail model validation at this layer; the frame re-renders with the
  persisted value regardless.
- A since-deleted family/category simply won't be an option; submitting an unknown id
  would set an FK with no matching record. `belongs_to optional: true` (family) allows
  this; no category presence/association validation was observed. Options are
  server-rendered per request, so risk is low. No extra guarding in v1.

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
families, e.g. `single_wall_8oz_white` → `single_wall_cups`).

Write failing tests first, then implement:

**Controller tests (`products_controller_test.rb`)**
1. `PATCH update_family` reassigns a product to a different family —
   `params: { product: { product_family_id: <id> } }`; assert
   `product.reload.product_family` is the new family; response success; body
   contains the family frame id / re-rendered select.
2. `PATCH update_family` with blank id un-assigns —
   `params: { product: { product_family_id: "" } }`; assert
   `product.reload.product_family_id` is `nil`.
3. `PATCH update_category` reassigns category (regression of the rewritten action) —
   assert `product.reload.category` changed; frame re-rendered.
4. `PATCH update_category` with blank id — confirm the intended behaviour of the
   `.presence` change (sets category to `nil`); if category should remain required,
   adjust this test to assert the desired handling.
5. **Auth:** `update_family` and `update_category` require admin. The file's `setup`
   signs in an admin and has no non-admin example; add a test that does not sign in
   (or signs in a non-admin) and asserts `assert_redirected_to root_path`. Confirm a
   non-admin fixture exists; if not, create one or test the signed-out case.
6. (Optional) Assert the removed `inline_edit_category` route no longer resolves.

**View/integration (optional but recommended)**
7. Index renders a Family select and a Category select per product row, each
   pre-selected to current value, in both desktop and mobile markup. A request test
   asserting the body contains the two frame ids (`product_<id>_family`,
   `product_<id>_category`) and the selected option is sufficient.

## Acceptance criteria
- On the admin products index (desktop table and mobile cards), each product row
  shows a Category select and a Family select, pre-selected to current values.
- Changing the Category select immediately saves the new category (no Save button)
  and the select reflects it after the Turbo frame re-render.
- Changing the Family select immediately saves the new family; choosing "— None —"
  removes the product from its family.
- No Edit/Save/Cancel buttons remain for Category; both controls behave identically.
- `data-controller="form"` sits on the form and `data-action="change->form#submit"`
  on the select (37signals wiring), reusing the existing `form` controller.
- The product **edit** page is unchanged.
- No regression to the index search, sorting, toggles, or reorder.
