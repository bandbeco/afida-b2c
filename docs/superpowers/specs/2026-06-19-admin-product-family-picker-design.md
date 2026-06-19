# Admin product family picker

**Date:** 2026-06-19
**Status:** Approved (design)

## Problem

Admins cannot reassign a product to a different product family from the UI. The
`Product` belongs_to `ProductFamily` association exists and is fully wired on the
backend, but the admin product edit page exposes no control for it. Today the
only way to change a product's family is via the Rails console or a migration.

Goal: let an admin move a product from one family to another (or to no family)
directly on the product edit page.

## Background (current state)

- `Product belongs_to :product_family, optional: true`
  (`app/models/product.rb:29`). The FK column `products.product_family_id` is
  nullable; there is no presence validation.
- `ProductFamily has_many :products, dependent: :nullify`
  (`app/models/product_family.rb:2`). No counter cache.
- No callbacks fire on family change. Changing the family overwrites the FK with
  no side effects: no slug regeneration, no search reindex, no counter updates,
  no touch.
- `:product_family_id` is **already permitted** in `product_params`
  (`app/controllers/admin/products_controller.rb:262`).
- There is **no** `Admin::ProductFamiliesController` and no routes for managing
  families. Families are data-only / console-managed.
- Authorization is a single `require_admin` before_action in
  `Admin::ApplicationController`; there are no per-resource policies.

### Customer-visible effect of a family change

`Product#display_name` (`app/models/product.rb:218-223`) renders as
`"<Family Name> (<Product Name>)"` when a family is present, falling back to the
product name otherwise. This method is used in cart messages, order displays, and
product cards. Therefore moving a product between families changes how it is
labelled to customers. The change is reversible and low-stakes, but it is not a
purely internal admin concern. (Decision: no confirmation dialog; see below.)

### Closest existing precedent

The **Category** control on the same edit page already uses an inline-edit
pattern that this feature will mirror exactly:

- `GET inline_edit_category` renders an editing partial
  (`app/controllers/admin/products_controller.rb:176-180`).
- `PATCH update_category` persists `category_id` and re-renders the read-only
  partial, with an `:unprocessable_entity` error branch
  (`app/controllers/admin/products_controller.rb:182-190`).
- The partial swaps between a read-only display and an inline `select` inside a
  Turbo frame, saving independently of the main product form.

## Decisions

These were settled during brainstorming:

1. **Scope: picker only.** Add a family picker to the product edit page. Do **not**
   build any family-management UI (no index/create/rename/delete, no
   "manage products from the family side"). Family creation and renaming remain
   console-managed. (YAGNI: families are created rarely; the frequent operation is
   reassigning a product.)
2. **UX: inline edit, matching Category.** Read-only display with an Edit link
   that swaps to a select, saves on its own via a dedicated action, and swaps back.
   Chosen for consistency with the Category control sitting right beside it.
3. **No confirmation dialog.** Save persists immediately, like the Category
   inline edit. The change is reversible.
4. **Dropdown: alphabetical + "— None —".** List all families ordered by name,
   plus a blank option so an admin can also un-assign a product from its family
   (valid because the FK is optional).
5. **Placement: directly beneath the Category control** in the Details fieldset,
   so the two associations read as a pair.

## Design

This is almost entirely a UI/controller-action addition that clones the proven
Category inline-edit pattern. No model changes, no migration, no strong-params
change.

### Components

**1. Routes** (`config/routes.rb`)

Add two member routes on the existing `admin/products` resource, paralleling the
category routes:

- `GET  inline_edit_family` → renders the editing partial
- `PATCH update_family` → persists `product_family_id`, renders the read-only
  partial

**2. Controller** (`app/controllers/admin/products_controller.rb`)

Two new actions, structurally identical to the category pair:

```ruby
# GET /admin/products/:id/inline_edit_family
def inline_edit_family
  @product_families = ProductFamily.order(:name)
  render partial: "inline_family", locals: { product: @product, editing: true }
end

# PATCH /admin/products/:id/update_family
def update_family
  if @product.update(product_family_id: params[:product][:product_family_id].presence)
    render partial: "inline_family", locals: { product: @product, editing: false }
  else
    @product_families = ProductFamily.order(:name)
    render partial: "inline_family", locals: { product: @product, editing: true }, status: :unprocessable_entity
  end
end
```

- `.presence` converts the blank "— None —" choice to `nil`, which the optional
  FK accepts (un-assign).
- These actions set `product_family_id` directly (like `update_category`), so no
  change to `product_params` is required even though it already permits the key.
- `set_product` already loads `@product` via `Product.unscoped.find_by!(slug:)`
  (`app/controllers/admin/products_controller.rb:241-243`); both new actions rely
  on it, consistent with the category actions.

**3. View partial** (`app/views/admin/products/_inline_family.html.erb`)

A Turbo-frame partial with two states, modeled on `_inline_category.html.erb`:

- **Read-only** (`editing: false`): shows `product.product_family&.name || "None"`
  with an **Edit** link targeting the frame.
- **Editing** (`editing: true`): a `collection_select` over `@product_families`
  with `include_blank: "— None —"`, the current value preselected, plus Save and
  Cancel. Cancel re-fetches the read-only state (GET back to the read-only
  render).

Reuse the same DaisyUI classes as the category partial (`select select-bordered`,
etc.). Per project rules: no inline styles, and no bold/semibold font weights
(`font-bold`/`font-semibold`).

**4. Form placement** (`app/views/admin/products/_form.html.erb`)

Mount the read-only state of the partial in the Details fieldset, directly beneath
the Category control (around `app/views/admin/products/_form.html.erb:190`):

```erb
<%= render "inline_family", product: form.object, editing: false %>
```

### Data flow

1. Edit page renders → Details section shows Family in read-only state inside its
   Turbo frame.
2. Admin clicks **Edit** → `GET inline_edit_family` → frame swaps to the select.
3. Admin picks a family (or "— None —") and clicks **Save** →
   `PATCH update_family` → `@product.update(...)` → frame swaps back to read-only
   showing the new family.
4. No other product fields are touched; the change is independent of the main
   form's Save button.

### Error handling

- A failed update re-renders the editing partial with `:unprocessable_entity`,
  matching `update_category`. In practice the update cannot fail validation
  (family is optional and unconstrained), but the symmetric error branch is kept
  for consistency.
- Stale option (family deleted mid-edit): a since-deleted family simply won't
  appear in the select. Submitting an unknown id would set an FK pointing at no
  record; `belongs_to optional: true` does not block this. Risk is low because
  families are rarely deleted, and no extra guarding will be added unless it
  proves necessary.

## Out of scope (explicitly not building)

- No `Admin::ProductFamilies` index / create / edit / delete UI. Families remain
  console-managed.
- No "add/remove products from the family side" screen.
- No confirmation dialog on family change.
- No audit trail / history of family moves.
- No model, schema, or strong-params changes.

## Testing

Test-driven, using the existing Minitest + fixtures setup. Relevant existing
files: `test/controllers/admin/products_controller_test.rb`,
`test/fixtures/product_families.yml`, `test/fixtures/products.yml`. The fixtures
already include multiple families (e.g. `single_wall_cups`, `branded_cups`,
`lids`, `straws`) and products assigned to them.

Write failing tests first, then implement:

1. `PATCH update_family` reassigns a product to a different family — assert
   `product.reload.product_family` is the new family and the response renders the
   read-only partial.
2. `PATCH update_family` with a blank `product_family_id` un-assigns the family —
   assert `product.reload.product_family_id` is `nil`.
3. `GET inline_edit_family` renders the editing partial containing the select with
   families listed (alphabetical) and a "— None —" option.
4. Both new actions require admin: when not signed in as an admin, the request is
   redirected (consistent with `Admin::ApplicationController#require_admin`).
5. (Optional) Integration/system check that the product edit page renders the
   Family control beside Category in the Details section.

## Acceptance criteria

- On the product edit page, an admin sees a Family control beside Category showing
  the current family (or "None").
- Clicking Edit reveals a dropdown of all families (alphabetical) plus "— None —";
  the current value is preselected.
- Saving persists the new family immediately (no full-form submit) and the control
  returns to its read-only state showing the new value.
- Selecting "— None —" and saving removes the product from its family.
- No regression to the existing Category inline edit or the main product form.
