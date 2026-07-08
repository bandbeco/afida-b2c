---
type: Plan
description: Task-by-task implementation plan for the acts_as_list-based admin ordering controls for categories and products.
status: shipped
timestamp: 2025-11-08
---

# Admin Ordering Controls Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add admin controls for managing category and product display order using up/down arrow buttons on dedicated ordering pages.

**Architecture:** Uses acts_as_list gem for automatic position management. Categories have global ordering, products have category-scoped ordering. Dedicated ordering pages with Turbo Stream updates for instant feedback.

**Tech Stack:** Rails 8, acts_as_list gem, Hotwire Turbo, DaisyUI, PostgreSQL

---

## Task 1: Add acts_as_list Gem

**Files:**
- Modify: `Gemfile`

**Step 1: Add acts_as_list gem to Gemfile**

Add after other gems in the main group:

```ruby
gem "acts_as_list"
```

**Step 2: Install the gem**

```bash
bundle install
```

Expected: "Bundle complete! 29 Gemfile dependencies..." (one more than before)

**Step 3: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "Add acts_as_list gem for ordering management"
```

---

## Task 2: Add Position Column to Categories

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_add_position_to_categories.rb`

**Step 1: Generate migration**

```bash
rails generate migration AddPositionToCategories position:integer
```

Expected: Creates migration file in db/migrate/

**Step 2: Edit migration to add index and backfill data**

```ruby
class AddPositionToCategories < ActiveRecord::Migration[8.0]
  def up
    add_column :categories, :position, :integer
    add_index :categories, :position

    # Backfill positions based on current name order
    Category.order(:name).each.with_index(1) do |category, index|
      category.update_column(:position, index)
    end

    change_column_null :categories, :position, false
  end

  def down
    remove_index :categories, :position
    remove_column :categories, :position
  end
end
```

**Step 3: Run migration**

```bash
rails db:migrate
```

Expected: "== AddPositionToCategories: migrated"

**Step 4: Verify in schema**

```bash
grep -A 5 "create_table \"categories\"" db/schema.rb
```

Expected: Should see `t.integer "position", null: false`

**Step 5: Commit**

```bash
git add db/migrate/*.rb db/schema.rb
git commit -m "Add position column to categories with backfill"
```

---

## Task 3: Rename sort_order to position on Products

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_rename_sort_order_to_position_on_products.rb`

**Step 1: Generate migration**

```bash
rails generate migration RenameSortOrderToPositionOnProducts
```

**Step 2: Edit migration**

```ruby
class RenameSortOrderToPositionOnProducts < ActiveRecord::Migration[8.0]
  def change
    rename_column :products, :sort_order, :position
    add_index :products, [:category_id, :position], name: "index_products_on_category_id_and_position"
  end
end
```

**Step 3: Run migration**

```bash
rails db:migrate
```

Expected: "== RenameSortOrderToPositionOnProducts: migrated"

**Step 4: Commit**

```bash
git add db/migrate/*.rb db/schema.rb
git commit -m "Rename sort_order to position on products and add composite index"
```

---

## Task 4: Update Product Model References

**Files:**
- Modify: `app/models/product.rb:26,91`
- Modify: `app/controllers/admin/products_controller.rb:91`

**Step 1: Update Product model default scope**

In `app/models/product.rb` line 26, change:

```ruby
default_scope { where(active: true).order(:sort_order, :name) }
```

to:

```ruby
default_scope { where(active: true).order(:position, :name) }
```

**Step 2: Update Product model strong params reference**

In `app/controllers/admin/products_controller.rb` line 91, change:

```ruby
:sort_order,
```

to:

```ruby
:position,
```

**Step 3: Update ProductVariant strong params**

In `app/controllers/admin/products_controller.rb` line 105, change:

```ruby
:sort_order,
```

to:

```ruby
:position,
```

**Step 4: Search for other sort_order references**

```bash
grep -r "sort_order" app/ test/ --include="*.rb"
```

Expected: Should find references in ProductVariant and test fixtures

**Step 5: Commit**

```bash
git add app/models/product.rb app/controllers/admin/products_controller.rb
git commit -m "Update Product model to use position instead of sort_order"
```

---

## Task 5: Update ProductVariant Model References

**Files:**
- Modify: `app/models/product_variant.rb`

**Step 1: Read ProductVariant model**

Check for sort_order references:

```bash
grep "sort_order" app/models/product_variant.rb
```

**Step 2: Update scopes that use sort_order**

Find and replace `sort_order` with `position` in:
- `by_sort_order` scope (rename to `by_position`)
- Any other references

In `app/models/product_variant.rb`, change scope:

```ruby
scope :by_sort_order, -> { order(:sort_order) }
```

to:

```ruby
scope :by_position, -> { order(:position) }
```

**Step 3: Update Product model reference to variant scope**

In `app/models/product.rb` line 36, change:

```ruby
has_many :active_variants, -> { active.by_sort_order }, class_name: "ProductVariant"
```

to:

```ruby
has_many :active_variants, -> { active.by_position }, class_name: "ProductVariant"
```

**Step 4: Commit**

```bash
git add app/models/product_variant.rb app/models/product.rb
git commit -m "Update ProductVariant to use position instead of sort_order"
```

---

## Task 6: Update Test Fixtures

**Files:**
- Modify: `test/fixtures/products.yml`
- Modify: `test/fixtures/product_variants.yml`

**Step 1: Update products fixtures**

In `test/fixtures/products.yml`, find all `sort_order:` and replace with `position:`

```bash
sed -i '' 's/sort_order:/position:/g' test/fixtures/products.yml
```

**Step 2: Update product_variants fixtures**

In `test/fixtures/product_variants.yml`, find all `sort_order:` and replace with `position:`

```bash
sed -i '' 's/sort_order:/position:/g' test/fixtures/product_variants.yml
```

**Step 3: Run tests to verify fixtures work**

```bash
rails test
```

Expected: All tests still passing (534 runs, 0 failures)

**Step 4: Commit**

```bash
git add test/fixtures/*.yml
git commit -m "Update test fixtures to use position instead of sort_order"
```

---

## Task 7: Add acts_as_list to Category Model

**Files:**
- Modify: `app/models/category.rb`

**Step 1: Write failing test**

Create `test/models/category_position_test.rb`:

```ruby
require "test_helper"

class CategoryPositionTest < ActiveSupport::TestCase
  test "categories can be moved higher in position" do
    category1 = categories(:cups)
    category2 = categories(:lids)

    initial_position = category1.position
    category1.move_lower

    assert category1.position > initial_position
  end

  test "categories can be moved lower in position" do
    category1 = categories(:cups)
    category2 = categories(:lids)

    category1.move_to_bottom
    initial_position = category1.position
    category1.move_higher

    assert category1.position < initial_position
  end

  test "top category cannot move higher" do
    category = Category.order(:position).first
    initial_position = category.position
    category.move_higher

    assert_equal initial_position, category.position
  end

  test "bottom category cannot move lower" do
    category = Category.order(:position).last
    initial_position = category.position
    category.move_lower

    assert_equal initial_position, category.position
  end
end
```

**Step 2: Run test to verify it fails**

```bash
rails test test/models/category_position_test.rb
```

Expected: FAIL - "undefined method `move_higher' for Category"

**Step 3: Add acts_as_list to Category model**

In `app/models/category.rb` after class definition:

```ruby
class Category < ApplicationRecord
  acts_as_list

  has_many :products
  # ... rest of code
end
```

**Step 4: Run tests to verify they pass**

```bash
rails test test/models/category_position_test.rb
```

Expected: PASS - 4 runs, 0 failures

**Step 5: Commit**

```bash
git add app/models/category.rb test/models/category_position_test.rb
git commit -m "Add acts_as_list to Category model with tests"
```

---

## Task 8: Add acts_as_list to Product Model

**Files:**
- Modify: `app/models/product.rb`

**Step 1: Write failing test**

Create `test/models/product_position_test.rb`:

```ruby
require "test_helper"

class ProductPositionTest < ActiveSupport::TestCase
  test "products can be moved higher within their category" do
    category = categories(:cups)
    products = category.products.order(:position).limit(2)
    product2 = products.second

    initial_position = product2.position
    product2.move_higher

    assert product2.position < initial_position
  end

  test "products can be moved lower within their category" do
    category = categories(:cups)
    products = category.products.order(:position).limit(2)
    product1 = products.first

    initial_position = product1.position
    product1.move_lower

    assert product1.position > initial_position
  end

  test "product position is scoped to category" do
    cups_category = categories(:cups)
    lids_category = categories(:lids)

    cups_product = cups_category.products.first
    lids_product = lids_category.products.first

    # Both can be position 1 in different categories
    cups_product.update(position: 1)
    lids_product.update(position: 1)

    assert_equal 1, cups_product.reload.position
    assert_equal 1, lids_product.reload.position
  end

  test "moving product to different category updates positions" do
    old_category = categories(:cups)
    new_category = categories(:lids)
    product = old_category.products.first

    product.update(category: new_category)

    # Should be added to bottom of new category
    assert_equal new_category.products.maximum(:position), product.position
  end
end
```

**Step 2: Run test to verify it fails**

```bash
rails test test/models/product_position_test.rb
```

Expected: FAIL - "undefined method `move_higher' for Product"

**Step 3: Add acts_as_list to Product model**

In `app/models/product.rb` after class definition:

```ruby
class Product < ApplicationRecord
  acts_as_list scope: :category_id

  # ... rest of code
end
```

**Step 4: Run tests to verify they pass**

```bash
rails test test/models/product_position_test.rb
```

Expected: PASS - 4 runs, 0 failures

**Step 5: Commit**

```bash
git add app/models/product.rb test/models/product_position_test.rb
git commit -m "Add acts_as_list to Product model with category scope and tests"
```

---

## Task 9: Add Routes for Category Ordering

**Files:**
- Modify: `config/routes.rb`

**Step 1: Add routes for category ordering**

In `config/routes.rb`, find the admin categories resources and modify:

```ruby
namespace :admin do
  resources :categories do
    collection do
      get :order
    end
    member do
      patch :move_higher
      patch :move_lower
    end
  end
  # ... other resources
end
```

**Step 2: Verify routes**

```bash
rails routes | grep "admin/categories"
```

Expected: Should see order_admin_categories, move_higher_admin_category, move_lower_admin_category routes

**Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "Add routes for category ordering"
```

---

## Task 10: Add Routes for Product Ordering

**Files:**
- Modify: `config/routes.rb`

**Step 1: Add routes for product ordering**

In `config/routes.rb`, find the admin products resources and modify:

```ruby
namespace :admin do
  resources :products do
    collection do
      get :order
    end
    member do
      patch :move_higher
      patch :move_lower
    end
  end
  # ... other resources
end
```

**Step 2: Verify routes**

```bash
rails routes | grep "admin/products.*order\|move"
```

Expected: Should see order_admin_products, move_higher_admin_product, move_lower_admin_product routes

**Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "Add routes for product ordering"
```

---

## Task 11: Add Category Ordering Controller Actions

**Files:**
- Modify: `app/controllers/admin/categories_controller.rb`

**Step 1: Write controller test**

Create `test/controllers/admin/categories_ordering_test.rb`:

```ruby
require "test_helper"

class Admin::CategoriesOrderingTest < ActionDispatch::IntegrationTest
  test "should get order page" do
    get order_admin_categories_path
    assert_response :success
    assert_select "h1", "Order Categories"
  end

  test "should move category higher" do
    category = categories(:lids)
    initial_position = category.position

    patch move_higher_admin_category_path(category)
    assert_redirected_to order_admin_categories_path

    assert category.reload.position < initial_position
  end

  test "should move category lower" do
    category = categories(:cups)
    initial_position = category.position

    patch move_lower_admin_category_path(category)
    assert_redirected_to order_admin_categories_path

    assert category.reload.position > initial_position
  end

  test "should respond with turbo stream for move_higher" do
    category = categories(:lids)

    patch move_higher_admin_category_path(category),
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
  end
end
```

**Step 2: Run test to verify it fails**

```bash
rails test test/controllers/admin/categories_ordering_test.rb
```

Expected: FAIL - "The action 'order' could not be found"

**Step 3: Add controller actions**

In `app/controllers/admin/categories_controller.rb`, add before the private section:

```ruby
# GET /admin/categories/order
def order
  @categories = Category.order(:position)
end

# PATCH /admin/categories/:id/move_higher
def move_higher
  @category = Category.find_by!(slug: params[:id])
  @category.move_higher
  @categories = Category.order(:position)

  respond_to do |format|
    format.turbo_stream
    format.html { redirect_to order_admin_categories_path }
  end
end

# PATCH /admin/categories/:id/move_lower
def move_lower
  @category = Category.find_by!(slug: params[:id])
  @category.move_lower
  @categories = Category.order(:position)

  respond_to do |format|
    format.turbo_stream
    format.html { redirect_to order_admin_categories_path }
  end
end
```

**Step 4: Update before_action**

Change the before_action line to include new actions:

```ruby
before_action :set_category, only: %i[ edit update destroy move_higher move_lower ]
```

**Step 5: Run tests**

```bash
rails test test/controllers/admin/categories_ordering_test.rb
```

Expected: FAIL - missing template (we'll add views next)

**Step 6: Commit**

```bash
git add app/controllers/admin/categories_controller.rb test/controllers/admin/categories_ordering_test.rb
git commit -m "Add category ordering controller actions"
```

---

## Task 12: Add Product Ordering Controller Actions

**Files:**
- Modify: `app/controllers/admin/products_controller.rb`

**Step 1: Write controller test**

Create `test/controllers/admin/products_ordering_test.rb`:

```ruby
require "test_helper"

class Admin::ProductsOrderingTest < ActionDispatch::IntegrationTest
  test "should get order page" do
    get order_admin_products_path
    assert_response :success
    assert_select "h1", "Order Products"
  end

  test "should show products from first category by default" do
    first_category = Category.order(:position).first

    get order_admin_products_path
    assert_response :success
    assert_select "select#category_id option[selected]", first_category.name
  end

  test "should show products from selected category" do
    category = categories(:lids)

    get order_admin_products_path(category_id: category.id)
    assert_response :success
    assert_select "select#category_id option[selected]", category.name
  end

  test "should move product higher within category" do
    category = categories(:cups)
    products = category.products.order(:position)
    product = products.second
    initial_position = product.position

    patch move_higher_admin_product_path(product)
    assert_redirected_to order_admin_products_path(category_id: category.id)

    assert product.reload.position < initial_position
  end

  test "should move product lower within category" do
    category = categories(:cups)
    products = category.products.order(:position)
    product = products.first
    initial_position = product.position

    patch move_lower_admin_product_path(product)
    assert_redirected_to order_admin_products_path(category_id: category.id)

    assert product.reload.position > initial_position
  end
end
```

**Step 2: Run test to verify it fails**

```bash
rails test test/controllers/admin/products_ordering_test.rb
```

Expected: FAIL - "The action 'order' could not be found"

**Step 3: Add controller actions**

In `app/controllers/admin/products_controller.rb`, add before the private section:

```ruby
# GET /admin/products/order
def order
  @categories = Category.order(:position)
  @selected_category = if params[:category_id]
    Category.find(params[:category_id])
  else
    @categories.first
  end

  @products = if @selected_category
    @selected_category.products.unscoped
      .where(category_id: @selected_category.id)
      .order(:position)
  else
    []
  end
end

# PATCH /admin/products/:id/move_higher
def move_higher
  @product = Product.unscoped.find_by!(slug: params[:id])
  @product.move_higher

  redirect_to order_admin_products_path(category_id: @product.category_id)
end

# PATCH /admin/products/:id/move_lower
def move_lower
  @product = Product.unscoped.find_by!(slug: params[:id])
  @product.move_lower

  redirect_to order_admin_products_path(category_id: @product.category_id)
end
```

**Step 4: Update before_action**

Change the before_action line to exclude ordering actions:

```ruby
before_action :set_product, only: %i[ show edit update destroy new_variant destroy_product_photo destroy_lifestyle_photo ]
```

**Step 5: Run tests**

```bash
rails test test/controllers/admin/products_ordering_test.rb
```

Expected: FAIL - missing template (we'll add views next)

**Step 6: Commit**

```bash
git add app/controllers/admin/products_controller.rb test/controllers/admin/products_ordering_test.rb
git commit -m "Add product ordering controller actions"
```

---

## Task 13: Create Category Ordering View

**Files:**
- Create: `app/views/admin/categories/order.html.erb`

**Step 1: Create the view file**

Create `app/views/admin/categories/order.html.erb`:

```erb
<div class="container mx-auto px-4 py-8">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-3xl font-bold">Order Categories</h1>
    <%= link_to "Back to Categories", admin_categories_path, class: "btn btn-ghost" %>
  </div>

  <%= turbo_frame_tag "categories_list" do %>
    <div class="overflow-x-auto">
      <table class="table table-zebra w-full">
        <thead>
          <tr>
            <th class="w-24">Position</th>
            <th>Name</th>
            <th class="w-32">Actions</th>
          </tr>
        </thead>
        <tbody>
          <% @categories.each do |category| %>
            <tr>
              <td><%= category.position %></td>
              <td><%= category.name %></td>
              <td>
                <div class="flex gap-2">
                  <%= button_to move_higher_admin_category_path(category),
                      method: :patch,
                      class: "btn btn-sm btn-ghost",
                      disabled: category.first?,
                      form: { data: { turbo_frame: "categories_list" } } do %>
                    ↑
                  <% end %>
                  <%= button_to move_lower_admin_category_path(category),
                      method: :patch,
                      class: "btn btn-sm btn-ghost",
                      disabled: category.last?,
                      form: { data: { turbo_frame: "categories_list" } } do %>
                    ↓
                  <% end %>
                </div>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  <% end %>
</div>
```

**Step 2: Run test to verify view renders**

```bash
rails test test/controllers/admin/categories_ordering_test.rb::test_should_get_order_page
```

Expected: PASS

**Step 3: Commit**

```bash
git add app/views/admin/categories/order.html.erb
git commit -m "Add category ordering view"
```

---

## Task 14: Create Category Ordering Turbo Stream Templates

**Files:**
- Create: `app/views/admin/categories/move_higher.turbo_stream.erb`
- Create: `app/views/admin/categories/move_lower.turbo_stream.erb`

**Step 1: Create move_higher turbo stream template**

Create `app/views/admin/categories/move_higher.turbo_stream.erb`:

```erb
<%= turbo_stream.replace "categories_list" do %>
  <%= turbo_frame_tag "categories_list" do %>
    <div class="overflow-x-auto">
      <table class="table table-zebra w-full">
        <thead>
          <tr>
            <th class="w-24">Position</th>
            <th>Name</th>
            <th class="w-32">Actions</th>
          </tr>
        </thead>
        <tbody>
          <% @categories.each do |category| %>
            <tr>
              <td><%= category.position %></td>
              <td><%= category.name %></td>
              <td>
                <div class="flex gap-2">
                  <%= button_to move_higher_admin_category_path(category),
                      method: :patch,
                      class: "btn btn-sm btn-ghost",
                      disabled: category.first?,
                      form: { data: { turbo_frame: "categories_list" } } do %>
                    ↑
                  <% end %>
                  <%= button_to move_lower_admin_category_path(category),
                      method: :patch,
                      class: "btn btn-sm btn-ghost",
                      disabled: category.last?,
                      form: { data: { turbo_frame: "categories_list" } } do %>
                    ↓
                  <% end %>
                </div>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  <% end %>
<% end %>
```

**Step 2: Create move_lower turbo stream template**

Create `app/views/admin/categories/move_lower.turbo_stream.erb` with the same content as move_higher.

**Step 3: Run turbo stream test**

```bash
rails test test/controllers/admin/categories_ordering_test.rb::test_should_respond_with_turbo_stream_for_move_higher
```

Expected: PASS

**Step 4: Commit**

```bash
git add app/views/admin/categories/*.turbo_stream.erb
git commit -m "Add category ordering turbo stream templates"
```

---

## Task 15: Create Product Ordering View

**Files:**
- Create: `app/views/admin/products/order.html.erb`

**Step 1: Create the view file**

Create `app/views/admin/products/order.html.erb`:

```erb
<div class="container mx-auto px-4 py-8">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-3xl font-bold">Order Products</h1>
    <%= link_to "Back to Products", admin_products_path, class: "btn btn-ghost" %>
  </div>

  <% if @categories.any? %>
    <div class="mb-6">
      <%= form_with url: order_admin_products_path, method: :get, class: "flex gap-4 items-center" do |f| %>
        <%= f.label :category_id, "Category:", class: "font-semibold" %>
        <%= f.select :category_id,
            options_from_collection_for_select(@categories, :id, :name, @selected_category&.id),
            {},
            class: "select select-bordered w-64",
            onchange: "this.form.requestSubmit()" %>
      <% end %>
    </div>

    <% if @products.any? %>
      <div class="overflow-x-auto">
        <table class="table table-zebra w-full">
          <thead>
            <tr>
              <th class="w-24">Position</th>
              <th>Name</th>
              <th>SKU</th>
              <th class="w-32">Actions</th>
            </tr>
          </thead>
          <tbody>
            <% @products.each do |product| %>
              <tr>
                <td><%= product.position %></td>
                <td><%= product.name %></td>
                <td><%= product.sku %></td>
                <td>
                  <div class="flex gap-2">
                    <%= button_to move_higher_admin_product_path(product),
                        method: :patch,
                        class: "btn btn-sm btn-ghost",
                        disabled: product.first? do %>
                      ↑
                    <% end %>
                    <%= button_to move_lower_admin_product_path(product),
                        method: :patch,
                        class: "btn btn-sm btn-ghost",
                        disabled: product.last? do %>
                      ↓
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% else %>
      <p class="text-gray-500">No products in this category.</p>
    <% end %>
  <% else %>
    <p class="text-gray-500">No categories available. Create categories first.</p>
  <% end %>
</div>
```

**Step 2: Run test to verify view renders**

```bash
rails test test/controllers/admin/products_ordering_test.rb::test_should_get_order_page
```

Expected: PASS

**Step 3: Commit**

```bash
git add app/views/admin/products/order.html.erb
git commit -m "Add product ordering view with category filter"
```

---

## Task 16: Add Links to Ordering Pages from Index

**Files:**
- Modify: `app/views/admin/categories/index.html.erb`
- Modify: `app/views/admin/products/index.html.erb`

**Step 1: Add link to categories index**

In `app/views/admin/categories/index.html.erb`, find the header section and add the reorder link:

```erb
<div class="flex justify-between items-center mb-6">
  <h1 class="text-3xl font-bold">Categories</h1>
  <div class="flex gap-2">
    <%= link_to "Reorder Categories", order_admin_categories_path, class: "btn btn-outline" %>
    <%= link_to "New Category", new_admin_category_path, class: "btn btn-primary" %>
  </div>
</div>
```

**Step 2: Add link to products index**

In `app/views/admin/products/index.html.erb`, find the header section and add the reorder link:

```erb
<div class="flex justify-between items-center mb-6">
  <h1 class="text-3xl font-bold">Products</h1>
  <div class="flex gap-2">
    <%= link_to "Reorder Products", order_admin_products_path, class: "btn btn-outline" %>
    <%= link_to "New Product", new_admin_product_path, class: "btn btn-primary" %>
  </div>
</div>
```

**Step 3: Test links appear**

```bash
rails test:system
```

Expected: System tests pass

**Step 4: Commit**

```bash
git add app/views/admin/categories/index.html.erb app/views/admin/products/index.html.erb
git commit -m "Add reorder links to admin index pages"
```

---

## Task 17: Update Category Index Ordering

**Files:**
- Modify: `app/controllers/admin/categories_controller.rb:7`

**Step 1: Update categories index to order by position**

In `app/controllers/admin/categories_controller.rb` line 7, change:

```ruby
@categories = Category.includes(image_attachment: :blob).order(:name)
```

to:

```ruby
@categories = Category.includes(image_attachment: :blob).order(:position)
```

**Step 2: Run tests**

```bash
rails test test/controllers/admin/categories_controller_test.rb
```

Expected: PASS

**Step 3: Commit**

```bash
git add app/controllers/admin/categories_controller.rb
git commit -m "Order categories by position in admin index"
```

---

## Task 18: Run All Tests

**Step 1: Run full test suite**

```bash
rails test
```

Expected: All tests passing

**Step 2: Check test coverage**

```bash
grep "Line Coverage:" coverage/.last_run.json || echo "Check coverage/index.html"
```

Expected: Coverage should be similar or better than baseline (83.1%)

**Step 3: Verify no regressions**

If any tests fail, fix them before proceeding.

---

## Task 19: Manual Testing

**Step 1: Start the server**

```bash
bin/dev
```

**Step 2: Test category ordering**

1. Visit http://localhost:3000/admin/categories
2. Click "Reorder Categories"
3. Use up/down arrows to reorder
4. Verify positions update instantly (Turbo Stream)
5. Refresh page - verify order persists

**Step 3: Test product ordering**

1. Visit http://localhost:3000/admin/products
2. Click "Reorder Products"
3. Select a category from dropdown
4. Use up/down arrows to reorder products
5. Switch to different category
6. Verify products ordered independently per category

**Step 4: Test edge cases**

1. Try moving top category up (should be disabled)
2. Try moving bottom category down (should be disabled)
3. Same for products
4. Verify positions renumber correctly

**Step 5: Document any issues**

If issues found, create tasks to fix before final commit.

---

## Task 20: Final Commit and Cleanup

**Step 1: Run final test suite**

```bash
rails test
```

Expected: All passing

**Step 2: Review git status**

```bash
git status
```

Expected: Working tree clean (all changes committed)

**Step 3: Review commit log**

```bash
git log --oneline origin/master..HEAD
```

Expected: Clean, descriptive commits following the feature implementation

**Step 4: Push branch**

```bash
git push -u origin feature/admin-ordering-controls
```

---

## Success Criteria

- [ ] acts_as_list gem installed
- [ ] Categories have position column with backfilled data
- [ ] Products use position instead of sort_order
- [ ] Categories can be reordered globally
- [ ] Products can be reordered within each category
- [ ] Dedicated ordering pages with up/down arrows
- [ ] Turbo Stream updates work for instant feedback
- [ ] Links to ordering pages from admin index pages
- [ ] All tests passing (model, controller, integration)
- [ ] Manual testing confirms everything works
- [ ] Code committed and pushed to feature branch

## Next Steps

After implementation complete:
1. Create pull request
2. Request code review
3. Address review feedback
4. Merge to master
5. Deploy to production
