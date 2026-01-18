# Collections & Curated Samples Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable audience-based product navigation through Collections (cross-cutting product groups like "Coffee Shop Essentials") and Curated Sample Packs (pre-selected samples for specific customer types).

**Architecture:** Collections are a many-to-many relationship with Products via a join table. Unlike Categories (which slice vertically by product type), Collections slice horizontally by audience/use-case. A product belongs to ONE category but can appear in MANY collections. Curated Sample Packs are special collections flagged for the samples flow.

**Tech Stack:** Rails 8.1, PostgreSQL, Hotwire (Turbo + Stimulus), TailwindCSS 4 + DaisyUI, Active Storage (images), acts_as_list (ordering)

---

## Phase 1: Core Collection Model

### Task 1: Create Collection Migration

**Files:**
- Create: `db/migrate/XXXXXX_create_collections.rb`

**Step 1: Generate the migration**

Run:
```bash
rails generate migration CreateCollections name:string slug:string:uniq description:text meta_title:string meta_description:text featured:boolean position:integer
```

**Step 2: Edit migration for proper constraints**

```ruby
class CreateCollections < ActiveRecord::Migration[8.0]
  def change
    create_table :collections do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :meta_title
      t.text :meta_description
      t.boolean :featured, default: false, null: false
      t.boolean :sample_pack, default: false, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :collections, :slug, unique: true
    add_index :collections, :featured
    add_index :collections, :sample_pack
    add_index :collections, :position
  end
end
```

**Step 3: Run migration**

Run: `rails db:migrate`
Expected: Migration completes successfully

**Step 4: Commit**

```bash
git add db/migrate/*_create_collections.rb db/schema.rb
git commit -m "feat: add collections table

- name, slug, description for identity
- meta_title, meta_description for SEO
- featured flag for homepage display
- sample_pack flag for curated samples
- position for ordering via acts_as_list"
```

---

### Task 2: Create CollectionItem Join Table Migration

**Files:**
- Create: `db/migrate/XXXXXX_create_collection_items.rb`

**Step 1: Generate the migration**

Run:
```bash
rails generate migration CreateCollectionItems collection:references product:references position:integer
```

**Step 2: Edit migration for proper constraints**

```ruby
class CreateCollectionItems < ActiveRecord::Migration[8.0]
  def change
    create_table :collection_items do |t|
      t.references :collection, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :collection_items, [:collection_id, :product_id], unique: true
    add_index :collection_items, [:collection_id, :position]
  end
end
```

**Step 3: Run migration**

Run: `rails db:migrate`
Expected: Migration completes successfully

**Step 4: Commit**

```bash
git add db/migrate/*_create_collection_items.rb db/schema.rb
git commit -m "feat: add collection_items join table

- links collections to products (many-to-many)
- position for ordering within collection
- unique constraint prevents duplicate entries"
```

---

### Task 3: Create Collection Model with Tests

**Files:**
- Create: `test/models/collection_test.rb`
- Create: `app/models/collection.rb`
- Create: `test/fixtures/collections.yml`

**Step 1: Write the failing test**

```ruby
# test/models/collection_test.rb
require "test_helper"

class CollectionTest < ActiveSupport::TestCase
  test "valid collection" do
    collection = Collection.new(name: "Coffee Shop Essentials", slug: "coffee-shop")
    assert collection.valid?
  end

  test "requires name" do
    collection = Collection.new(slug: "test")
    assert_not collection.valid?
    assert_includes collection.errors[:name], "can't be blank"
  end

  test "requires slug" do
    collection = Collection.new(name: "Test")
    assert_not collection.valid?
    assert_includes collection.errors[:slug], "can't be blank"
  end

  test "slug must be unique" do
    existing = collections(:coffee_shop)
    collection = Collection.new(name: "Another", slug: existing.slug)
    assert_not collection.valid?
    assert_includes collection.errors[:slug], "has already been taken"
  end

  test "to_param returns slug" do
    collection = collections(:coffee_shop)
    assert_equal collection.slug, collection.to_param
  end

  test "featured scope returns featured collections" do
    featured = Collection.featured
    assert featured.all?(&:featured?)
  end

  test "sample_packs scope returns sample pack collections" do
    packs = Collection.sample_packs
    assert packs.all?(&:sample_pack?)
  end
end
```

**Step 2: Create fixtures**

```yaml
# test/fixtures/collections.yml
coffee_shop:
  name: Coffee Shop Essentials
  slug: coffee-shop
  description: Everything your café needs for takeaway drinks and snacks.
  featured: true
  sample_pack: false
  position: 1

restaurant:
  name: Restaurant Collection
  slug: restaurant
  description: Takeaway containers, cutlery, and napkins for restaurants.
  featured: true
  sample_pack: false
  position: 2

coffee_shop_samples:
  name: Coffee Shop Sample Pack
  slug: coffee-shop-samples
  description: Try our most popular café products.
  featured: false
  sample_pack: true
  position: 1
```

**Step 3: Run test to verify it fails**

Run: `rails test test/models/collection_test.rb`
Expected: FAIL with "uninitialized constant Collection"

**Step 4: Write the model**

```ruby
# app/models/collection.rb
class Collection < ApplicationRecord
  has_many :collection_items, dependent: :destroy
  has_many :products, through: :collection_items

  has_one_attached :image

  acts_as_list

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  scope :featured, -> { where(featured: true) }
  scope :sample_packs, -> { where(sample_pack: true) }
  scope :browsable, -> { where(sample_pack: false) }

  def to_param
    slug
  end
end
```

**Step 5: Run test to verify it passes**

Run: `rails test test/models/collection_test.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add app/models/collection.rb test/models/collection_test.rb test/fixtures/collections.yml
git commit -m "feat: add Collection model

- validates name and slug presence
- slug uniqueness for SEO-friendly URLs
- featured and sample_packs scopes
- acts_as_list for position ordering
- has_one_attached :image for collection hero"
```

---

### Task 4: Create CollectionItem Model with Tests

**Files:**
- Create: `test/models/collection_item_test.rb`
- Create: `app/models/collection_item.rb`
- Create: `test/fixtures/collection_items.yml`

**Step 1: Write the failing test**

```ruby
# test/models/collection_item_test.rb
require "test_helper"

class CollectionItemTest < ActiveSupport::TestCase
  test "valid collection item" do
    item = CollectionItem.new(
      collection: collections(:coffee_shop),
      product: products(:hot_cup_8oz)
    )
    assert item.valid?
  end

  test "requires collection" do
    item = CollectionItem.new(product: products(:hot_cup_8oz))
    assert_not item.valid?
    assert_includes item.errors[:collection], "must exist"
  end

  test "requires product" do
    item = CollectionItem.new(collection: collections(:coffee_shop))
    assert_not item.valid?
    assert_includes item.errors[:product], "must exist"
  end

  test "product must be unique within collection" do
    existing = collection_items(:coffee_shop_hot_cup)
    duplicate = CollectionItem.new(
      collection: existing.collection,
      product: existing.product
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:product_id], "has already been taken"
  end

  test "same product can be in different collections" do
    product = products(:hot_cup_8oz)
    item1 = CollectionItem.new(collection: collections(:coffee_shop), product: product)
    item2 = CollectionItem.new(collection: collections(:restaurant), product: product)

    assert item1.valid?
    item1.save!
    assert item2.valid?
  end
end
```

**Step 2: Create fixtures**

```yaml
# test/fixtures/collection_items.yml
coffee_shop_hot_cup:
  collection: coffee_shop
  product: hot_cup_8oz
  position: 1

coffee_shop_lid:
  collection: coffee_shop
  product: hot_cup_lid
  position: 2

coffee_shop_napkin:
  collection: coffee_shop
  product: napkin
  position: 3

sample_pack_hot_cup:
  collection: coffee_shop_samples
  product: hot_cup_8oz
  position: 1

sample_pack_lid:
  collection: coffee_shop_samples
  product: hot_cup_lid
  position: 2
```

**Step 3: Run test to verify it fails**

Run: `rails test test/models/collection_item_test.rb`
Expected: FAIL with "uninitialized constant CollectionItem"

**Step 4: Write the model**

```ruby
# app/models/collection_item.rb
class CollectionItem < ApplicationRecord
  belongs_to :collection
  belongs_to :product

  acts_as_list scope: :collection

  validates :product_id, uniqueness: { scope: :collection_id }
end
```

**Step 5: Run test to verify it passes**

Run: `rails test test/models/collection_item_test.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add app/models/collection_item.rb test/models/collection_item_test.rb test/fixtures/collection_items.yml
git commit -m "feat: add CollectionItem join model

- links Collection to Product (many-to-many)
- position scoped to collection via acts_as_list
- validates product uniqueness within collection"
```

---

### Task 5: Add Product Association

**Files:**
- Modify: `app/models/product.rb`
- Modify: `test/models/collection_test.rb`

**Step 1: Write failing test for association**

Add to `test/models/collection_test.rb`:

```ruby
test "has many products through collection_items" do
  collection = collections(:coffee_shop)
  assert_respond_to collection, :products
  assert_kind_of ActiveRecord::Associations::CollectionProxy, collection.products
end

test "products are ordered by position" do
  collection = collections(:coffee_shop)
  positions = collection.collection_items.pluck(:position)
  assert_equal positions.sort, positions
end
```

**Step 2: Run test to verify it fails**

Run: `rails test test/models/collection_test.rb`
Expected: Tests should pass (association already defined in Collection model)

**Step 3: Add reverse association to Product model**

Find the associations section in `app/models/product.rb` and add:

```ruby
has_many :collection_items, dependent: :destroy
has_many :collections, through: :collection_items
```

**Step 4: Run all model tests**

Run: `rails test test/models/`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add app/models/product.rb test/models/collection_test.rb
git commit -m "feat: add collections association to Product

- Product can belong to many collections
- destroys collection_items when product deleted"
```

---

## Phase 2: Public Collection Pages

### Task 6: Create Collections Controller with Tests

**Files:**
- Create: `test/controllers/collections_controller_test.rb`
- Create: `app/controllers/collections_controller.rb`

**Step 1: Write failing controller test**

```ruby
# test/controllers/collections_controller_test.rb
require "test_helper"

class CollectionsControllerTest < ActionDispatch::IntegrationTest
  test "show displays collection" do
    collection = collections(:coffee_shop)
    get collection_path(collection)

    assert_response :success
    assert_select "h1", collection.name
  end

  test "show displays collection products" do
    collection = collections(:coffee_shop)
    get collection_path(collection)

    assert_response :success
    collection.products.each do |product|
      assert_select "[data-product-id='#{product.id}']"
    end
  end

  test "show returns 404 for missing collection" do
    get collection_path(id: "nonexistent")
    assert_response :not_found
  end

  test "show excludes sample_pack collections" do
    sample_pack = collections(:coffee_shop_samples)
    get collection_path(sample_pack)
    assert_response :not_found
  end

  test "index displays featured collections" do
    get collections_path

    assert_response :success
    assert_select ".collection-card", minimum: 1
  end
end
```

**Step 2: Run test to verify it fails**

Run: `rails test test/controllers/collections_controller_test.rb`
Expected: FAIL with routing error

**Step 3: Add routes**

In `config/routes.rb`, add after the categories resource:

```ruby
resources :collections, only: [:index, :show]
```

**Step 4: Run test again**

Run: `rails test test/controllers/collections_controller_test.rb`
Expected: FAIL with "uninitialized constant CollectionsController"

**Step 5: Create the controller**

```ruby
# app/controllers/collections_controller.rb
class CollectionsController < ApplicationController
  allow_unauthenticated_access

  def index
    @collections = Collection.browsable.featured.order(:position)
  end

  def show
    @collection = Collection.browsable.find_by!(slug: params[:id])
    @products = @collection.products
                           .active
                           .catalog_products
                           .includes(:category)
                           .with_attached_product_photo
                           .order("collection_items.position")
  rescue ActiveRecord::RecordNotFound
    raise ActionController::RoutingError, "Not Found"
  end
end
```

**Step 6: Run test to verify it passes**

Run: `rails test test/controllers/collections_controller_test.rb`
Expected: FAIL (missing template) - this is expected, views are next task

**Step 7: Commit**

```bash
git add app/controllers/collections_controller.rb test/controllers/collections_controller_test.rb config/routes.rb
git commit -m "feat: add CollectionsController

- index shows featured browsable collections
- show displays collection with products
- excludes sample_pack collections from public view
- uses slug-based lookup"
```

---

### Task 7: Create Collection Show View

**Files:**
- Create: `app/views/collections/show.html.erb`
- Create: `app/helpers/collections_helper.rb`

**Step 1: Create the helper**

```ruby
# app/helpers/collections_helper.rb
module CollectionsHelper
  def collection_structured_data(collection)
    {
      "@context": "https://schema.org",
      "@type": "CollectionPage",
      "name": collection.name,
      "description": collection.description || collection.meta_description,
      "url": collection_url(collection)
    }.to_json
  end
end
```

**Step 2: Create the view**

```erb
<%# app/views/collections/show.html.erb %>

<% content_for :title, @collection.meta_title.presence || "#{@collection.name} | Afida" %>
<% content_for :meta_description, @collection.meta_description.presence || @collection.description&.truncate(160) %>

<% content_for :head do %>
  <script type="application/ld+json">
    <%= raw collection_structured_data(@collection) %>
  </script>
  <%= breadcrumb_structured_data([
    { name: "Home", url: root_url },
    { name: "Collections", url: collections_url },
    { name: @collection.name, url: collection_url(@collection) }
  ]).html_safe %>
<% end %>

<%= render "shared/breadcrumbs", breadcrumbs: [
  { name: "Collections", path: collections_path },
  { name: @collection.name }
] %>

<div class="mb-8">
  <h1 class="text-3xl font-bold mb-4"><%= @collection.name %></h1>
  <% if @collection.description.present? %>
    <p class="text-lg text-base-content/70 max-w-3xl"><%= @collection.description %></p>
  <% end %>
</div>

<% if @products.any? %>
  <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 md:gap-6">
    <% @products.each do |product| %>
      <%= render "products/card", product: product %>
    <% end %>
  </div>
<% else %>
  <div class="text-center py-12">
    <p class="text-base-content/60">No products in this collection yet.</p>
  </div>
<% end %>

<div class="mt-12">
  <%= link_to "Browse All Products", shop_path, class: "btn btn-outline" %>
</div>
```

**Step 3: Run controller tests**

Run: `rails test test/controllers/collections_controller_test.rb`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add app/views/collections/show.html.erb app/helpers/collections_helper.rb
git commit -m "feat: add collection show view

- SEO meta tags and structured data
- breadcrumb navigation
- product grid using existing card partial
- responsive 2/3/4 column layout"
```

---

### Task 8: Create Collection Index View

**Files:**
- Create: `app/views/collections/index.html.erb`
- Create: `app/views/collections/_card.html.erb`

**Step 1: Create the card partial**

```erb
<%# app/views/collections/_card.html.erb %>

<%= link_to collection_path(collection),
    class: "collection-card card bg-base-100 shadow-sm hover:shadow-md transition-shadow",
    data: { collection_id: collection.id } do %>
  <% if collection.image.attached? %>
    <figure class="aspect-[4/3]">
      <%= image_tag collection.image, class: "w-full h-full object-cover" %>
    </figure>
  <% else %>
    <figure class="aspect-[4/3] bg-base-200 flex items-center justify-center">
      <svg class="w-12 h-12 text-base-content/20" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
      </svg>
    </figure>
  <% end %>
  <div class="card-body">
    <h2 class="card-title text-lg"><%= collection.name %></h2>
    <% if collection.description.present? %>
      <p class="text-sm text-base-content/70 line-clamp-2"><%= collection.description %></p>
    <% end %>
    <div class="card-actions justify-end mt-2">
      <span class="text-sm text-primary">View Collection &rarr;</span>
    </div>
  </div>
<% end %>
```

**Step 2: Create the index view**

```erb
<%# app/views/collections/index.html.erb %>

<% content_for :title, "Collections | Afida" %>
<% content_for :meta_description, "Browse our curated collections of eco-friendly catering supplies for coffee shops, restaurants, and events." %>

<%= render "shared/breadcrumbs", breadcrumbs: [
  { name: "Collections" }
] %>

<div class="mb-8">
  <h1 class="text-3xl font-bold mb-4">Collections</h1>
  <p class="text-lg text-base-content/70 max-w-3xl">
    Curated product selections for your business type. Find everything you need in one place.
  </p>
</div>

<% if @collections.any? %>
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
    <% @collections.each do |collection| %>
      <%= render "collections/card", collection: collection %>
    <% end %>
  </div>
<% else %>
  <div class="text-center py-12">
    <p class="text-base-content/60">No collections available yet.</p>
  </div>
<% end %>
```

**Step 3: Run controller tests**

Run: `rails test test/controllers/collections_controller_test.rb`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add app/views/collections/index.html.erb app/views/collections/_card.html.erb
git commit -m "feat: add collection index view

- grid of collection cards
- card shows image, name, description
- responsive 1/2/3 column layout"
```

---

## Phase 3: Admin Collection Management

### Task 9: Create Admin Collections Controller

**Files:**
- Create: `test/controllers/admin/collections_controller_test.rb`
- Create: `app/controllers/admin/collections_controller.rb`

**Step 1: Write failing controller test**

```ruby
# test/controllers/admin/collections_controller_test.rb
require "test_helper"

class Admin::CollectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @collection = collections(:coffee_shop)
  end

  test "index lists all collections" do
    get admin_collections_path
    assert_response :success
    assert_select "table tbody tr", minimum: 1
  end

  test "new renders form" do
    get new_admin_collection_path
    assert_response :success
    assert_select "form"
  end

  test "create saves valid collection" do
    assert_difference("Collection.count", 1) do
      post admin_collections_path, params: {
        collection: {
          name: "New Collection",
          slug: "new-collection",
          description: "A new test collection"
        }
      }
    end
    assert_redirected_to admin_collections_path
  end

  test "create rejects invalid collection" do
    assert_no_difference("Collection.count") do
      post admin_collections_path, params: {
        collection: { name: "", slug: "" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "edit renders form" do
    get edit_admin_collection_path(@collection)
    assert_response :success
    assert_select "form"
  end

  test "update saves changes" do
    patch admin_collection_path(@collection), params: {
      collection: { name: "Updated Name" }
    }
    assert_redirected_to admin_collections_path
    @collection.reload
    assert_equal "Updated Name", @collection.name
  end

  test "destroy removes collection" do
    assert_difference("Collection.count", -1) do
      delete admin_collection_path(@collection)
    end
    assert_redirected_to admin_collections_path
  end
end
```

**Step 2: Run test to verify it fails**

Run: `rails test test/controllers/admin/collections_controller_test.rb`
Expected: FAIL with routing error

**Step 3: Add admin routes**

In `config/routes.rb`, inside the `namespace :admin` block, add:

```ruby
resources :collections do
  collection { get :order }
  member do
    patch :move_higher
    patch :move_lower
  end
end
```

**Step 4: Create the controller**

```ruby
# app/controllers/admin/collections_controller.rb
module Admin
  class CollectionsController < ApplicationController
    before_action :set_collection, only: [:show, :edit, :update, :destroy, :move_higher, :move_lower]

    def index
      @collections = Collection.order(:position)
    end

    def order
      @collections = Collection.order(:position)
    end

    def new
      @collection = Collection.new
    end

    def create
      @collection = Collection.new(collection_params)
      if @collection.save
        redirect_to admin_collections_path, notice: "Collection created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @collection.update(collection_params)
        redirect_to admin_collections_path, notice: "Collection updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @collection.destroy
      redirect_to admin_collections_path, notice: "Collection deleted."
    end

    def move_higher
      @collection.move_higher
      redirect_to order_admin_collections_path
    end

    def move_lower
      @collection.move_lower
      redirect_to order_admin_collections_path
    end

    private

    def set_collection
      @collection = Collection.find_by!(slug: params[:id])
    end

    def collection_params
      params.expect(collection: [
        :name, :slug, :description, :meta_title, :meta_description,
        :featured, :sample_pack, :image
      ])
    end
  end
end
```

**Step 5: Run test**

Run: `rails test test/controllers/admin/collections_controller_test.rb`
Expected: FAIL (missing template) - views are next

**Step 6: Commit**

```bash
git add app/controllers/admin/collections_controller.rb test/controllers/admin/collections_controller_test.rb config/routes.rb
git commit -m "feat: add Admin::CollectionsController

- full CRUD for collections
- move_higher/move_lower for ordering
- slug-based lookup
- strong parameters with params.expect"
```

---

### Task 10: Create Admin Collection Views

**Files:**
- Create: `app/views/admin/collections/index.html.erb`
- Create: `app/views/admin/collections/new.html.erb`
- Create: `app/views/admin/collections/edit.html.erb`
- Create: `app/views/admin/collections/_form.html.erb`
- Create: `app/views/admin/collections/order.html.erb`

**Step 1: Create the form partial**

```erb
<%# app/views/admin/collections/_form.html.erb %>

<%= form_with model: [:admin, @collection], class: "space-y-6" do |f| %>
  <% if @collection.errors.any? %>
    <div class="alert alert-error">
      <ul class="list-disc list-inside">
        <% @collection.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="card bg-base-100 shadow">
    <div class="card-body">
      <h2 class="card-title">Basic Information</h2>

      <div class="form-control">
        <%= f.label :name, class: "label" %>
        <%= f.text_field :name, class: "input input-bordered", required: true %>
      </div>

      <div class="form-control">
        <%= f.label :slug, class: "label" do %>
          <span class="label-text">Slug</span>
          <span class="label-text-alt">URL-friendly identifier (e.g., coffee-shop)</span>
        <% end %>
        <%= f.text_field :slug, class: "input input-bordered", required: true %>
      </div>

      <div class="form-control">
        <%= f.label :description, class: "label" %>
        <%= f.text_area :description, class: "textarea textarea-bordered h-24" %>
      </div>
    </div>
  </div>

  <div class="card bg-base-100 shadow">
    <div class="card-body">
      <h2 class="card-title">SEO</h2>

      <div class="form-control">
        <%= f.label :meta_title, class: "label" do %>
          <span class="label-text">Meta Title</span>
          <span class="label-text-alt">50-60 characters recommended</span>
        <% end %>
        <%= f.text_field :meta_title, class: "input input-bordered" %>
      </div>

      <div class="form-control">
        <%= f.label :meta_description, class: "label" do %>
          <span class="label-text">Meta Description</span>
          <span class="label-text-alt">150-160 characters recommended</span>
        <% end %>
        <%= f.text_area :meta_description, class: "textarea textarea-bordered h-20" %>
      </div>
    </div>
  </div>

  <div class="card bg-base-100 shadow">
    <div class="card-body">
      <h2 class="card-title">Settings</h2>

      <div class="form-control">
        <label class="label cursor-pointer justify-start gap-4">
          <%= f.check_box :featured, class: "toggle toggle-primary" %>
          <span class="label-text">Featured (show on collections index)</span>
        </label>
      </div>

      <div class="form-control">
        <label class="label cursor-pointer justify-start gap-4">
          <%= f.check_box :sample_pack, class: "toggle toggle-secondary" %>
          <span class="label-text">Sample Pack (curated samples for this audience)</span>
        </label>
      </div>
    </div>
  </div>

  <div class="card bg-base-100 shadow">
    <div class="card-body">
      <h2 class="card-title">Image</h2>

      <% if @collection.image.attached? %>
        <div class="mb-4">
          <%= image_tag @collection.image, class: "w-48 h-32 object-cover rounded" %>
        </div>
      <% end %>

      <div class="form-control">
        <%= f.file_field :image, class: "file-input file-input-bordered w-full max-w-xs",
            accept: "image/jpeg,image/png,image/webp" %>
        <label class="label">
          <span class="label-text-alt">JPG, PNG, or WebP. Recommended size: 800x600</span>
        </label>
      </div>
    </div>
  </div>

  <div class="flex gap-4">
    <%= f.submit class: "btn btn-primary" %>
    <%= link_to "Cancel", admin_collections_path, class: "btn btn-ghost" %>
  </div>
<% end %>
```

**Step 2: Create new view**

```erb
<%# app/views/admin/collections/new.html.erb %>

<div class="max-w-2xl mx-auto">
  <h1 class="text-2xl font-bold mb-6">New Collection</h1>
  <%= render "form" %>
</div>
```

**Step 3: Create edit view**

```erb
<%# app/views/admin/collections/edit.html.erb %>

<div class="max-w-2xl mx-auto">
  <h1 class="text-2xl font-bold mb-6">Edit Collection: <%= @collection.name %></h1>
  <%= render "form" %>
</div>
```

**Step 4: Create index view**

```erb
<%# app/views/admin/collections/index.html.erb %>

<div class="flex justify-between items-center mb-6">
  <h1 class="text-2xl font-bold">Collections</h1>
  <div class="flex gap-2">
    <%= link_to "Reorder", order_admin_collections_path, class: "btn btn-ghost btn-sm" %>
    <%= link_to "New Collection", new_admin_collection_path, class: "btn btn-primary btn-sm" %>
  </div>
</div>

<div class="overflow-x-auto">
  <table class="table">
    <thead>
      <tr>
        <th>Name</th>
        <th>Slug</th>
        <th>Products</th>
        <th>Featured</th>
        <th>Sample Pack</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      <% @collections.each do |collection| %>
        <tr>
          <td class="font-medium"><%= collection.name %></td>
          <td class="text-sm text-base-content/60"><%= collection.slug %></td>
          <td><%= collection.products.count %></td>
          <td>
            <% if collection.featured? %>
              <span class="badge badge-success badge-sm">Yes</span>
            <% end %>
          </td>
          <td>
            <% if collection.sample_pack? %>
              <span class="badge badge-secondary badge-sm">Yes</span>
            <% end %>
          </td>
          <td class="flex gap-2">
            <%= link_to "Edit", edit_admin_collection_path(collection), class: "btn btn-ghost btn-xs" %>
            <%= button_to "Delete", admin_collection_path(collection), method: :delete,
                class: "btn btn-ghost btn-xs text-error",
                data: { turbo_confirm: "Are you sure you want to delete this collection?" } %>
          </td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

**Step 5: Create order view**

```erb
<%# app/views/admin/collections/order.html.erb %>

<div class="max-w-2xl mx-auto">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-2xl font-bold">Reorder Collections</h1>
    <%= link_to "Done", admin_collections_path, class: "btn btn-primary btn-sm" %>
  </div>

  <div class="card bg-base-100 shadow">
    <div class="card-body p-0">
      <ul class="divide-y divide-base-200">
        <% @collections.each do |collection| %>
          <li class="flex items-center justify-between p-4">
            <span class="font-medium"><%= collection.name %></span>
            <div class="flex gap-1">
              <%= button_to "↑", move_higher_admin_collection_path(collection),
                  method: :patch, class: "btn btn-ghost btn-sm",
                  disabled: collection.first? %>
              <%= button_to "↓", move_lower_admin_collection_path(collection),
                  method: :patch, class: "btn btn-ghost btn-sm",
                  disabled: collection.last? %>
            </div>
          </li>
        <% end %>
      </ul>
    </div>
  </div>
</div>
```

**Step 6: Run controller tests**

Run: `rails test test/controllers/admin/collections_controller_test.rb`
Expected: All tests PASS

**Step 7: Commit**

```bash
git add app/views/admin/collections/
git commit -m "feat: add admin collection views

- index with table listing all collections
- new/edit forms with all fields
- order page for reordering via position
- DaisyUI components throughout"
```

---

### Task 11: Add Collection Products Management

**Files:**
- Modify: `app/controllers/admin/collections_controller.rb`
- Modify: `app/views/admin/collections/_form.html.erb`
- Create: `app/views/admin/collections/_product_selector.html.erb`

**Step 1: Add product_ids to permitted params**

In `app/controllers/admin/collections_controller.rb`, update `collection_params`:

```ruby
def collection_params
  params.expect(collection: [
    :name, :slug, :description, :meta_title, :meta_description,
    :featured, :sample_pack, :image, product_ids: []
  ])
end
```

**Step 2: Create product selector partial**

```erb
<%# app/views/admin/collections/_product_selector.html.erb %>

<div class="card bg-base-100 shadow">
  <div class="card-body">
    <h2 class="card-title">Products in Collection</h2>
    <p class="text-sm text-base-content/60 mb-4">
      Select products to include in this collection. Products can belong to multiple collections.
    </p>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-2 max-h-96 overflow-y-auto">
      <% Category.order(:position).each do |category| %>
        <% products = category.products.active.catalog_products.order(:name) %>
        <% next if products.empty? %>

        <div class="col-span-full font-medium text-sm mt-2 first:mt-0 bg-base-200 px-2 py-1 rounded">
          <%= category.name %>
        </div>

        <% products.each do |product| %>
          <label class="flex items-center gap-2 p-2 hover:bg-base-200 rounded cursor-pointer">
            <%= check_box_tag "collection[product_ids][]", product.id,
                @collection.product_ids.include?(product.id),
                class: "checkbox checkbox-sm checkbox-primary" %>
            <span class="text-sm"><%= product.name %></span>
          </label>
        <% end %>
      <% end %>
    </div>

    <%# Hidden field to ensure empty array is submitted when no products selected %>
    <%= hidden_field_tag "collection[product_ids][]", "" %>
  </div>
</div>
```

**Step 3: Add product selector to form**

In `app/views/admin/collections/_form.html.erb`, add before the submit buttons:

```erb
<%= render "product_selector" %>
```

**Step 4: Test manually in browser**

Run: `bin/dev`
Navigate to: `/admin/collections/new`
Expected: See product selector with checkboxes grouped by category

**Step 5: Commit**

```bash
git add app/controllers/admin/collections_controller.rb app/views/admin/collections/_form.html.erb app/views/admin/collections/_product_selector.html.erb
git commit -m "feat: add product selection to collection admin

- checkbox grid grouped by category
- scrollable container for many products
- products can be in multiple collections"
```

---

## Phase 4: Curated Sample Packs

### Task 12: Add Sample Pack Routes and Controller

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/samples_controller.rb`
- Create: `test/controllers/samples_controller_packs_test.rb`

**Step 1: Write failing test**

```ruby
# test/controllers/samples_controller_packs_test.rb
require "test_helper"

class SamplesControllerPacksTest < ActionDispatch::IntegrationTest
  test "pack shows curated sample pack" do
    pack = collections(:coffee_shop_samples)
    get samples_pack_path(pack.slug)

    assert_response :success
    assert_select "h1", /#{pack.name}/
  end

  test "pack only shows sample-eligible products" do
    pack = collections(:coffee_shop_samples)
    get samples_pack_path(pack.slug)

    assert_response :success
    pack.products.sample_eligible.each do |product|
      assert_select "[data-product-id='#{product.id}']"
    end
  end

  test "pack returns 404 for non-sample-pack collections" do
    collection = collections(:coffee_shop) # not a sample pack
    get samples_pack_path(collection.slug)

    assert_response :not_found
  end

  test "add_pack adds all pack products as samples" do
    pack = collections(:coffee_shop_samples)

    assert_difference("Current.cart.sample_count", pack.products.sample_eligible.count) do
      post samples_add_pack_path(pack.slug)
    end

    assert_redirected_to cart_path
  end
end
```

**Step 2: Add routes**

In `config/routes.rb`, update samples routes:

```ruby
resources :samples, only: [:index] do
  collection do
    get ":category_slug", action: :category, as: :category
    get "pack/:slug", action: :pack, as: :pack
    post "pack/:slug/add", action: :add_pack, as: :add_pack
  end
end
```

**Step 3: Add controller actions**

In `app/controllers/samples_controller.rb`, add:

```ruby
def pack
  @pack = Collection.sample_packs.find_by!(slug: params[:slug])
  @products = @pack.products
                   .active
                   .sample_eligible
                   .catalog_products
                   .with_attached_product_photo
                   .order("collection_items.position")
rescue ActiveRecord::RecordNotFound
  raise ActionController::RoutingError, "Not Found"
end

def add_pack
  @pack = Collection.sample_packs.find_by!(slug: params[:slug])
  @products = @pack.products.active.sample_eligible.catalog_products

  added_count = 0
  @products.each do |product|
    break if Current.cart.at_sample_limit?

    existing = Current.cart.cart_items.find_by(product: product)
    next if existing # Skip if already in cart (sample or regular)

    Current.cart.cart_items.create(product: product, quantity: 1, price: 0, is_sample: true)
    added_count += 1
  end

  redirect_to cart_path, notice: "Added #{added_count} samples to your cart."
rescue ActiveRecord::RecordNotFound
  raise ActionController::RoutingError, "Not Found"
end
```

**Step 4: Run tests**

Run: `rails test test/controllers/samples_controller_packs_test.rb`
Expected: FAIL (missing template for pack action)

**Step 5: Commit**

```bash
git add config/routes.rb app/controllers/samples_controller.rb test/controllers/samples_controller_packs_test.rb
git commit -m "feat: add sample pack routes and controller actions

- pack action shows curated sample pack
- add_pack adds all eligible products as samples
- respects sample limit (5 max)
- skips products already in cart"
```

---

### Task 13: Create Sample Pack View

**Files:**
- Create: `app/views/samples/pack.html.erb`

**Step 1: Create the view**

```erb
<%# app/views/samples/pack.html.erb %>

<% content_for :title, "#{@pack.name} | Free Samples | Afida" %>
<% content_for :meta_description, @pack.description || "Try our curated #{@pack.name.downcase} with free samples." %>

<%= render "shared/breadcrumbs", breadcrumbs: [
  { name: "Samples", path: samples_path },
  { name: @pack.name }
] %>

<div class="mb-8">
  <h1 class="text-3xl font-bold mb-4"><%= @pack.name %></h1>
  <% if @pack.description.present? %>
    <p class="text-lg text-base-content/70 max-w-3xl mb-6"><%= @pack.description %></p>
  <% end %>

  <div class="flex flex-wrap gap-4 items-center">
    <%= button_to "Add All to Cart", samples_add_pack_path(@pack.slug),
        method: :post,
        class: "btn btn-primary",
        disabled: Current.cart.at_sample_limit?,
        data: { turbo: false } %>

    <span class="text-sm text-base-content/60">
      <%= @products.count %> products in this pack
      <% if Current.cart.at_sample_limit? %>
        <span class="text-warning">(Sample limit reached)</span>
      <% end %>
    </span>
  </div>
</div>

<% if @products.any? %>
  <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 md:gap-6">
    <% @products.each do |product| %>
      <div data-product-id="<%= product.id %>">
        <%= render "samples/product_card", product: product %>
      </div>
    <% end %>
  </div>
<% else %>
  <div class="text-center py-12">
    <p class="text-base-content/60">No sample-eligible products in this pack.</p>
  </div>
<% end %>

<div class="mt-12 pt-8 border-t border-base-200">
  <h2 class="text-xl font-bold mb-4">Or Browse All Samples</h2>
  <%= link_to "View All Samples", samples_path, class: "btn btn-outline" %>
</div>
```

**Step 2: Run tests**

Run: `rails test test/controllers/samples_controller_packs_test.rb`
Expected: All tests PASS

**Step 3: Commit**

```bash
git add app/views/samples/pack.html.erb
git commit -m "feat: add sample pack view

- shows all products in curated pack
- 'Add All to Cart' button
- respects sample limit
- link to browse all samples"
```

---

### Task 14: Add Sample Packs to Samples Index

**Files:**
- Modify: `app/views/samples/index.html.erb`
- Modify: `app/controllers/samples_controller.rb`

**Step 1: Load sample packs in controller**

In `app/controllers/samples_controller.rb`, update `index`:

```ruby
def index
  @categories = Category.joins(:products)
                        .where(products: { active: true, sample_eligible: true, product_type: "standard" })
                        .distinct
                        .order(:position)
  @sample_packs = Collection.sample_packs.order(:position)
end
```

**Step 2: Add sample packs section to view**

At the top of `app/views/samples/index.html.erb`, after the header, add:

```erb
<% if @sample_packs.any? %>
  <div class="mb-12">
    <h2 class="text-xl font-bold mb-4">Curated Sample Packs</h2>
    <p class="text-base-content/70 mb-6">
      Not sure where to start? Try one of our curated sample packs.
    </p>

    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <% @sample_packs.each do |pack| %>
        <%= link_to samples_pack_path(pack.slug),
            class: "card bg-base-100 shadow-sm hover:shadow-md transition-shadow" do %>
          <div class="card-body">
            <h3 class="card-title text-lg"><%= pack.name %></h3>
            <% if pack.description.present? %>
              <p class="text-sm text-base-content/70 line-clamp-2"><%= pack.description %></p>
            <% end %>
            <div class="card-actions justify-between items-center mt-2">
              <span class="text-xs text-base-content/50">
                <%= pack.products.sample_eligible.count %> products
              </span>
              <span class="text-sm text-primary">View Pack &rarr;</span>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
  </div>

  <div class="divider">Or Browse by Category</div>
<% end %>
```

**Step 3: Test manually**

Run: `bin/dev`
Navigate to: `/samples`
Expected: See sample packs section above categories (if any sample packs exist)

**Step 4: Commit**

```bash
git add app/controllers/samples_controller.rb app/views/samples/index.html.erb
git commit -m "feat: show sample packs on samples index

- curated packs displayed above category browser
- shows product count per pack
- links to dedicated pack page"
```

---

## Phase 5: Navigation Integration

### Task 15: Add Collections to Navigation

**Files:**
- Modify: `app/views/shared/_navbar.html.erb` or `app/views/shared/_category_nav.html.erb`

**Step 1: Identify navigation file**

Check which file handles main navigation. Likely `_category_nav.html.erb` or a dropdown in `_navbar.html.erb`.

**Step 2: Add collections link**

Add to the appropriate navigation section:

```erb
<% if Collection.browsable.featured.any? %>
  <div class="dropdown dropdown-hover">
    <%= link_to "Collections", collections_path, class: "btn btn-ghost" %>
    <ul class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-52">
      <% Collection.browsable.featured.order(:position).limit(6).each do |collection| %>
        <li><%= link_to collection.name, collection_path(collection) %></li>
      <% end %>
      <li class="border-t border-base-200 mt-2 pt-2">
        <%= link_to "View All Collections", collections_path, class: "text-primary" %>
      </li>
    </ul>
  </div>
<% end %>
```

**Step 3: Test manually**

Run: `bin/dev`
Check: Navigation should show Collections dropdown

**Step 4: Commit**

```bash
git add app/views/shared/
git commit -m "feat: add collections to site navigation

- dropdown with featured collections
- link to full collections index"
```

---

### Task 16: Add Admin Navigation Link

**Files:**
- Modify: `app/views/layouts/admin.html.erb` or `app/views/admin/shared/_sidebar.html.erb`

**Step 1: Find admin navigation**

Look for admin layout or sidebar partial.

**Step 2: Add collections link**

Add to admin navigation:

```erb
<%= link_to "Collections", admin_collections_path,
    class: "flex items-center gap-2 px-4 py-2 hover:bg-base-200 rounded" %>
```

**Step 3: Commit**

```bash
git add app/views/layouts/admin.html.erb app/views/admin/shared/
git commit -m "feat: add collections to admin navigation"
```

---

## Phase 6: Final Polish

### Task 17: Add System Tests

**Files:**
- Create: `test/system/collections_test.rb`

**Step 1: Write system tests**

```ruby
# test/system/collections_test.rb
require "application_system_test_case"

class CollectionsTest < ApplicationSystemTestCase
  test "visiting collections index" do
    visit collections_path

    assert_selector "h1", text: "Collections"
  end

  test "viewing a collection" do
    collection = collections(:coffee_shop)
    visit collection_path(collection)

    assert_selector "h1", text: collection.name
  end

  test "browsing sample pack" do
    pack = collections(:coffee_shop_samples)
    visit samples_pack_path(pack.slug)

    assert_selector "h1", text: pack.name
    assert_selector "button", text: "Add All to Cart"
  end
end
```

**Step 2: Run system tests**

Run: `rails test:system`
Expected: All tests PASS

**Step 3: Commit**

```bash
git add test/system/collections_test.rb
git commit -m "test: add system tests for collections

- collections index browsing
- individual collection viewing
- sample pack browsing"
```

---

### Task 18: Update Seeds (Optional)

**Files:**
- Modify: `db/seeds.rb`

**Step 1: Add collection seeds**

```ruby
# Collections
puts "Creating collections..."

coffee_shop = Collection.find_or_create_by!(slug: "coffee-shop") do |c|
  c.name = "Coffee Shop Essentials"
  c.description = "Everything your café needs for takeaway drinks and snacks."
  c.featured = true
  c.sample_pack = false
end

restaurant = Collection.find_or_create_by!(slug: "restaurant") do |c|
  c.name = "Restaurant Collection"
  c.description = "Takeaway containers, cutlery, and napkins for restaurants."
  c.featured = true
  c.sample_pack = false
end

# Sample Packs
coffee_samples = Collection.find_or_create_by!(slug: "coffee-shop-samples") do |c|
  c.name = "Coffee Shop Sample Pack"
  c.description = "Try our most popular café products - cups, lids, and napkins."
  c.featured = false
  c.sample_pack = true
end

# Add products to collections (adjust product references as needed)
# coffee_shop.products << Product.where(category: Category.find_by(slug: "hot-cups"))
```

**Step 2: Commit**

```bash
git add db/seeds.rb
git commit -m "chore: add collection seeds

- Coffee Shop Essentials collection
- Restaurant Collection
- Coffee Shop Sample Pack"
```

---

## Summary

This plan implements:

1. **Collection model** with many-to-many product relationships
2. **Public collection pages** with SEO and structured data
3. **Admin CRUD** for managing collections and their products
4. **Curated Sample Packs** integrated with existing samples flow
5. **Navigation** updates for both public and admin areas
6. **Tests** at unit, controller, and system levels

**Total Tasks:** 18
**Estimated Time:** 2-3 days for experienced developer

**Key Patterns Followed:**
- Fixtures over factories (per CLAUDE.md)
- Slug-based URLs for SEO
- DaisyUI components throughout
- acts_as_list for ordering
- Turbo-compatible forms
- Strong params with `params.expect`
