---
type: Plan
description: Implementation plan for a product configuration system with organizations, product options, branded product pricing, and customer product instances for reordering.
status: shipped
timestamp: 2025-10-22
---

# Product Configuration System Implementation Plan

> **For Claude:** Use `${SUPERPOWERS_SKILLS_ROOT}/skills/collaboration/executing-plans/SKILL.md` to implement this plan task-by-task.

**Goal:** Build a comprehensive product configuration system supporting standard products with options (size, color) and customizable B2B products (branded cups) with organization support, pricing matrices, design uploads, and customer product instances for reordering.

**Architecture:** Product Options system for all products + Branded Product templates that generate customer-specific product instances after manufacturing. Organizations own customized products and team members can reorder. Uses TDD throughout with RED-GREEN-REFACTOR cycles.

**Tech Stack:** Rails 8, PostgreSQL, Hotwire (Turbo + Stimulus), Active Storage, Vite, TailwindCSS 4, DaisyUI

---

## Phase 1: Foundation - Organizations & Product Options

### Task 1: Create Organization model

**Files:**
- Create: `app/models/organization.rb`
- Create: `test/models/organization_test.rb`
- Create: `test/fixtures/organizations.yml`
- Create migration: `db/migrate/XXXXXX_create_organizations.rb`

**Step 1: Write the failing test**

In `test/models/organization_test.rb`:
```ruby
require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "valid organization" do
    organization = Organization.new(
      name: "ACME Coffee",
      billing_email: "billing@acme.com"
    )
    assert organization.valid?
  end

  test "requires name" do
    organization = Organization.new(billing_email: "test@example.com")
    assert_not organization.valid?
    assert_includes organization.errors[:name], "can't be blank"
  end

  test "requires billing_email" do
    organization = Organization.new(name: "Test Org")
    assert_not organization.valid?
    assert_includes organization.errors[:billing_email], "can't be blank"
  end

  test "validates email format" do
    organization = organizations(:acme)
    organization.billing_email = "invalid"
    assert_not organization.valid?
    assert_includes organization.errors[:billing_email], "is invalid"
  end
end
```

**Step 2: Create fixture**

In `test/fixtures/organizations.yml`:
```yaml
acme:
  name: ACME Coffee
  billing_email: billing@acme.com
  phone: "+44 20 1234 5678"
  default_shipping_address:
    street: "123 High Street"
    city: "London"
    postcode: "SW1A 1AA"
    country: "GB"

bobs_bakery:
  name: Bob's Bakery
  billing_email: bob@bobsbakery.com
  phone: "+44 161 234 5678"
```

**Step 3: Run test to verify it fails**

Run: `rails test test/models/organization_test.rb`
Expected: FAIL with "uninitialized constant Organization"

**Step 4: Create migration**

Run: `rails generate migration CreateOrganizations name:string billing_email:string phone:string default_shipping_address:jsonb`

Edit the generated migration:
```ruby
class CreateOrganizations < ActiveRecord::Migration[8.0]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :billing_email, null: false
      t.string :phone
      t.jsonb :default_shipping_address, default: {}

      t.timestamps
    end

    add_index :organizations, :billing_email
  end
end
```

**Step 5: Run migration**

Run: `rails db:migrate`

**Step 6: Create model**

In `app/models/organization.rb`:
```ruby
class Organization < ApplicationRecord
  has_many :users, dependent: :restrict_with_error
  has_many :customized_products, -> { where(product_type: "customized_instance") },
           class_name: "Product",
           foreign_key: :organization_id,
           dependent: :restrict_with_error

  validates :name, presence: true
  validates :billing_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  def owner
    users.find_by(role: "owner")
  end
end
```

**Step 7: Run tests to verify they pass**

Run: `rails test test/models/organization_test.rb`
Expected: PASS (4 tests, 7 assertions)

**Step 8: Commit**

```bash
git add .
git commit -m "Add Organization model

- Create organizations table with name, billing_email, phone, shipping address
- Validates name and email presence and format
- Associations: has_many users, has_many customized_products
- Fixtures for testing

Tests: 4 tests, 7 assertions, 0 failures"
```

---

### Task 2: Add organization_id and role to Users

**Files:**
- Modify: `app/models/user.rb`
- Modify: `test/models/user_test.rb`
- Modify: `test/fixtures/users.yml`
- Create migration: `db/migrate/XXXXXX_add_organization_to_users.rb`

**Step 1: Write the failing tests**

Add to `test/models/user_test.rb`:
```ruby
  test "user can belong to organization" do
    user = users(:acme_owner)
    assert_equal organizations(:acme), user.organization
  end

  test "user with organization must have role" do
    user = User.new(
      email: "test@example.com",
      password: "password123",
      organization: organizations(:acme),
      role: nil
    )
    assert_not user.valid?
    assert_includes user.errors[:role], "can't be blank"
  end

  test "user without organization can have nil role" do
    user = User.new(
      email: "consumer@example.com",
      password: "password123",
      organization: nil,
      role: nil
    )
    assert user.valid?
  end

  test "valid roles are owner, admin, member" do
    user = users(:acme_owner)

    user.role = "owner"
    assert user.valid?

    user.role = "admin"
    assert user.valid?

    user.role = "member"
    assert user.valid?

    user.role = "invalid"
    assert_not user.valid?
  end

  test "organization can have only one owner" do
    # First owner is valid
    owner1 = User.create!(
      email: "owner1@acme.com",
      password: "password123",
      organization: organizations(:acme),
      role: "owner"
    )

    # Second owner should fail
    owner2 = User.new(
      email: "owner2@acme.com",
      password: "password123",
      organization: organizations(:acme),
      role: "owner"
    )
    assert_not owner2.valid?
    assert_includes owner2.errors[:role], "organization already has an owner"
  end
```

**Step 2: Update fixtures**

Add to `test/fixtures/users.yml`:
```yaml
acme_owner:
  email: owner@acme.com
  organization: acme
  role: owner

acme_admin:
  email: admin@acme.com
  organization: acme
  role: admin

acme_member:
  email: member@acme.com
  organization: acme
  role: member

bobs_owner:
  email: bob@bobsbakery.com
  organization: bobs_bakery
  role: owner

consumer:
  email: consumer@example.com
  organization:
  role:
```

**Step 3: Run tests to verify they fail**

Run: `rails test test/models/user_test.rb`
Expected: FAIL (organization column doesn't exist)

**Step 4: Create migration**

Run: `rails generate migration AddOrganizationToUsers organization:references role:string`

Edit migration:
```ruby
class AddOrganizationToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :organization, foreign_key: true
    add_column :users, :role, :string

    add_index :users, [:organization_id, :role]
  end
end
```

**Step 5: Run migration**

Run: `rails db:migrate`

**Step 6: Update User model**

In `app/models/user.rb`, add:
```ruby
  belongs_to :organization, optional: true

  enum :role, { owner: "owner", admin: "admin", member: "member" }, validate: true

  validates :role, presence: true, if: :organization_id?
  validate :organization_has_one_owner, if: -> { organization_id? && role == "owner" }

  private

  def organization_has_one_owner
    return unless organization

    existing_owner = organization.users.where(role: "owner").where.not(id: id).exists?
    if existing_owner
      errors.add(:role, "organization already has an owner")
    end
  end
```

**Step 7: Run tests to verify they pass**

Run: `rails test test/models/user_test.rb`
Expected: PASS

**Step 8: Commit**

```bash
git add .
git commit -m "Add organization and role to User model

- Add organization_id foreign key and role column
- Validates role presence when user has organization
- Validates only one owner per organization
- Enum for roles: owner, admin, member
- Individual consumers have no organization/role

Tests: All user tests passing"
```

---

### Task 3: Create ProductOption model

**Files:**
- Create: `app/models/product_option.rb`
- Create: `test/models/product_option_test.rb`
- Create: `test/fixtures/product_options.yml`
- Create migration: `db/migrate/XXXXXX_create_product_options.rb`

**Step 1: Write the failing test**

In `test/models/product_option_test.rb`:
```ruby
require "test_helper"

class ProductOptionTest < ActiveSupport::TestCase
  test "valid product option" do
    option = ProductOption.new(
      name: "Size",
      display_type: "dropdown",
      required: true,
      position: 1
    )
    assert option.valid?
  end

  test "requires name" do
    option = ProductOption.new(display_type: "dropdown")
    assert_not option.valid?
    assert_includes option.errors[:name], "can't be blank"
  end

  test "requires display_type" do
    option = ProductOption.new(name: "Size")
    assert_not option.valid?
    assert_includes option.errors[:display_type], "can't be blank"
  end

  test "validates display_type values" do
    option = product_options(:size)

    option.display_type = "dropdown"
    assert option.valid?

    option.display_type = "radio"
    assert option.valid?

    option.display_type = "swatch"
    assert option.valid?

    option.display_type = "invalid"
    assert_not option.valid?
  end

  test "has many values" do
    option = product_options(:size)
    assert_includes option.values.map(&:value), "8oz"
    assert_includes option.values.map(&:value), "12oz"
  end

  test "required defaults to true" do
    option = ProductOption.create!(name: "Test", display_type: "dropdown")
    assert option.required?
  end
end
```

**Step 2: Create fixtures**

In `test/fixtures/product_options.yml`:
```yaml
size:
  name: Size
  display_type: dropdown
  required: true
  position: 1

color:
  name: Color
  display_type: swatch
  required: true
  position: 2

material:
  name: Material
  display_type: radio
  required: false
  position: 3
```

**Step 3: Run test to verify it fails**

Run: `rails test test/models/product_option_test.rb`
Expected: FAIL with "uninitialized constant ProductOption"

**Step 4: Create migration**

Run: `rails generate migration CreateProductOptions name:string display_type:string required:boolean position:integer`

Edit migration:
```ruby
class CreateProductOptions < ActiveRecord::Migration[8.0]
  def change
    create_table :product_options do |t|
      t.string :name, null: false
      t.string :display_type, null: false
      t.boolean :required, default: true, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :product_options, :position
  end
end
```

**Step 5: Run migration**

Run: `rails db:migrate`

**Step 6: Create model**

In `app/models/product_option.rb`:
```ruby
class ProductOption < ApplicationRecord
  has_many :values, -> { order(:position) },
           class_name: "ProductOptionValue",
           dependent: :destroy
  has_many :assignments, class_name: "ProductOptionAssignment", dependent: :destroy
  has_many :products, through: :assignments

  enum :display_type, { dropdown: "dropdown", radio: "radio", swatch: "swatch" }, validate: true

  validates :name, presence: true
  validates :display_type, presence: true

  default_scope { order(:position) }
end
```

**Step 7: Run tests to verify they pass**

Run: `rails test test/models/product_option_test.rb`
Expected: PASS (6 tests)

**Step 8: Commit**

```bash
git add .
git commit -m "Add ProductOption model

- Create product_options table with name, display_type, required, position
- Enum for display_type: dropdown, radio, swatch
- Has many values (ProductOptionValue)
- Has many products through assignments
- Default scope orders by position

Tests: 6 tests passing"
```

---

### Task 4: Create ProductOptionValue model

**Files:**
- Create: `app/models/product_option_value.rb`
- Create: `test/models/product_option_value_test.rb`
- Create: `test/fixtures/product_option_values.yml`
- Create migration: `db/migrate/XXXXXX_create_product_option_values.rb`

**Step 1: Write the failing test**

In `test/models/product_option_value_test.rb`:
```ruby
require "test_helper"

class ProductOptionValueTest < ActiveSupport::TestCase
  test "valid product option value" do
    value = ProductOptionValue.new(
      product_option: product_options(:size),
      value: "20oz",
      position: 4
    )
    assert value.valid?
  end

  test "requires product_option" do
    value = ProductOptionValue.new(value: "Test")
    assert_not value.valid?
    assert_includes value.errors[:product_option], "must exist"
  end

  test "requires value" do
    value = ProductOptionValue.new(product_option: product_options(:size))
    assert_not value.valid?
    assert_includes value.errors[:value], "can't be blank"
  end

  test "belongs to product option" do
    value = product_option_values(:size_8oz)
    assert_equal product_options(:size), value.product_option
  end

  test "unique value per option" do
    duplicate = ProductOptionValue.new(
      product_option: product_options(:size),
      value: "8oz"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:value], "has already been taken"
  end

  test "same value allowed for different options" do
    # "Small" can exist for both Size and Color (hypothetically)
    value1 = ProductOptionValue.create!(
      product_option: product_options(:size),
      value: "Small"
    )
    value2 = ProductOptionValue.new(
      product_option: product_options(:color),
      value: "Small"
    )
    assert value2.valid?
  end
end
```

**Step 2: Create fixtures**

In `test/fixtures/product_option_values.yml`:
```yaml
size_8oz:
  product_option: size
  value: 8oz
  position: 1

size_12oz:
  product_option: size
  value: 12oz
  position: 2

size_16oz:
  product_option: size
  value: 16oz
  position: 3

color_white:
  product_option: color
  value: White
  position: 1

color_black:
  product_option: color
  value: Black
  position: 2

material_recyclable:
  product_option: material
  value: Recyclable
  position: 1

material_compostable:
  product_option: material
  value: Compostable
  position: 2
```

**Step 3: Run test to verify it fails**

Run: `rails test test/models/product_option_value_test.rb`
Expected: FAIL

**Step 4: Create migration**

Run: `rails generate migration CreateProductOptionValues product_option:references value:string position:integer`

Edit migration:
```ruby
class CreateProductOptionValues < ActiveRecord::Migration[8.0]
  def change
    create_table :product_option_values do |t|
      t.references :product_option, null: false, foreign_key: true
      t.string :value, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :product_option_values, [:product_option_id, :value], unique: true
    add_index :product_option_values, :position
  end
end
```

**Step 5: Run migration**

Run: `rails db:migrate`

**Step 6: Create model**

In `app/models/product_option_value.rb`:
```ruby
class ProductOptionValue < ApplicationRecord
  belongs_to :product_option

  validates :value, presence: true, uniqueness: { scope: :product_option_id }

  default_scope { order(:position) }
end
```

**Step 7: Run tests to verify they pass**

Run: `rails test test/models/product_option_value_test.rb`
Expected: PASS (6 tests)

**Step 8: Commit**

```bash
git add .
git commit -m "Add ProductOptionValue model

- Create product_option_values table
- Belongs to ProductOption
- Validates value presence and uniqueness per option
- Default scope orders by position

Tests: 6 tests passing"
```

---

### Task 5: Create ProductOptionAssignment join model

**Files:**
- Create: `app/models/product_option_assignment.rb`
- Create: `test/models/product_option_assignment_test.rb`
- Create: `test/fixtures/product_option_assignments.yml`
- Create migration: `db/migrate/XXXXXX_create_product_option_assignments.rb`

**Step 1: Write the failing test**

In `test/models/product_option_assignment_test.rb`:
```ruby
require "test_helper"

class ProductOptionAssignmentTest < ActiveSupport::TestCase
  test "valid assignment" do
    assignment = ProductOptionAssignment.new(
      product: products(:single_wall_cups),
      product_option: product_options(:size),
      position: 1
    )
    assert assignment.valid?
  end

  test "requires product" do
    assignment = ProductOptionAssignment.new(product_option: product_options(:size))
    assert_not assignment.valid?
    assert_includes assignment.errors[:product], "must exist"
  end

  test "requires product_option" do
    assignment = ProductOptionAssignment.new(product: products(:single_wall_cups))
    assert_not assignment.valid?
    assert_includes assignment.errors[:product_option], "must exist"
  end

  test "unique product_option per product" do
    duplicate = ProductOptionAssignment.new(
      product: products(:single_wall_cups),
      product_option: product_options(:size)
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:product_option_id], "has already been taken"
  end

  test "same option can be assigned to different products" do
    assignment = ProductOptionAssignment.create!(
      product: products(:double_wall_cups),
      product_option: product_options(:size)
    )
    assert assignment.persisted?
  end
end
```

**Step 2: Create fixtures**

In `test/fixtures/product_option_assignments.yml`:
```yaml
single_wall_cups_size:
  product: single_wall_cups
  product_option: size
  position: 1

single_wall_cups_color:
  product: single_wall_cups
  product_option: color
  position: 2
```

**Step 3: Run test to verify it fails**

Run: `rails test test/models/product_option_assignment_test.rb`
Expected: FAIL

**Step 4: Create migration**

Run: `rails generate migration CreateProductOptionAssignments product:references product_option:references position:integer`

Edit migration:
```ruby
class CreateProductOptionAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :product_option_assignments do |t|
      t.references :product, null: false, foreign_key: true
      t.references :product_option, null: false, foreign_key: true
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :product_option_assignments, [:product_id, :product_option_id],
              unique: true,
              name: "index_product_option_assignments_uniqueness"
  end
end
```

**Step 5: Run migration**

Run: `rails db:migrate`

**Step 6: Create model**

In `app/models/product_option_assignment.rb`:
```ruby
class ProductOptionAssignment < ApplicationRecord
  belongs_to :product
  belongs_to :product_option

  validates :product_option_id, uniqueness: { scope: :product_id }

  default_scope { order(:position) }
end
```

**Step 7: Run tests to verify they pass**

Run: `rails test test/models/product_option_assignment_test.rb`
Expected: PASS (5 tests)

**Step 8: Commit**

```bash
git add .
git commit -m "Add ProductOptionAssignment join model

- Links products to product_options
- Validates uniqueness per product
- Tracks position for display order

Tests: 5 tests passing"
```

---

## Phase 2: Product Model Enhancements

### Task 6: Add product_type and organization_id to Product

**Files:**
- Modify: `app/models/product.rb`
- Modify: `test/models/product_test.rb`
- Modify: `test/fixtures/products.yml`
- Create migration: `db/migrate/XXXXXX_add_product_configuration_fields.rb`

**Step 1: Write the failing tests**

Add to `test/models/product_test.rb`:
```ruby
  test "product types are standard, customizable_template, customized_instance" do
    product = products(:single_wall_cups)

    product.product_type = "standard"
    assert product.valid?

    product.product_type = "customizable_template"
    assert product.valid?

    product.product_type = "customized_instance"
    assert product.valid?

    product.product_type = "invalid"
    assert_not product.valid?
  end

  test "customized_instance requires parent_product_id" do
    product = Product.new(
      name: "Test Instance",
      product_type: "customized_instance",
      parent_product_id: nil
    )
    assert_not product.valid?
    assert_includes product.errors[:parent_product_id], "can't be blank"
  end

  test "customized_instance requires organization_id" do
    product = Product.new(
      name: "Test Instance",
      product_type: "customized_instance",
      parent_product_id: products(:branded_double_wall_template).id,
      organization_id: nil
    )
    assert_not product.valid?
    assert_includes product.errors[:organization_id], "can't be blank"
  end

  test "customized_instance stores configuration_data" do
    product = products(:acme_branded_cups)
    assert_equal "12oz", product.configuration_data["size"]
    assert_equal "double_wall", product.configuration_data["type"]
    assert_equal 5000, product.configuration_data["quantity_ordered"]
  end

  test "standard and template products dont require parent or organization" do
    product = Product.new(
      name: "Test",
      product_type: "standard",
      category: categories(:cups)
    )
    assert product.valid?
  end

  test "product has many option assignments" do
    product = products(:single_wall_cups)
    assert_includes product.option_assignments.map(&:product_option), product_options(:size)
  end

  test "product has many options through assignments" do
    product = products(:single_wall_cups)
    assert_includes product.options, product_options(:size)
    assert_includes product.options, product_options(:color)
  end

  test "belongs to organization for customized instances" do
    product = products(:acme_branded_cups)
    assert_equal organizations(:acme), product.organization
  end

  test "belongs to parent product for customized instances" do
    product = products(:acme_branded_cups)
    assert_equal products(:branded_double_wall_template), product.parent_product
  end
```

**Step 2: Update fixtures**

Add to `test/fixtures/products.yml`:
```yaml
single_wall_cups:
  name: Single-Wall Cups
  slug: single-wall-cups
  category: cups
  active: true
  sort_order: 1
  product_type: standard

branded_double_wall_template:
  name: Double Wall Branded Cups
  slug: double-wall-branded-cups
  category: branded
  active: true
  sort_order: 1
  product_type: customizable_template
  description: Custom branded double-wall cups for your business

acme_branded_cups:
  name: ACME Coffee 12oz Double Wall Branded Cups
  slug: acme-coffee-12oz-double-wall-branded-cups
  category: branded
  active: true
  product_type: customized_instance
  parent_product: branded_double_wall_template
  organization: acme
  configuration_data:
    size: "12oz"
    type: "double_wall"
    quantity_ordered: 5000
    design_url: "https://example.com/designs/acme-logo.pdf"
```

**Step 3: Run tests to verify they fail**

Run: `rails test test/models/product_test.rb`
Expected: FAIL

**Step 4: Create migration**

Run: `rails generate migration AddProductConfigurationFields`

Edit migration:
```ruby
class AddProductConfigurationFields < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :product_type, :string, default: "standard", null: false
    add_reference :products, :parent_product, foreign_key: { to_table: :products }
    add_reference :products, :organization, foreign_key: true
    add_column :products, :configuration_data, :jsonb, default: {}

    add_index :products, :product_type
    add_index :products, [:organization_id, :product_type]
  end
end
```

**Step 5: Run migration**

Run: `rails db:migrate`

**Step 6: Update Product model**

In `app/models/product.rb`, add:
```ruby
  belongs_to :organization, optional: true
  belongs_to :parent_product, class_name: "Product", optional: true
  has_many :customized_instances, class_name: "Product", foreign_key: :parent_product_id

  has_many :option_assignments, class_name: "ProductOptionAssignment", dependent: :destroy
  has_many :options, through: :option_assignments, source: :product_option

  enum :product_type, {
    standard: "standard",
    customizable_template: "customizable_template",
    customized_instance: "customized_instance"
  }, validate: true

  validates :parent_product_id, presence: true, if: :customized_instance?
  validates :organization_id, presence: true, if: :customized_instance?

  # Update default scope to exclude customized instances from main catalog
  default_scope { where(active: true).order(:sort_order) }

  scope :catalog_products, -> { where(product_type: ["standard", "customizable_template"]) }
  scope :customized_for_organization, ->(org) { unscoped.where(product_type: "customized_instance", organization: org) }
```

**Step 7: Run tests to verify they pass**

Run: `rails test test/models/product_test.rb`
Expected: PASS

**Step 8: Commit**

```bash
git add .
git commit -m "Add product configuration fields to Product model

- Add product_type enum: standard, customizable_template, customized_instance
- Add parent_product_id for instances
- Add organization_id for customized instances
- Add configuration_data jsonb for storing instance config
- Add option_assignments and options associations
- Update default scope to handle all product types

Tests: All product tests passing"
```

---

### Task 7: Add option_values to ProductVariant

**Files:**
- Modify: `app/models/product_variant.rb`
- Modify: `test/models/product_variant_test.rb`
- Modify: `test/fixtures/product_variants.yml`
- Create migration: `db/migrate/XXXXXX_add_option_values_to_product_variants.rb`

**Step 1: Write the failing tests**

Add to `test/models/product_variant_test.rb`:
```ruby
  test "variant stores option values as jsonb" do
    variant = product_variants(:single_wall_8oz_white)
    assert_equal "8oz", variant.option_values["size"]
    assert_equal "White", variant.option_values["color"]
  end

  test "variant can retrieve option value for specific option" do
    variant = product_variants(:single_wall_8oz_white)
    assert_equal "8oz", variant.option_value_for("size")
    assert_equal "White", variant.option_value_for("color")
  end

  test "variant display name includes option values" do
    variant = product_variants(:single_wall_8oz_white)
    assert_equal "8oz White", variant.options_display
  end

  test "variant without option values returns empty hash" do
    variant = ProductVariant.create!(
      product: products(:branded_double_wall_template),
      sku: "TEST-SKU",
      price: 100,
      stock: 0
    )
    assert_equal({}, variant.option_values)
  end
```

**Step 2: Update fixtures**

Update `test/fixtures/product_variants.yml`:
```yaml
single_wall_8oz_white:
  product: single_wall_cups
  sku: CUP-SW-8-WHT
  price: 26.00
  stock: 1000
  option_values:
    size: "8oz"
    color: "White"

single_wall_12oz_white:
  product: single_wall_cups
  sku: CUP-SW-12-WHT
  price: 28.00
  stock: 1000
  option_values:
    size: "12oz"
    color: "White"

single_wall_8oz_black:
  product: single_wall_cups
  sku: CUP-SW-8-BLK
  price: 26.00
  stock: 500
  option_values:
    size: "8oz"
    color: "Black"

acme_cups_variant:
  product: acme_branded_cups
  sku: BRANDED-ACME-12DW-001
  price: 900.00
  stock: 5000
  option_values: {}
```

**Step 3: Run tests to verify they fail**

Run: `rails test test/models/product_variant_test.rb`
Expected: FAIL

**Step 4: Create migration**

Run: `rails generate migration AddOptionValuesToProductVariants option_values:jsonb`

Edit migration:
```ruby
class AddOptionValuesToProductVariants < ActiveRecord::Migration[8.0]
  def change
    add_column :product_variants, :option_values, :jsonb, default: {}

    add_index :product_variants, :option_values, using: :gin
  end
end
```

**Step 5: Run migration**

Run: `rails db:migrate`

**Step 6: Update ProductVariant model**

In `app/models/product_variant.rb`, add:
```ruby
  def option_value_for(option_name)
    option_values[option_name]
  end

  def options_display
    option_values.values.join(" ")
  end
```

**Step 7: Run tests to verify they pass**

Run: `rails test test/models/product_variant_test.rb`
Expected: PASS

**Step 8: Commit**

```bash
git add .
git commit -m "Add option_values to ProductVariant

- Add option_values jsonb column with GIN index
- Store selected option values as hash (size: 8oz, color: White)
- Add helper methods for option access and display
- Update fixtures with option values

Tests: All variant tests passing"
```

---

## Phase 3: Branded Product Pricing

### Task 8: Create BrandedProductPrice model

**Files:**
- Create: `app/models/branded_product_price.rb`
- Create: `test/models/branded_product_price_test.rb`
- Create: `test/fixtures/branded_product_prices.yml`
- Create migration: `db/migrate/XXXXXX_create_branded_product_prices.rb`

**Step 1: Write the failing test**

In `test/models/branded_product_price_test.rb`:
```ruby
require "test_helper"

class BrandedProductPriceTest < ActiveSupport::TestCase
  test "valid branded product price" do
    price = BrandedProductPrice.new(
      product: products(:branded_double_wall_template),
      size: "8oz",
      quantity_tier: 1000,
      price_per_unit: 0.30,
      case_quantity: 500
    )
    assert price.valid?
  end

  test "requires product" do
    price = BrandedProductPrice.new(
      size: "8oz",
      quantity_tier: 1000,
      price_per_unit: 0.30
    )
    assert_not price.valid?
    assert_includes price.errors[:product], "must exist"
  end

  test "requires size" do
    price = BrandedProductPrice.new(
      product: products(:branded_double_wall_template),
      quantity_tier: 1000,
      price_per_unit: 0.30
    )
    assert_not price.valid?
    assert_includes price.errors[:size], "can't be blank"
  end

  test "requires quantity_tier" do
    price = BrandedProductPrice.new(
      product: products(:branded_double_wall_template),
      size: "8oz",
      price_per_unit: 0.30
    )
    assert_not price.valid?
    assert_includes price.errors[:quantity_tier], "can't be blank"
  end

  test "requires price_per_unit" do
    price = BrandedProductPrice.new(
      product: products(:branded_double_wall_template),
      size: "8oz",
      quantity_tier: 1000
    )
    assert_not price.valid?
    assert_includes price.errors[:price_per_unit], "can't be blank"
  end

  test "price_per_unit must be positive" do
    price = branded_product_prices(:dw_8oz_1000)
    price.price_per_unit = -0.10
    assert_not price.valid?
    assert_includes price.errors[:price_per_unit], "must be greater than 0"
  end

  test "quantity_tier must be positive" do
    price = branded_product_prices(:dw_8oz_1000)
    price.quantity_tier = -100
    assert_not price.valid?
    assert_includes price.errors[:quantity_tier], "must be greater than 0"
  end

  test "unique combination of product, size, and quantity_tier" do
    duplicate = BrandedProductPrice.new(
      product: products(:branded_double_wall_template),
      size: "8oz",
      quantity_tier: 1000,
      price_per_unit: 0.25
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:quantity_tier], "has already been taken"
  end

  test "calculates total price" do
    price = branded_product_prices(:dw_8oz_1000)
    expected = price.price_per_unit * price.quantity_tier
    assert_equal expected, price.total_price
  end

  test "find price for configuration" do
    price = BrandedProductPrice.find_for_configuration(
      products(:branded_double_wall_template),
      "8oz",
      1000
    )
    assert_equal branded_product_prices(:dw_8oz_1000), price
  end

  test "find price returns nil for invalid configuration" do
    price = BrandedProductPrice.find_for_configuration(
      products(:branded_double_wall_template),
      "99oz",
      1000
    )
    assert_nil price
  end
end
```

**Step 2: Create fixtures**

In `test/fixtures/branded_product_prices.yml`:
```yaml
# Double Wall 8oz pricing
dw_8oz_1000:
  product: branded_double_wall_template
  size: 8oz
  quantity_tier: 1000
  price_per_unit: 0.30
  case_quantity: 500

dw_8oz_2000:
  product: branded_double_wall_template
  size: 8oz
  quantity_tier: 2000
  price_per_unit: 0.25
  case_quantity: 500

dw_8oz_5000:
  product: branded_double_wall_template
  size: 8oz
  quantity_tier: 5000
  price_per_unit: 0.18
  case_quantity: 500

# Double Wall 12oz pricing
dw_12oz_1000:
  product: branded_double_wall_template
  size: 12oz
  quantity_tier: 1000
  price_per_unit: 0.32
  case_quantity: 500

dw_12oz_5000:
  product: branded_double_wall_template
  size: 12oz
  quantity_tier: 5000
  price_per_unit: 0.20
  case_quantity: 500

# Double Wall 16oz pricing
dw_16oz_1000:
  product: branded_double_wall_template
  size: 16oz
  quantity_tier: 1000
  price_per_unit: 0.34
  case_quantity: 500
```

**Step 3: Run test to verify it fails**

Run: `rails test test/models/branded_product_price_test.rb`
Expected: FAIL

**Step 4: Create migration**

Run: `rails generate migration CreateBrandedProductPrices product:references size:string quantity_tier:integer price_per_unit:decimal case_quantity:integer`

Edit migration:
```ruby
class CreateBrandedProductPrices < ActiveRecord::Migration[8.0]
  def change
    create_table :branded_product_prices do |t|
      t.references :product, null: false, foreign_key: true
      t.string :size, null: false
      t.integer :quantity_tier, null: false
      t.decimal :price_per_unit, precision: 10, scale: 4, null: false
      t.integer :case_quantity, null: false

      t.timestamps
    end

    add_index :branded_product_prices, [:product_id, :size, :quantity_tier],
              unique: true,
              name: "index_branded_prices_uniqueness"
  end
end
```

**Step 5: Run migration**

Run: `rails db:migrate`

**Step 6: Create model**

In `app/models/branded_product_price.rb`:
```ruby
class BrandedProductPrice < ApplicationRecord
  belongs_to :product

  validates :size, presence: true
  validates :quantity_tier, presence: true,
            numericality: { only_integer: true, greater_than: 0 },
            uniqueness: { scope: [:product_id, :size] }
  validates :price_per_unit, presence: true,
            numericality: { greater_than: 0 }
  validates :case_quantity, presence: true,
            numericality: { only_integer: true, greater_than: 0 }

  def total_price
    price_per_unit * quantity_tier
  end

  def self.find_for_configuration(product, size, quantity)
    where(product: product, size: size)
      .where("quantity_tier <= ?", quantity)
      .order(quantity_tier: :desc)
      .first
  end
end
```

**Step 7: Run tests to verify they pass**

Run: `rails test test/models/branded_product_price_test.rb`
Expected: PASS (10 tests)

**Step 8: Commit**

```bash
git add .
git commit -m "Add BrandedProductPrice model

- Store pricing matrix for customizable products
- Indexed on product_id, size, quantity_tier (unique)
- Validates all fields, positive values
- Class method to find price for configuration
- Total price calculation helper

Tests: 10 tests passing"
```

---

### Task 9: Create BrandedProductPricingService

**Files:**
- Create: `app/services/branded_product_pricing_service.rb`
- Create: `test/services/branded_product_pricing_service_test.rb`

**Step 1: Write the failing test**

In `test/services/branded_product_pricing_service_test.rb`:
```ruby
require "test_helper"

class BrandedProductPricingServiceTest < ActiveSupport::TestCase
  setup do
    @product = products(:branded_double_wall_template)
    @service = BrandedProductPricingService.new(@product)
  end

  test "calculates price for valid configuration" do
    result = @service.calculate(size: "8oz", quantity: 1000)

    assert result.success?
    assert_equal 0.30, result.price_per_unit
    assert_equal 300.00, result.total_price
    assert_equal 1000, result.quantity
  end

  test "uses correct tier pricing based on quantity" do
    # 1500 units should use 1000 tier pricing
    result = @service.calculate(size: "8oz", quantity: 1500)

    assert result.success?
    assert_equal 0.30, result.price_per_unit # 1000 tier
    assert_equal 450.00, result.total_price # 1500 * 0.30
  end

  test "uses higher tier when quantity exceeds threshold" do
    result = @service.calculate(size: "8oz", quantity: 5000)

    assert result.success?
    assert_equal 0.18, result.price_per_unit # 5000 tier
    assert_equal 900.00, result.total_price
  end

  test "returns error for invalid size" do
    result = @service.calculate(size: "99oz", quantity: 1000)

    assert_not result.success?
    assert_equal "No pricing found for this configuration", result.error
  end

  test "returns error for quantity below minimum" do
    result = @service.calculate(size: "8oz", quantity: 500)

    assert_not result.success?
    assert_equal "Quantity below minimum order", result.error
  end

  test "returns error for missing parameters" do
    result = @service.calculate(size: nil, quantity: 1000)

    assert_not result.success?
    assert_includes result.error, "required"
  end

  test "includes case quantity in result" do
    result = @service.calculate(size: "8oz", quantity: 1000)

    assert result.success?
    assert_equal 500, result.case_quantity
  end

  test "calculates number of cases needed" do
    result = @service.calculate(size: "8oz", quantity: 1000)

    assert result.success?
    assert_equal 2, result.cases_needed # 1000 / 500 = 2
  end

  test "available sizes returns all sizes for product" do
    sizes = @service.available_sizes

    assert_includes sizes, "8oz"
    assert_includes sizes, "12oz"
    assert_includes sizes, "16oz"
  end

  test "available quantities returns all tiers for size" do
    quantities = @service.available_quantities("8oz")

    assert_includes quantities, 1000
    assert_includes quantities, 2000
    assert_includes quantities, 5000
  end
end
```

**Step 2: Run test to verify it fails**

Run: `rails test test/services/branded_product_pricing_service_test.rb`
Expected: FAIL

**Step 3: Create the service**

In `app/services/branded_product_pricing_service.rb`:
```ruby
class BrandedProductPricingService
  Result = Struct.new(:success, :price_per_unit, :total_price, :quantity, :case_quantity, :cases_needed, :error, keyword_init: true) do
    def success?
      success
    end
  end

  MINIMUM_ORDER_QUANTITY = 1000

  def initialize(product)
    @product = product
  end

  def calculate(size:, quantity:)
    return error_result("Size and quantity are required") if size.blank? || quantity.blank?
    return error_result("Quantity below minimum order") if quantity < MINIMUM_ORDER_QUANTITY

    pricing = BrandedProductPrice.find_for_configuration(@product, size, quantity)
    return error_result("No pricing found for this configuration") unless pricing

    Result.new(
      success: true,
      price_per_unit: pricing.price_per_unit,
      total_price: pricing.price_per_unit * quantity,
      quantity: quantity,
      case_quantity: pricing.case_quantity,
      cases_needed: (quantity.to_f / pricing.case_quantity).ceil
    )
  end

  def available_sizes
    @product.branded_product_prices.distinct.pluck(:size).sort
  end

  def available_quantities(size)
    @product.branded_product_prices
            .where(size: size)
            .pluck(:quantity_tier)
            .sort
  end

  private

  def error_result(message)
    Result.new(success: false, error: message)
  end
end
```

**Step 4: Add association to Product model**

In `app/models/product.rb`, add:
```ruby
  has_many :branded_product_prices, dependent: :destroy
```

**Step 5: Run tests to verify they pass**

Run: `rails test test/services/branded_product_pricing_service_test.rb`
Expected: PASS (11 tests)

**Step 6: Commit**

```bash
git add .
git commit -m "Add BrandedProductPricingService

- Calculate pricing for branded product configurations
- Tier-based pricing (uses highest applicable tier)
- Minimum order quantity validation
- Returns success/error results with pricing details
- Helper methods for available sizes and quantities

Tests: 11 tests passing"
```

---

## Phase 4: Cart & Order Updates

### Task 10: Add configuration and design to CartItem

**Files:**
- Modify: `app/models/cart_item.rb`
- Modify: `test/models/cart_item_test.rb`
- Modify: `test/fixtures/cart_items.yml`
- Create migration: `db/migrate/XXXXXX_add_configuration_to_cart_items.rb`

**Step 1: Write the failing tests**

Add to `test/models/cart_item_test.rb`:
```ruby
  test "cart item can store configuration for customizable products" do
    cart_item = cart_items(:branded_configuration)
    assert_equal "12oz", cart_item.configuration["size"]
    assert_equal 5000, cart_item.configuration["quantity"]
  end

  test "cart item with configuration uses calculated_price" do
    cart_item = cart_items(:branded_configuration)
    assert_equal 900.00, cart_item.calculated_price
    assert_equal 900.00, cart_item.line_total
  end

  test "cart item without configuration uses variant price" do
    cart_item = cart_items(:cart_one_item_one)
    expected = cart_item.variant.price * cart_item.quantity
    assert_equal expected, cart_item.line_total
  end

  test "cart item unit price for configured product" do
    cart_item = cart_items(:branded_configuration)
    expected = cart_item.calculated_price / cart_item.configuration["quantity"]
    assert_equal expected, cart_item.unit_price
  end

  test "cart item unit price for standard product" do
    cart_item = cart_items(:cart_one_item_one)
    assert_equal cart_item.variant.price, cart_item.unit_price
  end

  test "configured cart item validates calculated_price presence" do
    cart_item = CartItem.new(
      cart: carts(:cart_one),
      product: products(:branded_double_wall_template),
      quantity: 1,
      configuration: { size: "8oz", quantity: 1000 },
      calculated_price: nil
    )
    assert_not cart_item.valid?
    assert_includes cart_item.errors[:calculated_price], "can't be blank"
  end

  test "cart item can have design attachment" do
    cart_item = cart_items(:branded_configuration)
    # We'll attach actual file in integration test
    assert_respond_to cart_item, :design
  end
```

**Step 2: Update fixtures**

Add to `test/fixtures/cart_items.yml`:
```yaml
branded_configuration:
  cart: cart_one
  product: branded_double_wall_template
  quantity: 1
  configuration:
    size: "12oz"
    quantity: 5000
  calculated_price: 900.00
```

**Step 3: Run tests to verify they fail**

Run: `rails test test/models/cart_item_test.rb`
Expected: FAIL

**Step 4: Create migration**

Run: `rails generate migration AddConfigurationToCartItems configuration:jsonb calculated_price:decimal`

Edit migration:
```ruby
class AddConfigurationToCartItems < ActiveRecord::Migration[8.0]
  def change
    add_column :cart_items, :configuration, :jsonb, default: {}
    add_column :cart_items, :calculated_price, :decimal, precision: 10, scale: 2

    add_index :cart_items, :configuration, using: :gin
  end
end
```

**Step 5: Run migration**

Run: `rails db:migrate`

**Step 6: Update CartItem model**

In `app/models/cart_item.rb`:
```ruby
  has_one_attached :design

  validates :calculated_price, presence: true, if: -> { configuration.present? }

  def unit_price
    if configuration.present?
      calculated_price / configuration["quantity"]
    else
      variant.price
    end
  end

  def line_total
    if configuration.present?
      calculated_price
    else
      variant.price * quantity
    end
  end

  def configured?
    configuration.present?
  end
```

**Step 7: Run tests to verify they pass**

Run: `rails test test/models/cart_item_test.rb`
Expected: PASS

**Step 8: Commit**

```bash
git add .
git commit -m "Add configuration support to CartItem

- Add configuration jsonb column for product options
- Add calculated_price for configured products
- Add design attachment via Active Storage
- Update unit_price and line_total to handle both types
- Validates calculated_price when configuration present

Tests: All cart item tests passing"
```

---

### Task 11: Add organization_id to Order

**Files:**
- Modify: `app/models/order.rb`
- Modify: `test/models/order_test.rb`
- Modify: `test/fixtures/orders.yml`
- Create migration: `db/migrate/XXXXXX_add_organization_to_orders.rb`

**Step 1: Write the failing tests**

Add to `test/models/order_test.rb`:
```ruby
  test "order can belong to organization" do
    order = orders(:acme_order)
    assert_equal organizations(:acme), order.organization
  end

  test "order tracks which user placed it" do
    order = orders(:acme_order)
    assert_equal users(:acme_admin), order.placed_by_user
  end

  test "B2B order has both organization and placed_by" do
    order = Order.create!(
      user: users(:acme_admin),
      organization: organizations(:acme),
      placed_by_user: users(:acme_admin),
      stripe_session_id: "test_session_123",
      total_amount: 1000,
      subtotal_amount: 833.33,
      vat_amount: 166.67,
      shipping_amount: 0,
      status: "pending"
    )
    assert order.persisted?
    assert order.b2b_order?
  end

  test "consumer order has no organization" do
    order = orders(:one)
    assert_nil order.organization_id
    assert_not order.b2b_order?
  end

  test "organization orders scope" do
    org_orders = Order.for_organization(organizations(:acme))
    assert_includes org_orders, orders(:acme_order)
    assert_not_includes org_orders, orders(:one)
  end
```

**Step 2: Update fixtures**

Add to `test/fixtures/orders.yml`:
```yaml
acme_order:
  user: acme_admin
  organization: acme
  placed_by_user: acme_admin
  stripe_session_id: cs_test_acme_001
  total_amount: 1080.00
  subtotal_amount: 900.00
  vat_amount: 180.00
  shipping_amount: 0.00
  status: completed
  created_at: <%= 2.days.ago %>
```

**Step 3: Run tests to verify they fail**

Run: `rails test test/models/order_test.rb`
Expected: FAIL

**Step 4: Create migration**

Run: `rails generate migration AddOrganizationToOrders organization:references placed_by_user:references`

Edit migration:
```ruby
class AddOrganizationToOrders < ActiveRecord::Migration[8.0]
  def change
    add_reference :orders, :organization, foreign_key: true
    add_reference :orders, :placed_by_user, foreign_key: { to_table: :users }

    add_index :orders, [:organization_id, :created_at]
  end
end
```

**Step 5: Run migration**

Run: `rails db:migrate`

**Step 6: Update Order model**

In `app/models/order.rb`, add:
```ruby
  belongs_to :organization, optional: true
  belongs_to :placed_by_user, class_name: "User", optional: true

  scope :for_organization, ->(org) { where(organization: org) }

  def b2b_order?
    organization_id.present?
  end
```

**Step 7: Run tests to verify they pass**

Run: `rails test test/models/order_test.rb`
Expected: PASS

**Step 8: Commit**

```bash
git add .
git commit -m "Add organization support to Order model

- Add organization_id and placed_by_user_id
- Track which team member placed B2B orders
- Scope for querying organization orders
- Helper method to identify B2B vs consumer orders

Tests: All order tests passing"
```

---

## Phase 5: Branded Product Configurator UI

### Task 12: Create BrandedProducts::ConfiguratorController

**Files:**
- Create: `app/controllers/branded_products/configurator_controller.rb`
- Create: `test/controllers/branded_products/configurator_controller_test.rb`
- Modify: `config/routes.rb`

**Step 1: Write the failing test**

In `test/controllers/branded_products/configurator_controller_test.rb`:
```ruby
require "test_helper"

class BrandedProducts::ConfiguratorControllerTest < ActionDispatch::IntegrationTest
  test "calculate pricing returns success for valid configuration" do
    post branded_products_calculate_price_path, params: {
      product_id: products(:branded_double_wall_template).id,
      size: "8oz",
      quantity: 1000
    }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json["success"]
    assert_equal 0.30, json["price_per_unit"]
    assert_equal 300.00, json["total_price"]
    assert_equal 1000, json["quantity"]
    assert_equal 500, json["case_quantity"]
  end

  test "calculate pricing returns error for invalid size" do
    post branded_products_calculate_price_path, params: {
      product_id: products(:branded_double_wall_template).id,
      size: "99oz",
      quantity: 1000
    }, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)

    assert_not json["success"]
    assert_present json["error"]
  end

  test "calculate pricing returns error for quantity below minimum" do
    post branded_products_calculate_price_path, params: {
      product_id: products(:branded_double_wall_template).id,
      size: "8oz",
      quantity: 500
    }, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)

    assert_not json["success"]
    assert_includes json["error"], "minimum"
  end

  test "calculate pricing requires product_id" do
    post branded_products_calculate_price_path, params: {
      size: "8oz",
      quantity: 1000
    }, as: :json

    assert_response :bad_request
  end

  test "available options returns sizes and quantities" do
    get branded_products_available_options_path(products(:branded_double_wall_template)), as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_includes json["sizes"], "8oz"
    assert_includes json["sizes"], "12oz"
    assert json["quantity_tiers"].is_a?(Hash)
    assert_includes json["quantity_tiers"]["8oz"], 1000
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `rails test test/controllers/branded_products/configurator_controller_test.rb`
Expected: FAIL

**Step 3: Add routes**

In `config/routes.rb`, add:
```ruby
  namespace :branded_products do
    post "calculate_price", to: "configurator#calculate_price"
    get "available_options/:product_id", to: "configurator#available_options", as: :available_options
  end
```

**Step 4: Create controller**

In `app/controllers/branded_products/configurator_controller.rb`:
```ruby
module BrandedProducts
  class ConfiguratorController < ApplicationController
    allow_unauthenticated_access

    def calculate_price
      product = Product.find_by(id: params[:product_id])
      return render json: { success: false, error: "Product not found" }, status: :bad_request unless product

      service = BrandedProductPricingService.new(product)
      result = service.calculate(
        size: params[:size],
        quantity: params[:quantity]&.to_i
      )

      if result.success?
        render json: {
          success: true,
          price_per_unit: result.price_per_unit,
          total_price: result.total_price,
          quantity: result.quantity,
          case_quantity: result.case_quantity,
          cases_needed: result.cases_needed
        }
      else
        render json: {
          success: false,
          error: result.error
        }, status: :unprocessable_entity
      end
    end

    def available_options
      product = Product.find(params[:product_id])
      service = BrandedProductPricingService.new(product)

      sizes = service.available_sizes
      quantity_tiers = {}

      sizes.each do |size|
        quantity_tiers[size] = service.available_quantities(size)
      end

      render json: {
        sizes: sizes,
        quantity_tiers: quantity_tiers
      }
    end
  end
end
```

**Step 5: Run tests to verify they pass**

Run: `rails test test/controllers/branded_products/configurator_controller_test.rb`
Expected: PASS (5 tests)

**Step 6: Commit**

```bash
git add .
git commit -m "Add BrandedProducts::ConfiguratorController

- AJAX endpoint for real-time price calculation
- Returns pricing details based on size and quantity
- Endpoint for fetching available options
- Error handling for invalid configurations

Tests: 5 tests passing"
```

---

### Task 13: Create branded product configurator Stimulus controller

**Files:**
- Create: `app/frontend/javascript/controllers/branded_configurator_controller.js`
- Modify: `app/frontend/javascript/controllers/index.js`

**Step 1: Create the Stimulus controller**

In `app/frontend/javascript/controllers/branded_configurator_controller.js`:
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "sizeOption",
    "quantityOption",
    "pricePerUnit",
    "totalPrice",
    "subtotal",
    "vat",
    "total",
    "addToCartButton",
    "designInput",
    "designPreview",
    "errorMessage"
  ]

  static values = {
    productId: Number,
    vatRate: { type: Number, default: 0.2 }
  }

  connect() {
    this.selectedSize = null
    this.selectedQuantity = null
    this.calculatedPrice = null
    this.updateAddToCartButton()
  }

  selectSize(event) {
    // Remove active class from all size options
    this.sizeOptionTargets.forEach(el => {
      el.classList.remove("btn-primary")
      el.classList.add("btn-outline")
    })

    // Add active class to selected
    event.currentTarget.classList.remove("btn-outline")
    event.currentTarget.classList.add("btn-primary")

    this.selectedSize = event.currentTarget.dataset.size
    this.calculatePrice()
  }

  selectQuantity(event) {
    // Remove active class from all quantity options
    this.quantityOptionTargets.forEach(el => {
      el.classList.remove("card-bordered", "border-primary")
      el.classList.add("border-base-300")
    })

    // Add active class to selected
    event.currentTarget.classList.remove("border-base-300")
    event.currentTarget.classList.add("card-bordered", "border-primary")

    this.selectedQuantity = parseInt(event.currentTarget.dataset.quantity)
    this.calculatePrice()
  }

  async calculatePrice() {
    if (!this.selectedSize || !this.selectedQuantity) {
      return
    }

    try {
      const response = await fetch("/branded_products/calculate_price", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: JSON.stringify({
          product_id: this.productIdValue,
          size: this.selectedSize,
          quantity: this.selectedQuantity
        })
      })

      const data = await response.json()

      if (data.success) {
        this.calculatedPrice = data.total_price
        this.updatePricingDisplay(data)
        this.clearError()
      } else {
        this.showError(data.error)
      }
    } catch (error) {
      this.showError("Failed to calculate price. Please try again.")
    }

    this.updateAddToCartButton()
  }

  updatePricingDisplay(data) {
    // Update price per unit
    if (this.hasPricePerUnitTarget) {
      this.pricePerUnitTarget.textContent = `£${data.price_per_unit.toFixed(2)}`
    }

    // Update subtotal
    const subtotal = data.total_price
    if (this.hasSubtotalTarget) {
      this.subtotalTarget.textContent = `£${subtotal.toFixed(2)}`
    }

    // Update VAT
    const vat = subtotal * this.vatRateValue
    if (this.hasVatTarget) {
      this.vatTarget.textContent = `£${vat.toFixed(2)}`
    }

    // Update total
    const total = subtotal + vat
    if (this.hasTotalTarget) {
      this.totalTarget.textContent = `£${total.toFixed(2)}`
    }

    // Update total price display
    if (this.hasTotalPriceTarget) {
      this.totalPriceTarget.textContent = `£${total.toFixed(2)}`
    }
  }

  handleDesignUpload(event) {
    const file = event.target.files[0]
    if (!file) return

    // Validate file type
    const validTypes = ["application/pdf", "image/png", "image/jpeg", "application/postscript"]
    if (!validTypes.includes(file.type)) {
      this.showError("Please upload a PDF, PNG, JPG, or AI file")
      event.target.value = ""
      return
    }

    // Validate file size (max 10MB)
    const maxSize = 10 * 1024 * 1024
    if (file.size > maxSize) {
      this.showError("File size must be less than 10MB")
      event.target.value = ""
      return
    }

    // Show preview
    if (this.hasDesignPreviewTarget) {
      this.designPreviewTarget.textContent = file.name
      this.designPreviewTarget.classList.remove("hidden")
    }

    this.clearError()
    this.updateAddToCartButton()
  }

  updateAddToCartButton() {
    if (!this.hasAddToCartButtonTarget) return

    const isValid = this.selectedSize &&
                    this.selectedQuantity &&
                    this.calculatedPrice &&
                    this.designInputTarget?.files.length > 0

    this.addToCartButtonTarget.disabled = !isValid

    if (isValid) {
      this.addToCartButtonTarget.classList.remove("btn-disabled")
    } else {
      this.addToCartButtonTarget.classList.add("btn-disabled")
    }
  }

  showError(message) {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = message
      this.errorMessageTarget.classList.remove("hidden")
    }
  }

  clearError() {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.classList.add("hidden")
    }
  }

  async addToCart(event) {
    event.preventDefault()

    if (!this.selectedSize || !this.selectedQuantity || !this.calculatedPrice) {
      this.showError("Please complete all configuration steps")
      return
    }

    const formData = new FormData()
    formData.append("product_id", this.productIdValue)
    formData.append("configuration[size]", this.selectedSize)
    formData.append("configuration[quantity]", this.selectedQuantity)
    formData.append("calculated_price", this.calculatedPrice)

    if (this.designInputTarget.files[0]) {
      formData.append("design", this.designInputTarget.files[0])
    }

    try {
      const response = await fetch("/cart_items", {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: formData
      })

      if (response.ok) {
        // Redirect to cart or show success
        window.location.href = "/cart"
      } else {
        const data = await response.json()
        this.showError(data.error || "Failed to add to cart")
      }
    } catch (error) {
      this.showError("Failed to add to cart. Please try again.")
    }
  }
}
```

**Step 2: Register controller**

Verify `app/frontend/javascript/controllers/index.js` auto-registers controllers (should already be set up with Vite).

**Step 3: Commit**

```bash
git add .
git commit -m "Add branded configurator Stimulus controller

- Handles size and quantity selection
- Real-time AJAX pricing calculation
- Design file upload with validation
- Updates pricing display with VAT
- Enables/disables add to cart based on completion
- Form submission to add configured product to cart

Frontend: Stimulus controller for configurator UI"
```

---

### Task 14: Create branded product configurator view

**Files:**
- Create: `app/views/products/_branded_configurator.html.erb`
- Modify: `app/views/products/show.html.erb`
- Modify: `app/controllers/products_controller.rb`

**Step 1: Create configurator partial**

In `app/views/products/_branded_configurator.html.erb`:
```erb
<div data-controller="branded-configurator"
     data-branded-configurator-product-id-value="<%= @product.id %>"
     data-branded-configurator-vat-rate-value="0.2">

  <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
    <!-- Left: Product Images -->
    <div>
      <%= render "products/image_carousel", product: @product %>
    </div>

    <!-- Right: Configuration Panel -->
    <div class="space-y-6">
      <div>
        <h1 class="text-3xl font-bold"><%= @product.name %></h1>
        <p class="text-lg text-gray-600 mt-2"><%= @product.description %></p>
      </div>

      <!-- Step 1: Select Size -->
      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Step 1: Select Size</span>
        </label>
        <div class="flex gap-2">
          <% @available_sizes.each do |size| %>
            <button type="button"
                    class="btn btn-outline"
                    data-branded-configurator-target="sizeOption"
                    data-size="<%= size %>"
                    data-action="click->branded-configurator#selectSize">
              <%= size %>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Step 2: Select Quantity -->
      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Step 2: Select Quantity</span>
        </label>
        <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
          <% @quantity_tiers.each do |quantity| %>
            <div class="card border border-base-300 cursor-pointer hover:border-primary transition"
                 data-branded-configurator-target="quantityOption"
                 data-quantity="<%= quantity %>"
                 data-action="click->branded-configurator#selectQuantity">
              <div class="card-body p-4">
                <div class="text-center">
                  <div class="text-2xl font-bold"><%= number_with_delimiter(quantity) %></div>
                  <div class="text-sm text-gray-600">units</div>
                  <div class="text-xs mt-2 font-semibold text-primary"
                       data-branded-configurator-target="pricePerUnit">
                    <!-- Price filled by JS -->
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Step 3: Upload Design -->
      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Step 3: Upload Your Design</span>
        </label>
        <input type="file"
               class="file-input file-input-bordered w-full"
               accept=".pdf,.png,.jpg,.jpeg,.ai"
               data-branded-configurator-target="designInput"
               data-action="change->branded-configurator#handleDesignUpload">
        <label class="label">
          <span class="label-text-alt">
            Accepted formats: PDF, PNG, JPG, AI (max 10MB)
            <%= link_to "Design Guidelines", "#", class: "link link-primary" %>
          </span>
        </label>
        <div class="hidden mt-2 alert alert-success"
             data-branded-configurator-target="designPreview">
          <!-- File name shown here -->
        </div>
      </div>

      <!-- Error Messages -->
      <div class="hidden alert alert-error"
           data-branded-configurator-target="errorMessage">
        <!-- Error text shown here -->
      </div>

      <!-- Price Summary -->
      <div class="card bg-base-200">
        <div class="card-body">
          <h3 class="card-title text-lg">Price Summary</h3>
          <div class="space-y-2">
            <div class="flex justify-between">
              <span>Subtotal:</span>
              <span data-branded-configurator-target="subtotal" class="font-semibold">£0.00</span>
            </div>
            <div class="flex justify-between">
              <span>VAT (20%):</span>
              <span data-branded-configurator-target="vat" class="font-semibold">£0.00</span>
            </div>
            <div class="divider my-1"></div>
            <div class="flex justify-between text-lg">
              <span class="font-bold">Total:</span>
              <span data-branded-configurator-target="total" class="font-bold text-primary">£0.00</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Add to Cart Button -->
      <button class="btn btn-primary btn-lg w-full btn-disabled"
              data-branded-configurator-target="addToCartButton"
              data-action="click->branded-configurator#addToCart"
              disabled>
        Add to Cart
      </button>

      <!-- Delivery Info -->
      <div class="alert">
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-info shrink-0 w-6 h-6">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>
        <span>Delivered in 3-4 weeks • Free shipping on orders over £500</span>
      </div>
    </div>
  </div>
</div>
```

**Step 2: Update ProductsController**

In `app/controllers/products_controller.rb`, modify `show` action:
```ruby
  def show
    @product = Product.friendly.find(params[:id])

    if @product.customizable_template?
      # Load data for configurator
      service = BrandedProductPricingService.new(@product)
      @available_sizes = service.available_sizes
      @quantity_tiers = service.available_quantities(@available_sizes.first) if @available_sizes.any?
    elsif @product.standard?
      # Existing logic for standard products
      @selected_variant = if params[:variant_id]
        @product.active_variants.find(params[:variant_id])
      else
        @product.default_variant
      end
    end
  end
```

**Step 3: Update products/show view to use configurator**

In `app/views/products/show.html.erb`:
```erb
<% if @product.customizable_template? %>
  <%= render "branded_configurator", product: @product %>
<% else %>
  <%= render "standard_product", product: @product, selected_variant: @selected_variant %>
<% end %>
```

**Step 4: Create standard product partial**

Move existing product show content to `app/views/products/_standard_product.html.erb`.

**Step 5: Commit**

```bash
git add .
git commit -m "Add branded product configurator view

- BrandYour-inspired configurator UI
- Progressive disclosure: size → quantity → design upload
- Real-time price calculation display
- TailwindCSS + DaisyUI components
- Responsive grid layout
- ProductsController detects product_type and renders appropriate view

Views: Branded configurator with Stimulus integration"
```

---

## Phase 6: Cart Integration for Configured Products

### Task 15: Update CartItemsController for configurations

**Files:**
- Modify: `app/controllers/cart_items_controller.rb`
- Modify: `test/controllers/cart_items_controller_test.rb`

**Step 1: Write the failing tests**

Add to `test/controllers/cart_items_controller_test.rb`:
```ruby
  test "creates cart item with configuration for branded product" do
    sign_in users(:consumer)

    # Upload design file
    design_file = fixture_file_upload("files/test_design.pdf", "application/pdf")

    assert_difference "CartItem.count", 1 do
      post cart_items_url, params: {
        product_id: products(:branded_double_wall_template).id,
        configuration: {
          size: "12oz",
          quantity: 5000
        },
        calculated_price: 1000.00,
        design: design_file
      }
    end

    cart_item = CartItem.last
    assert_equal "12oz", cart_item.configuration["size"]
    assert_equal 5000, cart_item.configuration["quantity"]
    assert_equal 1000.00, cart_item.calculated_price
    assert cart_item.design.attached?
  end

  test "requires calculated_price for configured products" do
    sign_in users(:consumer)

    assert_no_difference "CartItem.count" do
      post cart_items_url, params: {
        product_id: products(:branded_double_wall_template).id,
        configuration: {
          size: "12oz",
          quantity: 5000
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "validates design attachment for configured products" do
    sign_in users(:consumer)

    assert_no_difference "CartItem.count" do
      post cart_items_url, params: {
        product_id: products(:branded_double_wall_template).id,
        configuration: {
          size: "12oz",
          quantity: 5000
        },
        calculated_price: 1000.00
      }
    end

    assert_response :unprocessable_entity
  end

  test "standard product cart item creation still works" do
    sign_in users(:consumer)

    assert_difference "CartItem.count", 1 do
      post cart_items_url, params: {
        variant_id: product_variants(:single_wall_8oz_white).id,
        quantity: 10
      }
    end

    cart_item = CartItem.last
    assert_nil cart_item.configuration
    assert_nil cart_item.calculated_price
  end
```

**Step 2: Create test fixture file**

Create `test/fixtures/files/test_design.pdf` (a small valid PDF file for testing).

**Step 3: Run tests to verify they fail**

Run: `rails test test/controllers/cart_items_controller_test.rb`
Expected: FAIL

**Step 4: Update CartItemsController**

In `app/controllers/cart_items_controller.rb`, modify `create`:
```ruby
  def create
    @cart = Current.cart

    if cart_item_params[:configuration].present?
      # Configured product (branded cups)
      create_configured_cart_item
    else
      # Standard product
      create_standard_cart_item
    end
  end

  private

  def create_configured_cart_item
    product = Product.find(cart_item_params[:product_id])

    unless product.customizable_template?
      return render json: { error: "Product is not customizable" },
                    status: :unprocessable_entity
    end

    cart_item = @cart.cart_items.build(
      product: product,
      quantity: 1, # Configured products are always quantity 1
      configuration: cart_item_params[:configuration],
      calculated_price: cart_item_params[:calculated_price]
    )

    if params[:design].present?
      cart_item.design.attach(params[:design])
    end

    if cart_item.save
      respond_to do |format|
        format.html { redirect_to cart_path, notice: "Configured product added to cart" }
        format.json { render json: { success: true, cart_item: cart_item }, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, alert: cart_item.errors.full_messages.join(", ") }
        format.json { render json: { error: cart_item.errors.full_messages.join(", ") }, status: :unprocessable_entity }
      end
    end
  end

  def create_standard_cart_item
    # Existing logic for standard products
    variant = ProductVariant.find(cart_item_params[:variant_id])
    cart_item = @cart.cart_items.find_or_initialize_by(variant: variant)

    if cart_item.new_record?
      cart_item.quantity = cart_item_params[:quantity] || 1
    else
      cart_item.quantity += (cart_item_params[:quantity] || 1)
    end

    if cart_item.save
      redirect_to cart_path, notice: "Item added to cart"
    else
      redirect_back fallback_location: root_path, alert: cart_item.errors.full_messages.join(", ")
    end
  end

  def cart_item_params
    params.permit(:product_id, :variant_id, :quantity, :calculated_price, configuration: [:size, :quantity])
  end
```

**Step 5: Add validation to CartItem**

In `app/models/cart_item.rb`, add:
```ruby
  validate :design_required_for_configured_products

  private

  def design_required_for_configured_products
    if configured? && !design.attached?
      errors.add(:design, "must be uploaded for custom products")
    end
  end
```

**Step 6: Run tests to verify they pass**

Run: `rails test test/controllers/cart_items_controller_test.rb`
Expected: PASS

**Step 7: Commit**

```bash
git add .
git commit -m "Update CartItemsController for configured products

- Separate logic for configured vs standard products
- Validates design attachment for configured products
- Attaches design file to cart item
- JSON and HTML responses for AJAX and direct form submission
- Maintains backward compatibility with standard products

Tests: Cart item controller tests passing"
```

---

---

## Phase 7: Customer Dashboard for Branded Products

### Task 16: Create Organizations::ProductsController

**Files:**
- Create: `app/controllers/organizations/products_controller.rb`
- Create: `test/controllers/organizations/products_controller_test.rb`
- Modify: `config/routes.rb`

**Step 1: Write the failing test**

In `test/controllers/organizations/products_controller_test.rb`:
```ruby
require "test_helper"

class Organizations::ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @acme_admin = users(:acme_admin)
    @acme_member = users(:acme_member)
    @consumer = users(:consumer)
  end

  test "redirects non-organization users" do
    sign_in @consumer

    get organizations_products_path
    assert_redirected_to root_path
    assert_equal "You must be a member of an organization to access this page", flash[:alert]
  end

  test "shows organization's customized products" do
    sign_in @acme_admin

    get organizations_products_path
    assert_response :success

    assert_select "h1", "Your Branded Products"
    assert_select "div.product-card", count: 1 # acme_branded_cups
  end

  test "does not show other organizations' products" do
    sign_in users(:bobs_owner)

    get organizations_products_path
    assert_response :success

    # Should not see ACME's products
    assert_select "div.product-card", count: 0
  end

  test "all organization members can access" do
    [@acme_admin, @acme_member].each do |user|
      sign_in user

      get organizations_products_path
      assert_response :success
    end
  end

  test "shows empty state when no products" do
    sign_in users(:bobs_owner)

    get organizations_products_path
    assert_response :success

    assert_select "div.empty-state"
    assert_select "a[href=?]", products_path
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `rails test test/controllers/organizations/products_controller_test.rb`
Expected: FAIL

**Step 3: Add routes**

In `config/routes.rb`, add:
```ruby
  namespace :organizations do
    resources :products, only: [:index, :show]
  end
```

**Step 4: Create controller**

In `app/controllers/organizations/products_controller.rb`:
```ruby
module Organizations
  class ProductsController < ApplicationController
    before_action :require_organization_membership

    def index
      @products = current_user.organization
                              .customized_products
                              .includes(:active_variants, images_attachments: :blob)
                              .order(created_at: :desc)
    end

    def show
      @product = current_user.organization
                             .customized_products
                             .friendly
                             .find(params[:id])
    end

    private

    def require_organization_membership
      unless current_user&.organization_id.present?
        redirect_to root_path, alert: "You must be a member of an organization to access this page"
      end
    end
  end
end
```

**Step 5: Run tests to verify they pass**

Run: `rails test test/controllers/organizations/products_controller_test.rb`
Expected: PASS (5 tests)

**Step 6: Commit**

```bash
git add .
git commit -m "Add Organizations::ProductsController

- Dashboard for viewing organization's branded products
- Requires organization membership
- Scoped to current user's organization only
- Index and show actions

Tests: 5 tests passing"
```

---

### Task 17: Create organization products dashboard view

**Files:**
- Create: `app/views/organizations/products/index.html.erb`
- Create: `app/views/organizations/products/show.html.erb`
- Create: `app/views/organizations/products/_product_card.html.erb`

**Step 1: Create index view**

In `app/views/organizations/products/index.html.erb`:
```erb
<div class="container mx-auto px-4 py-8">
  <div class="flex justify-between items-center mb-8">
    <h1 class="text-3xl font-bold">Your Branded Products</h1>
    <%= link_to "Browse Customizable Products", products_path, class: "btn btn-primary" %>
  </div>

  <% if @products.any? %>
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <% @products.each do |product| %>
        <%= render "product_card", product: product %>
      <% end %>
    </div>
  <% else %>
    <div class="empty-state card bg-base-200 p-12 text-center">
      <div class="card-body">
        <h2 class="card-title text-2xl justify-center mb-4">No Branded Products Yet</h2>
        <p class="text-lg mb-6">
          You don't have any branded products yet.
          Browse our customizable options to create your first branded product!
        </p>
        <%= link_to "Browse Branded Products", products_path, class: "btn btn-primary btn-lg" %>
      </div>
    </div>
  <% end %>
</div>
```

**Step 2: Create product card partial**

In `app/views/organizations/products/_product_card.html.erb`:
```erb
<div class="product-card card bg-base-100 shadow-xl">
  <%= link_to organizations_product_path(product), class: "block" do %>
    <figure class="aspect-square">
      <% if product.images.attached? %>
        <%= image_tag product.images.first.variant(resize_to_limit: [400, 400]),
                      alt: product.name,
                      class: "object-cover w-full h-full" %>
      <% else %>
        <div class="bg-base-200 w-full h-full flex items-center justify-center">
          <span class="text-4xl">📦</span>
        </div>
      <% end %>
    </figure>
  <% end %>

  <div class="card-body">
    <h2 class="card-title">
      <%= product.name %>
    </h2>

    <div class="space-y-2 text-sm">
      <div class="flex justify-between">
        <span class="text-gray-600">SKU:</span>
        <span class="font-semibold"><%= product.active_variants.first&.sku || "N/A" %></span>
      </div>

      <% if product.configuration_data["size"].present? %>
        <div class="flex justify-between">
          <span class="text-gray-600">Size:</span>
          <span class="font-semibold"><%= product.configuration_data["size"] %></span>
        </div>
      <% end %>

      <% if product.active_variants.first %>
        <% variant = product.active_variants.first %>
        <div class="flex justify-between">
          <span class="text-gray-600">Price:</span>
          <span class="font-semibold">£<%= number_with_precision(variant.price, precision: 2) %>/unit</span>
        </div>

        <div class="flex justify-between">
          <span class="text-gray-600">Stock:</span>
          <% if variant.stock > 0 %>
            <span class="badge badge-success"><%= number_with_delimiter(variant.stock) %> in stock</span>
          <% elsif variant.stock > 0 && variant.stock < 1000 %>
            <span class="badge badge-warning">Low stock (<%= variant.stock %>)</span>
          <% else %>
            <span class="badge badge-error">Out of stock</span>
          <% end %>
        </div>
      <% end %>
    </div>

    <div class="card-actions justify-end mt-4">
      <%= link_to "Reorder", organizations_product_path(product), class: "btn btn-primary" %>
    </div>
  </div>
</div>
```

**Step 3: Create show view**

In `app/views/organizations/products/show.html.erb`:
```erb
<div class="container mx-auto px-4 py-8">
  <%= link_to "← Back to Your Products", organizations_products_path, class: "btn btn-ghost mb-4" %>

  <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
    <!-- Product Images -->
    <div>
      <%= render "products/image_carousel", product: @product %>
    </div>

    <!-- Product Details & Reorder -->
    <div class="space-y-6">
      <div>
        <h1 class="text-3xl font-bold"><%= @product.name %></h1>
        <p class="text-lg text-gray-600 mt-2">Your custom branded product</p>
      </div>

      <!-- Configuration Details -->
      <div class="card bg-base-200">
        <div class="card-body">
          <h3 class="card-title">Product Specifications</h3>
          <dl class="space-y-2">
            <% if @product.configuration_data["size"] %>
              <div class="flex justify-between">
                <dt class="text-gray-600">Size:</dt>
                <dd class="font-semibold"><%= @product.configuration_data["size"] %></dd>
              </div>
            <% end %>
            <% if @product.configuration_data["type"] %>
              <div class="flex justify-between">
                <dt class="text-gray-600">Type:</dt>
                <dd class="font-semibold"><%= @product.configuration_data["type"].titleize %></dd>
              </div>
            <% end %>
            <% if @product.active_variants.first %>
              <div class="flex justify-between">
                <dt class="text-gray-600">SKU:</dt>
                <dd class="font-semibold"><%= @product.active_variants.first.sku %></dd>
              </div>
            <% end %>
          </dl>
        </div>
      </div>

      <!-- Reorder Form -->
      <% if @product.active_variants.first %>
        <% variant = @product.active_variants.first %>
        <%= form_with url: cart_items_path, method: :post, class: "space-y-4" do |f| %>
          <%= f.hidden_field :variant_id, value: variant.id %>

          <div class="form-control">
            <label class="label">
              <span class="label-text font-semibold">Quantity</span>
            </label>
            <%= f.number_field :quantity,
                              value: 1000,
                              min: 500,
                              step: 500,
                              class: "input input-bordered w-full" %>
            <label class="label">
              <span class="label-text-alt">Minimum order: 500 units</span>
            </label>
          </div>

          <div class="card bg-base-200">
            <div class="card-body">
              <div class="flex justify-between text-lg">
                <span class="font-semibold">Price per unit:</span>
                <span class="text-primary font-bold">£<%= number_with_precision(variant.price, precision: 2) %></span>
              </div>
            </div>
          </div>

          <%= f.submit "Add to Cart", class: "btn btn-primary btn-lg w-full" %>
        <% end %>
      <% else %>
        <div class="alert alert-warning">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-current shrink-0 w-6 h-6">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path>
          </svg>
          <span>This product is currently out of stock. Please contact us to restock.</span>
        </div>
      <% end %>
    </div>
  </div>
</div>
```

**Step 4: Commit**

```bash
git add .
git commit -m "Add organization products dashboard views

- Index view with product grid and empty state
- Product card component showing SKU, stock, price
- Show view for reordering with quantity selector
- Configuration details display
- TailwindCSS + DaisyUI styling

Views: Customer-facing branded product dashboard"
```

---

## Phase 8: Admin Fulfillment Workflow

### Task 18: Create Admin::BrandedOrders namespace

**Files:**
- Create: `app/controllers/admin/branded_orders_controller.rb`
- Create: `test/controllers/admin/branded_orders_controller_test.rb`
- Modify: `config/routes.rb`

**Step 1: Write the failing test**

In `test/controllers/admin/branded_orders_controller_test.rb`:
```ruby
require "test_helper"

class Admin::BrandedOrdersControllerTest < ActionDispatch::IntegrationTest
  # Note: Add admin authentication when implemented
  # For now, these tests assume admin access

  test "index shows orders with configured products" do
    get admin_branded_orders_path
    assert_response :success

    # Should show orders containing configured cart items
    assert_select "h1", "Branded Product Orders"
  end

  test "show displays order with configuration details" do
    order = orders(:acme_order)

    get admin_branded_order_path(order)
    assert_response :success

    assert_select "h1", /Order ##{order.id}/
  end

  test "filters to only orders with configured products" do
    # Create order without configured products
    standard_order = orders(:one)

    get admin_branded_orders_path
    assert_response :success

    # Implementation will filter to only branded orders
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `rails test test/controllers/admin/branded_orders_controller_test.rb`
Expected: FAIL

**Step 3: Add routes**

In `config/routes.rb`, add to admin namespace:
```ruby
  namespace :admin do
    # ... existing admin routes
    resources :branded_orders, only: [:index, :show] do
      member do
        patch :update_status
        post :create_instance_product
      end
    end
  end
```

**Step 4: Create controller**

In `app/controllers/admin/branded_orders_controller.rb`:
```ruby
module Admin
  class BrandedOrdersController < ApplicationController
    # TODO: Add admin authentication
    # before_action :require_admin

    def index
      @orders = Order.joins(:order_items)
                    .where(order_items: { configuration: {} })
                    .where.not(order_items: { configuration: nil })
                    .distinct
                    .order(created_at: :desc)
                    .page(params[:page])
    end

    def show
      @order = Order.find(params[:id])
      @configured_items = @order.order_items.where.not(configuration: nil)
    end

    def update_status
      @order = Order.find(params[:id])
      @order.update!(branded_order_status: params[:status])

      redirect_to admin_branded_order_path(@order),
                  notice: "Order status updated to #{params[:status]}"
    end

    def create_instance_product
      @order = Order.find(params[:id])
      @order_item = @order.order_items.find(params[:order_item_id])

      service = BrandedProducts::InstanceCreatorService.new(@order_item)
      result = service.create_instance_product(
        name: params[:product_name],
        sku: params[:sku],
        initial_stock: params[:initial_stock],
        reorder_price: params[:reorder_price]
      )

      if result.success?
        redirect_to admin_branded_order_path(@order),
                    notice: "Customer product created successfully"
      else
        redirect_to admin_branded_order_path(@order),
                    alert: "Failed to create product: #{result.error}"
      end
    end
  end
end
```

**Step 5: Run tests to verify they pass**

Run: `rails test test/controllers/admin/branded_orders_controller_test.rb`
Expected: PASS (3 tests)

**Step 6: Commit**

```bash
git add .
git commit -m "Add Admin::BrandedOrdersController

- Lists orders containing configured products
- Show page with configuration details
- Status update action for fulfillment tracking
- Action to create instance product from order
- Filtered to only branded orders

Tests: 3 tests passing"
```

---

### Task 19: Add branded_order_status to Order

**Files:**
- Modify: `app/models/order.rb`
- Modify: `test/models/order_test.rb`
- Create migration: `db/migrate/XXXXXX_add_branded_order_status_to_orders.rb`

**Step 1: Write the failing tests**

Add to `test/models/order_test.rb`:
```ruby
  test "order has branded_order_status enum" do
    order = orders(:acme_order)

    order.branded_order_status = "design_pending"
    assert order.valid?

    order.branded_order_status = "design_approved"
    assert order.valid?

    order.branded_order_status = "in_production"
    assert order.valid?

    order.branded_order_status = "production_complete"
    assert order.valid?

    order.branded_order_status = "stock_received"
    assert order.valid?

    order.branded_order_status = "instance_created"
    assert order.valid?
  end

  test "branded order scope" do
    # Add configured item to order
    cart_item = cart_items(:branded_configuration)
    order = orders(:acme_order)

    # Orders with configured items
    branded_orders = Order.branded_orders
    # Implementation needed
  end
```

**Step 2: Run tests to verify they fail**

Run: `rails test test/models/order_test.rb`
Expected: FAIL

**Step 3: Create migration**

Run: `rails generate migration AddBrandedOrderStatusToOrders branded_order_status:string`

Edit migration:
```ruby
class AddBrandedOrderStatusToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :branded_order_status, :string
    add_index :orders, :branded_order_status
  end
end
```

**Step 4: Run migration**

Run: `rails db:migrate`

**Step 5: Update Order model**

In `app/models/order.rb`, add:
```ruby
  enum :branded_order_status, {
    design_pending: "design_pending",
    design_approved: "design_approved",
    in_production: "in_production",
    production_complete: "production_complete",
    stock_received: "stock_received",
    instance_created: "instance_created"
  }, prefix: true, validate: { allow_nil: true }

  scope :branded_orders, -> {
    joins(:order_items)
      .where.not(order_items: { configuration: nil })
      .distinct
  }

  def branded_order?
    order_items.any? { |item| item.configuration.present? }
  end
```

**Step 6: Run tests to verify they pass**

Run: `rails test test/models/order_test.rb`
Expected: PASS

**Step 7: Commit**

```bash
git add .
git commit -m "Add branded_order_status to Order model

- Enum for tracking fulfillment stages
- Statuses: design_pending → instance_created
- Scope for querying branded orders
- Helper method to identify branded orders

Tests: Order tests passing"
```

---

### Task 20: Add configuration to OrderItem

**Files:**
- Modify: `app/models/order_item.rb`
- Modify: `test/models/order_item_test.rb`
- Create migration: `db/migrate/XXXXXX_add_configuration_to_order_items.rb`

**Step 1: Write the failing tests**

Add to `test/models/order_item_test.rb`:
```ruby
  test "order item stores configuration from cart item" do
    cart_item = cart_items(:branded_configuration)
    order = orders(:acme_order)

    order_item = OrderItem.create_from_cart_item(cart_item, order)

    assert_equal cart_item.configuration["size"], order_item.configuration["size"]
    assert_equal cart_item.configuration["quantity"], order_item.configuration["quantity"]
  end

  test "order item has design attachment" do
    order_item = order_items(:acme_branded_item)
    assert_respond_to order_item, :design
  end

  test "configured order item" do
    order_item = order_items(:acme_branded_item)
    assert order_item.configured?
    assert_equal "12oz", order_item.configuration["size"]
  end
```

**Step 2: Add fixture**

In `test/fixtures/order_items.yml`:
```yaml
acme_branded_item:
  order: acme_order
  product: branded_double_wall_template
  quantity: 1
  unit_price: 0.18
  total_price: 900.00
  configuration:
    size: "12oz"
    quantity: 5000
```

**Step 3: Run tests to verify they fail**

Run: `rails test test/models/order_item_test.rb`
Expected: FAIL

**Step 4: Create migration**

Run: `rails generate migration AddConfigurationToOrderItems configuration:jsonb`

Edit migration:
```ruby
class AddConfigurationToOrderItems < ActiveRecord::Migration[8.0]
  def change
    add_column :order_items, :configuration, :jsonb, default: {}
    add_index :order_items, :configuration, using: :gin
  end
end
```

**Step 5: Run migration**

Run: `rails db:migrate`

**Step 6: Update OrderItem model**

In `app/models/order_item.rb`:
```ruby
  has_one_attached :design

  def self.create_from_cart_item(cart_item, order)
    order_item = new(
      order: order,
      product: cart_item.product,
      product_variant: cart_item.variant,
      quantity: cart_item.quantity,
      unit_price: cart_item.unit_price,
      total_price: cart_item.line_total,
      configuration: cart_item.configuration
    )

    # Copy design attachment if present
    if cart_item.design.attached?
      order_item.design.attach(cart_item.design.blob)
    end

    order_item
  end

  def configured?
    configuration.present? && !configuration.empty?
  end
```

**Step 7: Update CheckoutsController to use new method**

In `app/controllers/checkouts_controller.rb`, update `success` action:
```ruby
  def success
    # ... existing code to retrieve session and create order

    @order.transaction do
      Current.cart.cart_items.each do |cart_item|
        OrderItem.create_from_cart_item(cart_item, @order).save!
      end

      Current.cart.destroy
    end

    # ... rest of method
  end
```

**Step 8: Run tests to verify they pass**

Run: `rails test test/models/order_item_test.rb`
Expected: PASS

**Step 9: Commit**

```bash
git add .
git commit -m "Add configuration support to OrderItem

- Store configuration from CartItem
- Copy design attachment to OrderItem
- Class method to create from cart item
- Helper method to identify configured items
- Update checkout to preserve configuration

Tests: OrderItem tests passing"
```

---

## Phase 9: Instance Product Creation

### Task 21: Create BrandedProducts::InstanceCreatorService

**Files:**
- Create: `app/services/branded_products/instance_creator_service.rb`
- Create: `test/services/branded_products/instance_creator_service_test.rb`

**Step 1: Write the failing test**

In `test/services/branded_products/instance_creator_service_test.rb`:
```ruby
require "test_helper"

class BrandedProducts::InstanceCreatorServiceTest < ActiveSupport::TestCase
  setup do
    @order = orders(:acme_order)
    @order_item = order_items(:acme_branded_item)
    @service = BrandedProducts::InstanceCreatorService.new(@order_item)
  end

  test "creates instance product from order item" do
    assert_difference "Product.count", 1 do
      assert_difference "ProductVariant.count", 1 do
        result = @service.create_instance_product(
          name: "ACME Coffee 12oz Branded Cups",
          sku: "BRANDED-ACME-12DW-001",
          initial_stock: 5000,
          reorder_price: 0.18
        )

        assert result.success?
        assert_instance_of Product, result.product
      end
    end
  end

  test "sets correct product attributes" do
    result = @service.create_instance_product(
      name: "ACME Coffee 12oz Branded Cups",
      sku: "BRANDED-ACME-12DW-001",
      initial_stock: 5000,
      reorder_price: 0.18
    )

    product = result.product

    assert_equal "customized_instance", product.product_type
    assert_equal @order.organization, product.organization
    assert_equal @order_item.product, product.parent_product
    assert_equal @order_item.configuration, product.configuration_data
  end

  test "creates variant with correct attributes" do
    result = @service.create_instance_product(
      name: "ACME Coffee 12oz Branded Cups",
      sku: "BRANDED-ACME-12DW-001",
      initial_stock: 5000,
      reorder_price: 0.18
    )

    variant = result.product.active_variants.first

    assert_equal "BRANDED-ACME-12DW-001", variant.sku
    assert_equal 5000, variant.stock
    assert_equal 0.18, variant.price
  end

  test "copies design attachment to product" do
    # Attach design to order item
    @order_item.design.attach(
      io: File.open(Rails.root.join("test", "fixtures", "files", "test_design.pdf")),
      filename: "test_design.pdf"
    )

    result = @service.create_instance_product(
      name: "ACME Coffee 12oz Branded Cups",
      sku: "BRANDED-ACME-12DW-001",
      initial_stock: 5000,
      reorder_price: 0.18
    )

    assert result.product.images.attached?
  end

  test "generates slug from name" do
    result = @service.create_instance_product(
      name: "ACME Coffee 12oz Branded Cups",
      sku: "BRANDED-ACME-12DW-001",
      initial_stock: 5000,
      reorder_price: 0.18
    )

    assert_equal "acme-coffee-12oz-branded-cups", result.product.slug
  end

  test "requires order item to have configuration" do
    order_item = order_items(:one) # standard order item, no configuration
    service = BrandedProducts::InstanceCreatorService.new(order_item)

    result = service.create_instance_product(
      name: "Test",
      sku: "TEST-001",
      initial_stock: 1000,
      reorder_price: 0.50
    )

    assert_not result.success?
    assert_includes result.error, "configuration"
  end

  test "requires order to have organization" do
    @order.update!(organization_id: nil)

    result = @service.create_instance_product(
      name: "Test",
      sku: "TEST-001",
      initial_stock: 1000,
      reorder_price: 0.50
    )

    assert_not result.success?
    assert_includes result.error, "organization"
  end

  test "validates required parameters" do
    result = @service.create_instance_product(
      name: "",
      sku: "",
      initial_stock: nil,
      reorder_price: nil
    )

    assert_not result.success?
    assert_present result.error
  end

  test "updates order branded_order_status" do
    @order.update!(branded_order_status: "stock_received")

    @service.create_instance_product(
      name: "ACME Coffee 12oz Branded Cups",
      sku: "BRANDED-ACME-12DW-001",
      initial_stock: 5000,
      reorder_price: 0.18
    )

    @order.reload
    assert_equal "instance_created", @order.branded_order_status
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `rails test test/services/branded_products/instance_creator_service_test.rb`
Expected: FAIL

**Step 3: Create the service**

In `app/services/branded_products/instance_creator_service.rb`:
```ruby
module BrandedProducts
  class InstanceCreatorService
    Result = Struct.new(:success, :product, :error, keyword_init: true) do
      def success?
        success
      end
    end

    def initialize(order_item)
      @order_item = order_item
      @order = order_item.order
    end

    def create_instance_product(name:, sku:, initial_stock:, reorder_price:)
      return error_result("Order item must have configuration") unless @order_item.configured?
      return error_result("Order must belong to an organization") unless @order.organization_id.present?

      validate_params!(name, sku, initial_stock, reorder_price)

      ActiveRecord::Base.transaction do
        product = create_product(name)
        variant = create_variant(product, sku, initial_stock, reorder_price)
        copy_design_to_product(product)
        update_order_status

        Result.new(success: true, product: product)
      end
    rescue ActiveRecord::RecordInvalid => e
      error_result(e.message)
    rescue StandardError => e
      error_result("Failed to create product: #{e.message}")
    end

    private

    def create_product(name)
      Product.create!(
        name: name,
        product_type: "customized_instance",
        organization: @order.organization,
        parent_product: @order_item.product,
        category: @order_item.product.category,
        configuration_data: @order_item.configuration,
        active: true,
        description: "Custom branded product for #{@order.organization.name}"
      )
    end

    def create_variant(product, sku, initial_stock, reorder_price)
      product.variants.create!(
        sku: sku,
        price: reorder_price,
        stock: initial_stock,
        active: true
      )
    end

    def copy_design_to_product(product)
      return unless @order_item.design.attached?

      product.images.attach(@order_item.design.blob)
    end

    def update_order_status
      @order.update!(branded_order_status: "instance_created")
    end

    def validate_params!(name, sku, initial_stock, reorder_price)
      errors = []
      errors << "Name is required" if name.blank?
      errors << "SKU is required" if sku.blank?
      errors << "Initial stock must be positive" if initial_stock.to_i <= 0
      errors << "Reorder price must be positive" if reorder_price.to_f <= 0

      raise ArgumentError, errors.join(", ") if errors.any?
    end

    def error_result(message)
      Result.new(success: false, error: message)
    end
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `rails test test/services/branded_products/instance_creator_service_test.rb`
Expected: PASS (8 tests)

**Step 5: Commit**

```bash
git add .
git commit -m "Add BrandedProducts::InstanceCreatorService

- Creates customized_instance product from order item
- Copies configuration and design to new product
- Creates variant with SKU, stock, and pricing
- Updates order status to instance_created
- Validates all required parameters
- Transactional to ensure data consistency

Tests: 8 tests passing"
```

---

### Task 22: Create admin branded order fulfillment views

**Files:**
- Create: `app/views/admin/branded_orders/index.html.erb`
- Create: `app/views/admin/branded_orders/show.html.erb`
- Create: `app/views/admin/branded_orders/_instance_product_form.html.erb`

**Step 1: Create index view**

In `app/views/admin/branded_orders/index.html.erb`:
```erb
<div class="container mx-auto px-4 py-8">
  <h1 class="text-3xl font-bold mb-8">Branded Product Orders</h1>

  <div class="overflow-x-auto">
    <table class="table table-zebra w-full">
      <thead>
        <tr>
          <th>Order #</th>
          <th>Organization</th>
          <th>Date</th>
          <th>Total</th>
          <th>Status</th>
          <th>Fulfillment</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        <% @orders.each do |order| %>
          <tr>
            <td>
              <%= link_to "##{order.id}", admin_branded_order_path(order), class: "link link-primary" %>
            </td>
            <td><%= order.organization&.name || "N/A" %></td>
            <td><%= order.created_at.strftime("%Y-%m-%d") %></td>
            <td class="font-semibold">£<%= number_with_precision(order.total_amount, precision: 2) %></td>
            <td>
              <span class="badge badge-<%= order.status == 'completed' ? 'success' : 'warning' %>">
                <%= order.status.titleize %>
              </span>
            </td>
            <td>
              <% if order.branded_order_status %>
                <span class="badge badge-info">
                  <%= order.branded_order_status.humanize %>
                </span>
              <% else %>
                <span class="badge badge-ghost">Pending</span>
              <% end %>
            </td>
            <td>
              <%= link_to "View", admin_branded_order_path(order), class: "btn btn-sm btn-primary" %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>

  <%= paginate @orders if defined?(Kaminari) %>
</div>
```

**Step 2: Create show view**

In `app/views/admin/branded_orders/show.html.erb`:
```erb
<div class="container mx-auto px-4 py-8">
  <%= link_to "← Back to Orders", admin_branded_orders_path, class: "btn btn-ghost mb-4" %>

  <div class="mb-8">
    <h1 class="text-3xl font-bold">Order #<%= @order.id %></h1>
    <div class="text-lg text-gray-600">
      <%= @order.organization&.name || "Individual Customer" %> •
      <%= @order.created_at.strftime("%B %d, %Y at %I:%M %p") %>
    </div>
  </div>

  <!-- Fulfillment Status Timeline -->
  <div class="card bg-base-200 mb-8">
    <div class="card-body">
      <h2 class="card-title">Fulfillment Status</h2>

      <ul class="steps steps-vertical lg:steps-horizontal w-full">
        <li class="step <%= 'step-primary' if @order.branded_order_status.present? %>">
          Design Pending
        </li>
        <li class="step <%= 'step-primary' if @order.branded_order_status_design_approved? || @order.branded_order_status_in_production? %>">
          Design Approved
        </li>
        <li class="step <%= 'step-primary' if @order.branded_order_status_in_production? %>">
          In Production
        </li>
        <li class="step <%= 'step-primary' if @order.branded_order_status_production_complete? %>">
          Production Complete
        </li>
        <li class="step <%= 'step-primary' if @order.branded_order_status_stock_received? %>">
          Stock Received
        </li>
        <li class="step <%= 'step-primary' if @order.branded_order_status_instance_created? %>">
          Customer Product Created
        </li>
      </ul>

      <!-- Status Update Form -->
      <%= form_with url: update_status_admin_branded_order_path(@order), method: :patch, class: "mt-6" do |f| %>
        <div class="flex gap-2">
          <%= f.select :status,
                      options_for_select(
                        Order.branded_order_statuses.keys.map { |k| [k.humanize, k] },
                        @order.branded_order_status
                      ),
                      {},
                      class: "select select-bordered flex-1" %>
          <%= f.submit "Update Status", class: "btn btn-primary" %>
        </div>
      <% end %>
    </div>
  </div>

  <!-- Configured Order Items -->
  <div class="space-y-6">
    <% @configured_items.each do |item| %>
      <div class="card bg-base-100 border border-base-300">
        <div class="card-body">
          <div class="flex justify-between items-start">
            <div class="flex-1">
              <h3 class="card-title"><%= item.product.name %></h3>

              <!-- Configuration Details -->
              <div class="grid grid-cols-2 gap-4 mt-4">
                <div>
                  <h4 class="font-semibold mb-2">Configuration</h4>
                  <dl class="space-y-1">
                    <% item.configuration.each do |key, value| %>
                      <div class="flex gap-2">
                        <dt class="text-gray-600"><%= key.titleize %>:</dt>
                        <dd class="font-semibold"><%= value %></dd>
                      </div>
                    <% end %>
                  </dl>
                </div>

                <div>
                  <h4 class="font-semibold mb-2">Pricing</h4>
                  <dl class="space-y-1">
                    <div class="flex gap-2">
                      <dt class="text-gray-600">Unit Price:</dt>
                      <dd class="font-semibold">£<%= number_with_precision(item.unit_price, precision: 4) %></dd>
                    </div>
                    <div class="flex gap-2">
                      <dt class="text-gray-600">Quantity:</dt>
                      <dd class="font-semibold"><%= number_with_delimiter(item.quantity) %></dd>
                    </div>
                    <div class="flex gap-2">
                      <dt class="text-gray-600">Total:</dt>
                      <dd class="font-semibold">£<%= number_with_precision(item.total_price, precision: 2) %></dd>
                    </div>
                  </dl>
                </div>
              </div>

              <!-- Design Download -->
              <% if item.design.attached? %>
                <div class="mt-4">
                  <%= link_to "Download Design", rails_blob_path(item.design, disposition: "attachment"),
                             class: "btn btn-sm btn-outline" %>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Instance Product Creation Form -->
          <% unless @order.branded_order_status_instance_created? %>
            <div class="divider"></div>
            <%= render "instance_product_form", order: @order, order_item: item %>
          <% else %>
            <div class="alert alert-success mt-4">
              <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <span>Customer product has been created</span>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>
</div>
```

**Step 3: Create instance product form partial**

In `app/views/admin/branded_orders/_instance_product_form.html.erb`:
```erb
<div class="bg-base-200 p-6 rounded-lg">
  <h4 class="font-semibold text-lg mb-4">Create Customer Product</h4>

  <%= form_with url: create_instance_product_admin_branded_order_path(order),
               method: :post,
               class: "space-y-4" do |f| %>
    <%= hidden_field_tag :order_item_id, order_item.id %>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div class="form-control">
        <label class="label">
          <span class="label-text">Product Name</span>
        </label>
        <%= text_field_tag :product_name,
                          "#{order.organization.name} #{order_item.configuration['size']} #{order_item.product.name}",
                          class: "input input-bordered",
                          required: true %>
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text">SKU</span>
        </label>
        <%= text_field_tag :sku,
                          "BRANDED-#{order.organization.name.parameterize.upcase}-#{order_item.configuration['size']}-#{SecureRandom.hex(3).upcase}",
                          class: "input input-bordered",
                          required: true %>
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text">Initial Stock</span>
        </label>
        <%= number_field_tag :initial_stock,
                            order_item.configuration['quantity'],
                            min: 0,
                            class: "input input-bordered",
                            required: true %>
        <label class="label">
          <span class="label-text-alt">Quantity from order: <%= number_with_delimiter(order_item.configuration['quantity']) %></span>
        </label>
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text">Reorder Price (per unit)</span>
        </label>
        <%= number_field_tag :reorder_price,
                            order_item.unit_price,
                            step: 0.01,
                            min: 0,
                            class: "input input-bordered",
                            required: true %>
        <label class="label">
          <span class="label-text-alt">Original: £<%= number_with_precision(order_item.unit_price, precision: 4) %>/unit</span>
        </label>
      </div>
    </div>

    <div class="flex justify-end">
      <%= f.submit "Create Customer Product", class: "btn btn-primary" %>
    </div>
  <% end %>
</div>
```

**Step 4: Commit**

```bash
git add .
git commit -m "Add admin branded order fulfillment views

- Index page listing all branded orders
- Show page with fulfillment status timeline
- Configuration details display
- Design file download
- Instance product creation form with auto-filled values
- Status update workflow

Views: Admin fulfillment dashboard"
```

---

## Phase 10: Checkout & Organization Integration

### Task 23: Update CheckoutsController for organizations

**Files:**
- Modify: `app/controllers/checkouts_controller.rb`
- Modify: `test/controllers/checkouts_controller_test.rb`

**Step 1: Write the failing tests**

Add to `test/controllers/checkouts_controller_test.rb`:
```ruby
  test "creates order with organization for B2B users" do
    sign_in users(:acme_admin)

    # Add item to cart
    cart_item = Current.cart.cart_items.create!(
      product: products(:single_wall_cups),
      variant: product_variants(:single_wall_8oz_white),
      quantity: 10
    )

    # Mock Stripe session creation
    # ... existing stripe mocking

    post checkouts_url

    # Verify order created with organization
    order = Order.last
    assert_equal organizations(:acme), order.organization
    assert_equal users(:acme_admin), order.placed_by_user
  end

  test "creates order without organization for consumer users" do
    sign_in users(:consumer)

    # Add item to cart
    cart_item = Current.cart.cart_items.create!(
      product: products(:single_wall_cups),
      variant: product_variants(:single_wall_8oz_white),
      quantity: 10
    )

    # Mock Stripe session creation

    post checkouts_url

    # Verify order created without organization
    order = Order.last
    assert_nil order.organization_id
    assert_nil order.placed_by_user_id
    assert_equal users(:consumer), order.user
  end

  test "sets branded_order_status for orders with configured items" do
    sign_in users(:acme_admin)

    # Add configured item
    Current.cart.cart_items.create!(
      product: products(:branded_double_wall_template),
      quantity: 1,
      configuration: { size: "12oz", quantity: 5000 },
      calculated_price: 1000.00
    )

    # Mock Stripe and create order

    order = Order.last
    assert_equal "design_pending", order.branded_order_status
  end
```

**Step 2: Run tests to verify they fail**

Run: `rails test test/controllers/checkouts_controller_test.rb`
Expected: FAIL

**Step 3: Update CheckoutsController**

In `app/controllers/checkouts_controller.rb`, modify `success` action:
```ruby
  def success
    session_id = params[:session_id]
    return redirect_to root_path, alert: "Invalid session" unless session_id

    stripe_session = Stripe::Checkout::Session.retrieve(session_id)

    # Prevent duplicate orders
    existing_order = Order.find_by(stripe_session_id: session_id)
    return redirect_to order_path(existing_order), notice: "Order already processed" if existing_order

    @order = Order.new(
      user: current_user,
      organization: current_user&.organization,
      placed_by_user: current_user&.organization_id? ? current_user : nil,
      stripe_session_id: session_id,
      status: "completed",
      subtotal_amount: Current.cart.subtotal_amount,
      vat_amount: Current.cart.vat_amount,
      total_amount: Current.cart.total_amount,
      shipping_amount: stripe_session.total_details.amount_shipping / 100.0,
      shipping_address: extract_shipping_address(stripe_session)
    )

    # Set initial branded order status if cart contains configured items
    if Current.cart.cart_items.any?(&:configured?)
      @order.branded_order_status = "design_pending"
    end

    @order.transaction do
      @order.save!

      Current.cart.cart_items.each do |cart_item|
        OrderItem.create_from_cart_item(cart_item, @order).save!
      end

      Current.cart.destroy
    end

    OrderMailer.order_confirmation(@order).deliver_later

    redirect_to order_path(@order), notice: "Order completed successfully!"
  rescue Stripe::StripeError => e
    redirect_to root_path, alert: "Payment verification failed: #{e.message}"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to root_path, alert: "Order creation failed: #{e.message}"
  end

  private

  def extract_shipping_address(stripe_session)
    return {} unless stripe_session.shipping_details

    {
      name: stripe_session.shipping_details.name,
      line1: stripe_session.shipping_details.address.line1,
      line2: stripe_session.shipping_details.address.line2,
      city: stripe_session.shipping_details.address.city,
      postal_code: stripe_session.shipping_details.address.postal_code,
      country: stripe_session.shipping_details.address.country
    }
  end
```

**Step 4: Run tests to verify they pass**

Run: `rails test test/controllers/checkouts_controller_test.rb`
Expected: PASS

**Step 5: Commit**

```bash
git add .
git commit -m "Update CheckoutsController for organization orders

- Attach organization to order for B2B users
- Track which user placed the order (placed_by_user)
- Set initial branded_order_status for configured items
- Extract shipping address from Stripe session
- Maintain backward compatibility for consumer orders

Tests: Checkout controller tests passing"
```

---

## Phase 11: Standard Product Refactoring

### Task 24: Create ProductVariantGeneratorService

**Files:**
- Create: `app/services/product_variant_generator_service.rb`
- Create: `test/services/product_variant_generator_service_test.rb`

**Step 1: Write the failing test**

In `test/services/product_variant_generator_service_test.rb`:
```ruby
require "test_helper"

class ProductVariantGeneratorServiceTest < ActiveSupport::TestCase
  setup do
    @product = products(:single_wall_cups)
    @service = ProductVariantGeneratorService.new(@product)
  end

  test "generates variants for all option combinations" do
    # Product has Size (3 values) and Color (2 values) = 6 combinations
    assert_difference "ProductVariant.count", 6 do
      result = @service.generate_variants(base_price: 26.00, base_stock: 1000)
      assert result.success?
    end
  end

  test "creates variant for each option combination" do
    result = @service.generate_variants(base_price: 26.00, base_stock: 1000)

    variants = @product.variants.reload

    # Should have 8oz White, 8oz Black, 12oz White, 12oz Black, 16oz White, 16oz Black
    assert variants.any? { |v| v.option_values == { "size" => "8oz", "color" => "White" } }
    assert variants.any? { |v| v.option_values == { "size" => "8oz", "color" => "Black" } }
    assert variants.any? { |v| v.option_values == { "size" => "12oz", "color" => "White" } }
  end

  test "generates unique SKUs for each variant" do
    @service.generate_variants(base_price: 26.00, base_stock: 1000)

    skus = @product.variants.pluck(:sku)
    assert_equal skus.uniq.size, skus.size # All unique
  end

  test "SKU includes option values" do
    result = @service.generate_variants(base_price: 26.00, base_stock: 1000)

    variant = @product.variants.find_by("option_values @> ?", { size: "8oz", color: "White" }.to_json)
    assert_match /8/, variant.sku
    assert_match /WHT|WHITE/i, variant.sku
  end

  test "applies base price to all variants" do
    @service.generate_variants(base_price: 30.00, base_stock: 500)

    @product.variants.each do |variant|
      assert_equal 30.00, variant.price
    end
  end

  test "applies base stock to all variants" do
    @service.generate_variants(base_price: 26.00, base_stock: 2000)

    @product.variants.each do |variant|
      assert_equal 2000, variant.stock
    end
  end

  test "accepts custom price and stock per variant" do
    pricing = {
      { "size" => "8oz", "color" => "White" } => { price: 26.00, stock: 1000 },
      { "size" => "12oz", "color" => "White" } => { price: 28.00, stock: 1500 }
    }

    result = @service.generate_variants(pricing: pricing)

    variant_8oz = @product.variants.find_by("option_values @> ?", { size: "8oz", color: "White" }.to_json)
    assert_equal 26.00, variant_8oz.price
    assert_equal 1000, variant_8oz.stock

    variant_12oz = @product.variants.find_by("option_values @> ?", { size: "12oz", color: "White" }.to_json)
    assert_equal 28.00, variant_12oz.price
    assert_equal 1500, variant_12oz.stock
  end

  test "returns error if product has no options" do
    product = products(:branded_double_wall_template) # No option assignments
    service = ProductVariantGeneratorService.new(product)

    result = service.generate_variants(base_price: 10.00, base_stock: 100)

    assert_not result.success?
    assert_includes result.error, "options"
  end

  test "skips existing variants" do
    # Create one variant manually
    @product.variants.create!(
      sku: "EXISTING-001",
      price: 26.00,
      stock: 1000,
      option_values: { "size" => "8oz", "color" => "White" }
    )

    # Should only create 5 more (6 total - 1 existing)
    assert_difference "ProductVariant.count", 5 do
      @service.generate_variants(base_price: 26.00, base_stock: 1000)
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `rails test test/services/product_variant_generator_service_test.rb`
Expected: FAIL

**Step 3: Create the service**

In `app/services/product_variant_generator_service.rb`:
```ruby
class ProductVariantGeneratorService
  Result = Struct.new(:success, :variants_created, :error, keyword_init: true) do
    def success?
      success
    end
  end

  def initialize(product)
    @product = product
  end

  def generate_variants(base_price: nil, base_stock: 0, pricing: {})
    return error_result("Product must have options assigned") if @product.options.empty?

    combinations = generate_option_combinations
    variants_created = 0

    ActiveRecord::Base.transaction do
      combinations.each do |combination|
        # Skip if variant already exists
        next if variant_exists?(combination)

        # Get custom pricing or use base
        custom = pricing[combination] || {}
        price = custom[:price] || base_price
        stock = custom[:stock] || base_stock

        create_variant(combination, price, stock)
        variants_created += 1
      end
    end

    Result.new(success: true, variants_created: variants_created)
  rescue StandardError => e
    error_result("Failed to generate variants: #{e.message}")
  end

  private

  def generate_option_combinations
    option_values_by_option = @product.option_assignments.includes(product_option: :values).map do |assignment|
      [
        assignment.product_option.name,
        assignment.product_option.values.pluck(:value)
      ]
    end.to_h

    # Generate all combinations using Cartesian product
    option_names = option_values_by_option.keys
    value_arrays = option_values_by_option.values

    value_arrays.first.product(*value_arrays[1..-1]).map do |combo|
      combo = [combo] unless combo.is_a?(Array)
      Hash[option_names.zip(combo)]
    end
  end

  def variant_exists?(combination)
    @product.variants.where("option_values @> ?", combination.to_json).exists?
  end

  def create_variant(combination, price, stock)
    sku = generate_sku(combination)

    @product.variants.create!(
      sku: sku,
      price: price,
      stock: stock,
      option_values: combination,
      active: true
    )
  end

  def generate_sku(combination)
    base = @product.slug.upcase.gsub("-", "")
    suffix = combination.values.map { |v| v.gsub(/[^A-Z0-9]/i, "").upcase[0..2] }.join("-")
    "#{base}-#{suffix}"
  end

  def error_result(message)
    Result.new(success: false, error: message)
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `rails test test/services/product_variant_generator_service_test.rb`
Expected: PASS (10 tests)

**Step 5: Commit**

```bash
git add .
git commit -m "Add ProductVariantGeneratorService

- Generates all variants for product option combinations
- Creates unique SKU from product slug and option values
- Supports base pricing or custom pricing per variant
- Skips existing variants (idempotent)
- Validates product has options assigned

Tests: 10 tests passing"
```

---

## Phase 12: Data Migration & Seed Data

### Task 25: Create seed data for product options and pricing

**Files:**
- Modify: `db/seeds.rb`
- Create: `db/seeds/product_options.rb`
- Create: `db/seeds/branded_product_pricing.rb`

**Step 1: Create product options seed**

In `db/seeds/product_options.rb`:
```ruby
# Product Options (reusable across products)
puts "Creating product options..."

size_option = ProductOption.find_or_create_by!(name: "Size") do |option|
  option.display_type = "dropdown"
  option.required = true
  option.position = 1
end

["8oz", "12oz", "16oz", "20oz"].each_with_index do |size, index|
  size_option.values.find_or_create_by!(value: size) do |v|
    v.position = index + 1
  end
end

color_option = ProductOption.find_or_create_by!(name: "Color") do |option|
  option.display_type = "swatch"
  option.required = true
  option.position = 2
end

["White", "Black", "Kraft"].each_with_index do |color, index|
  color_option.values.find_or_create_by!(value: color) do |v|
    v.position = index + 1
  end
end

material_option = ProductOption.find_or_create_by!(name: "Material") do |option|
  option.display_type = "radio"
  option.required = false
  option.position = 3
end

["Recyclable", "Compostable", "Biodegradable"].each_with_index do |material, index|
  material_option.values.find_or_create_by!(value: material) do |v|
    v.position = index + 1
  end
end

puts "✓ Product options created"
```

**Step 2: Create branded product pricing seed**

In `db/seeds/branded_product_pricing.rb`:
```ruby
# Branded Product Pricing (from CSV data)
puts "Creating branded product pricing..."

# Find or create branded product categories
branded_category = Category.find_or_create_by!(name: "Branded Products") do |cat|
  cat.slug = "branded-products"
  cat.description = "Custom branded packaging for your business"
  cat.active = true
end

# Create Single Wall Branded Cups template
single_wall_branded = Product.find_or_create_by!(slug: "single-wall-branded-cups") do |product|
  product.name = "Single Wall Branded Cups"
  product.product_type = "customizable_template"
  product.category = branded_category
  product.description = "Custom branded single-wall cups with your design. Perfect for coffee shops, cafes, and events."
  product.active = true
  product.sort_order = 1
end

# Pricing from CSV: Single Wall
pricing_data_sw = [
  { size: "8oz", quantity: 1000, price: 0.26, case_qty: 1000 },
  { size: "8oz", quantity: 2000, price: 0.20, case_qty: 1000 },
  { size: "8oz", quantity: 5000, price: 0.15, case_qty: 1000 },
  { size: "8oz", quantity: 10000, price: 0.12, case_qty: 1000 },
  { size: "8oz", quantity: 20000, price: 0.11, case_qty: 1000 },
  { size: "8oz", quantity: 30000, price: 0.10, case_qty: 1000 },

  { size: "12oz", quantity: 1000, price: 0.28, case_qty: 1000 },
  { size: "12oz", quantity: 5000, price: 0.17, case_qty: 1000 },
  { size: "12oz", quantity: 10000, price: 0.14, case_qty: 1000 },
  { size: "12oz", quantity: 20000, price: 0.12, case_qty: 1000 },
  { size: "12oz", quantity: 30000, price: 0.11, case_qty: 1000 },

  { size: "16oz", quantity: 1000, price: 0.30, case_qty: 1000 },
  { size: "16oz", quantity: 5000, price: 0.20, case_qty: 1000 },
  { size: "16oz", quantity: 10000, price: 0.17, case_qty: 1000 },
  { size: "16oz", quantity: 20000, price: 0.15, case_qty: 1000 },
  { size: "16oz", quantity: 30000, price: 0.14, case_qty: 1000 }
]

pricing_data_sw.each do |data|
  single_wall_branded.branded_product_prices.find_or_create_by!(
    size: data[:size],
    quantity_tier: data[:quantity]
  ) do |price|
    price.price_per_unit = data[:price]
    price.case_quantity = data[:case_qty]
  end
end

# Create Double Wall Branded Cups template
double_wall_branded = Product.find_or_create_by!(slug: "double-wall-branded-cups") do |product|
  product.name = "Double Wall Branded Cups"
  product.product_type = "customizable_template"
  product.category = branded_category
  product.description = "Premium double-wall insulated cups with your custom branding. No sleeve needed!"
  product.active = true
  product.sort_order = 2
end

# Pricing from CSV: Double Wall
pricing_data_dw = [
  { size: "8oz", quantity: 1000, price: 0.30, case_qty: 500 },
  { size: "8oz", quantity: 2000, price: 0.25, case_qty: 500 },
  { size: "8oz", quantity: 5000, price: 0.18, case_qty: 500 },
  { size: "8oz", quantity: 10000, price: 0.15, case_qty: 500 },
  { size: "8oz", quantity: 20000, price: 0.11, case_qty: 500 },
  { size: "8oz", quantity: 30000, price: 0.10, case_qty: 500 },

  { size: "12oz", quantity: 1000, price: 0.32, case_qty: 500 },
  { size: "12oz", quantity: 5000, price: 0.20, case_qty: 500 },
  { size: "12oz", quantity: 10000, price: 0.17, case_qty: 500 },
  { size: "12oz", quantity: 20000, price: 0.13, case_qty: 500 },
  { size: "12oz", quantity: 30000, price: 0.12, case_qty: 500 },

  { size: "16oz", quantity: 1000, price: 0.34, case_qty: 500 },
  { size: "16oz", quantity: 5000, price: 0.22, case_qty: 500 },
  { size: "16oz", quantity: 10000, price: 0.19, case_qty: 500 },
  { size: "16oz", quantity: 20000, price: 0.15, case_qty: 500 },
  { size: "16oz", quantity: 30000, price: 0.14, case_qty: 500 }
]

pricing_data_dw.each do |data|
  double_wall_branded.branded_product_prices.find_or_create_by!(
    size: data[:size],
    quantity_tier: data[:quantity]
  ) do |price|
    price.price_per_unit = data[:price]
    price.case_quantity = data[:case_qty]
  end
end

puts "✓ Branded product pricing created (#{BrandedProductPrice.count} price points)"
```

**Step 3: Update main seeds.rb**

In `db/seeds.rb`, add:
```ruby
# Load product options
load Rails.root.join("db", "seeds", "product_options.rb")

# Load branded product pricing
load Rails.root.join("db", "seeds", "branded_product_pricing.rb")
```

**Step 4: Run seeds**

Run: `rails db:seed`
Expected: Product options and branded pricing created

**Step 5: Commit**

```bash
git add .
git commit -m "Add seed data for product options and branded pricing

- Product options: Size, Color, Material with values
- Branded product pricing from CSV data
- Single Wall and Double Wall cup templates
- All pricing tiers (1000 to 30000 units)
- Modular seed files for easy maintenance

Seeds: Complete product option and pricing data"
```

---

## Phase 13: Testing & Integration

### Task 26: Create system test for branded product workflow

**Files:**
- Create: `test/system/branded_product_ordering_test.rb`

**Step 1: Write system test**

In `test/system/branded_product_ordering_test.rb`:
```ruby
require "application_system_test_case"

class BrandedProductOrderingTest < ApplicationSystemTestCase
  setup do
    @acme_admin = users(:acme_admin)
    @product = products(:branded_double_wall_template)
  end

  test "complete branded product order workflow" do
    sign_in_as @acme_admin

    # Browse to branded product
    visit product_path(@product)

    # Verify configurator displayed
    assert_selector "h1", text: @product.name
    assert_selector "[data-controller='branded-configurator']"

    # Step 1: Select size
    click_button "12oz"
    assert_selector ".btn-primary", text: "12oz"

    # Step 2: Select quantity
    within "[data-quantity='5000']" do
      click
    end

    # Wait for price calculation
    assert_selector "[data-branded-configurator-target='total']", text: /£/, wait: 5

    # Step 3: Upload design
    attach_file "design", Rails.root.join("test", "fixtures", "files", "test_design.pdf")
    assert_text "test_design.pdf"

    # Add to cart (button should be enabled)
    assert_selector ".btn-primary:not(.btn-disabled)", text: "Add to Cart"
    click_button "Add to Cart"

    # Verify redirected to cart
    assert_current_path cart_path
    assert_text @product.name
    assert_text "12oz"
    assert_text "5,000"

    # Proceed to checkout (would need Stripe test mode)
    # click_button "Checkout"
  end

  test "configurator validates all steps completed" do
    sign_in_as @acme_admin
    visit product_path(@product)

    # Add to cart button should be disabled initially
    assert_selector ".btn-disabled", text: "Add to Cart"

    # Select only size
    click_button "8oz"

    # Still disabled (missing quantity and design)
    assert_selector ".btn-disabled", text: "Add to Cart"

    # Select quantity
    within "[data-quantity='1000']" do
      click
    end

    # Still disabled (missing design)
    assert_selector ".btn-disabled", text: "Add to Cart"

    # Upload design
    attach_file "design", Rails.root.join("test", "fixtures", "files", "test_design.pdf")

    # Now enabled
    assert_selector ".btn-primary:not(.btn-disabled)", text: "Add to Cart"
  end

  test "organization member can view and reorder branded products" do
    sign_in_as @acme_admin

    # Navigate to organization products
    visit organizations_products_path

    assert_selector "h1", text: "Your Branded Products"
    assert_selector ".product-card", count: 1 # acme_branded_cups

    # Click on product
    click_link products(:acme_branded_cups).name

    # Verify show page
    assert_text "12oz"
    assert_text products(:acme_branded_cups).active_variants.first.sku

    # Change quantity and add to cart
    fill_in "Quantity", with: 2000
    click_button "Add to Cart"

    # Verify in cart
    assert_current_path cart_path
    assert_text products(:acme_branded_cups).name
  end

  private

  def sign_in_as(user)
    visit new_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123" # Assuming fixture password
    click_button "Sign in"
  end
end
```

**Step 2: Run system tests**

Run: `rails test:system test/system/branded_product_ordering_test.rb`
Expected: Tests may fail initially due to missing view implementations

**Step 3: Commit**

```bash
git add .
git commit -m "Add system tests for branded product workflow

- End-to-end test of configurator interaction
- Validates all steps must be completed
- Tests organization member reordering
- Uses Capybara for browser automation

Tests: System tests for complete user journey"
```

---

### Task 27: Run full test suite and fix any issues

**Step 1: Run all tests**

Run: `rails test`

**Step 2: Fix any failing tests**

- Update fixtures as needed for new columns
- Fix assertion counts
- Update controller tests for new associations

**Step 3: Verify test coverage**

Run: `rails test` (with SimpleCov if configured)
Expected: Coverage should increase from baseline

**Step 4: Commit**

```bash
git add .
git commit -m "Fix test suite for product configuration system

- Updated fixtures for new database columns
- Fixed assertion counts in existing tests
- Ensured all tests pass with new features

Tests: Full suite passing (XXX tests, XXX assertions)"
```

---

### Task 28: Update navigation and UI integration

**Files:**
- Modify: `app/views/layouts/_header.html.erb` (or similar)
- Modify: `app/views/products/index.html.erb`

**Step 1: Add organization products link to navigation**

In header/navigation partial:
```erb
<% if current_user&.organization_id? %>
  <%= link_to "My Branded Products", organizations_products_path, class: "nav-link" %>
<% end %>
```

**Step 2: Add branded products section to products index**

In `app/views/products/index.html.erb`:
```erb
<!-- Add section for customizable products -->
<% if @customizable_products.any? %>
  <section class="mb-12">
    <h2 class="text-2xl font-bold mb-6">Custom Branded Products</h2>
    <p class="text-gray-600 mb-6">
      Create your own branded packaging with your custom design.
      Perfect for businesses looking to elevate their brand.
    </p>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
      <% @customizable_products.each do |product| %>
        <%= render "product_card", product: product %>
      <% end %>
    </div>
  </section>
<% end %>
```

**Step 3: Update ProductsController index**

In `app/controllers/products_controller.rb`:
```ruby
  def index
    @products = Product.catalog_products
                      .where(category: params[:category_id])
                      .includes(:category, :active_variants, images_attachments: :blob)

    # Separate customizable products
    @customizable_products = @products.where(product_type: "customizable_template")
    @standard_products = @products.where(product_type: "standard")
  end
```

**Step 4: Commit**

```bash
git add .
git commit -m "Add UI navigation for branded products

- Organization products link in header for B2B users
- Branded products section on products index
- Separated customizable from standard products
- Improved UX for discovering branded options

Views: Navigation and product discovery"
```

---

### Task 29: Add admin navigation for branded orders

**Files:**
- Modify: `app/views/admin/layouts/_sidebar.html.erb` (or similar admin nav)

**Step 1: Add link to branded orders**

In admin navigation:
```erb
<%= link_to "Branded Orders", admin_branded_orders_path, class: "admin-nav-link" %>
```

**Step 2: Add badge for pending branded orders**

```erb
<%= link_to admin_branded_orders_path, class: "admin-nav-link" do %>
  Branded Orders
  <% pending_count = Order.branded_orders.where(branded_order_status: ["design_pending", "design_approved"]).count %>
  <% if pending_count > 0 %>
    <span class="badge badge-warning"><%= pending_count %></span>
  <% end %>
<% end %>
```

**Step 3: Commit**

```bash
git add .
git commit -m "Add admin navigation for branded orders

- Link to branded orders in admin sidebar
- Badge showing pending orders count
- Quick access to fulfillment workflow

Views: Admin navigation enhancement"
```

---

### Task 30: Documentation and README updates

**Files:**
- Modify: `README.md`
- Create: `docs/BRANDED_PRODUCTS.md`

**Step 1: Create branded products documentation**

In `docs/BRANDED_PRODUCTS.md`:
```markdown
# Branded Products System

## Overview

The branded products system allows B2B customers to order custom branded packaging with their own designs. After the first order is manufactured, customers can reorder from their dashboard.

## User Workflow

### 1. Initial Order (Customer)
1. Browse customizable products (e.g., "Double Wall Branded Cups")
2. Configure product:
   - Select size (8oz, 12oz, 16oz)
   - Select quantity tier (1000, 2000, 5000, etc.)
   - Upload design file (PDF, PNG, JPG, AI)
3. Add to cart and checkout
4. Order is marked as "design_pending"

### 2. Fulfillment (Admin)
1. View order in Admin > Branded Orders
2. Download customer's design file
3. Update status through fulfillment stages:
   - Design Pending → Design Approved
   - Design Approved → In Production
   - In Production → Production Complete
   - Production Complete → Stock Received
4. When stock arrives, create customer product instance:
   - Auto-filled product name, SKU, stock quantity
   - Set reorder price
   - Copies design to product images
5. Status automatically updates to "Instance Created"
6. Customer is notified their product is ready

### 3. Reorders (Customer)
1. Navigate to "My Branded Products"
2. View all their custom products
3. Select product and quantity
4. Add to cart like standard product
5. No design upload needed (already on file)

## Data Model

### Organizations
- B2B customers belong to organizations
- Team members share access to branded products
- Individual consumers don't have organizations

### Product Types
- **standard**: Regular products with variants (size/color options)
- **customizable_template**: Configurator products (branded cups)
- **customized_instance**: Customer-specific products created after manufacturing

### Pricing
- BrandedProductPrice stores pricing matrix (size × quantity tier)
- BrandedProductPricingService calculates prices based on configuration
- CartItem stores calculated_price at add-to-cart time

### Configuration Storage
- CartItem.configuration: Selected options before purchase
- OrderItem.configuration: Preserved configuration after purchase
- Product.configuration_data: Instance product specifications

## Technical Architecture

### Services
- **BrandedProductPricingService**: Calculate prices from matrix
- **ProductVariantGeneratorService**: Generate variants for standard products
- **BrandedProducts::InstanceCreatorService**: Create customer products

### Controllers
- **BrandedProducts::ConfiguratorController**: AJAX pricing API
- **Organizations::ProductsController**: Customer dashboard
- **Admin::BrandedOrdersController**: Fulfillment workflow

### Stimulus Controllers
- **branded_configurator_controller.js**: Interactive configurator UI

## Configuration

### Pricing Import
Import pricing from CSV:
```ruby
# In db/seeds/branded_product_pricing.rb
pricing_data = [
  { size: "8oz", quantity: 1000, price: 0.26, case_qty: 1000 },
  # ...
]
```

### Product Options
Global reusable options (Size, Color, Material):
```ruby
# In db/seeds/product_options.rb
size_option = ProductOption.create!(name: "Size", display_type: "dropdown")
size_option.values.create!(value: "8oz", position: 1)
```

## Testing

Run branded product tests:
```bash
rails test test/models/branded_product_price_test.rb
rails test test/services/branded_products/
rails test test/controllers/branded_products/
rails test:system test/system/branded_product_ordering_test.rb
```

## Future Enhancements

- Auto-replenishment when stock runs low
- Design approval workflow with customer feedback
- Pricing tiers based on customer volume
- Multiple design variants per product
- Design guidelines PDF generator
```

**Step 2: Update main README**

In `README.md`, add section:
```markdown
## Product Configuration System

This application supports two types of products:

### Standard Products
Products with configurable options (size, color, material) that generate variants automatically.

### Customizable/Branded Products
B2B custom packaging with:
- Interactive configurator (BrandYour-inspired)
- Design file uploads
- Quantity-based pricing tiers
- Organization product instances for reordering

See [docs/BRANDED_PRODUCTS.md](/BRANDED_PRODUCTS.md) for detailed documentation.
```

**Step 3: Commit**

```bash
git add .
git commit -m "Add documentation for branded products system

- Complete workflow documentation
- Data model overview
- Technical architecture details
- Testing instructions
- Future enhancement ideas
- Updated main README

Docs: Comprehensive branded products guide"
```

---

## Final Phase: Verification & Cleanup

### Task 31: Run full test suite and verify coverage

**Step 1: Run all tests**

```bash
rails test
```

**Step 2: Run system tests**

```bash
rails test:system
```

**Step 3: Check test coverage**

Review SimpleCov output:
- Target: Maintain or improve from 55.54% baseline
- Focus on service objects and controllers

**Step 4: Commit if any fixes needed**

```bash
git add .
git commit -m "Final test suite verification

All tests passing:
- XXX total tests
- XXX assertions
- 0 failures, 0 errors
- Coverage: XX.XX%

Ready for code review"
```

---

### Task 32: Code review and refinement

**Step 1: Run RuboCop**

```bash
rubocop
```

Fix any style violations.

**Step 2: Run Brakeman security scan**

```bash
brakeman
```

Address any security warnings.

**Step 3: Review database migrations**

- Verify all migrations are reversible
- Check indexes are in place
- Confirm foreign keys are correct

**Step 4: Commit cleanup**

```bash
git add .
git commit -m "Code quality cleanup

- Fixed RuboCop violations
- Addressed Brakeman security warnings
- Verified migration reversibility
- Added missing indexes

Ready for code review"
```

---

## Phase 14: Standard Product Unit Pricing Refactoring

### Task 33: Refactor standard products to use unit pricing

**Background:** For consistency across the site, all products should use unit pricing (not pack pricing). This ensures customers always see price-per-unit and quantity in units, whether ordering standard or customizable products.

**Files:**
- Modify: `app/models/product_variant.rb`
- Modify: `app/views/products/_standard_product.html.erb`
- Modify: `app/views/cart_items/_cart_item.html.erb`
- Create: `db/migrate/XXXXXX_convert_pack_pricing_to_unit_pricing.rb`
- Modify: `test/models/product_variant_test.rb`

**Step 1: Add unit_price helper to ProductVariant**

In `app/models/product_variant.rb`, add:
```ruby
  # Convert pack price to unit price for display
  # If pac_size is set, price is per pack, so divide to get per-unit price
  # Otherwise, price is already per unit
  def unit_price
    return price unless pac_size.present? && pac_size > 0
    price / pac_size
  end

  # Returns minimum order quantity in units
  def minimum_order_units
    pac_size || 1
  end
```

**Step 2: Update product display to show unit pricing**

In product views, change from showing pack price to showing unit price with pack info:
```erb
<div class="text-2xl font-bold">
  <%= number_to_currency(variant.unit_price, precision: 4) %>/unit
</div>
<div class="text-sm text-gray-600">
  Sold in packs of <%= variant.pac_size %> (<%= number_to_currency(variant.price) %> per pack)
</div>
```

**Step 3: Update cart to use units consistently**

Already done! Cart now works with units for both product types.

**Step 4: Add data migration (optional for future)**

Create migration to convert existing pack prices to unit prices in database:
```ruby
class ConvertPackPricingToUnitPricing < ActiveRecord::Migration[8.0]
  def up
    ProductVariant.find_each do |variant|
      next unless variant.pac_size.present? && variant.pac_size > 0

      # Convert pack price to unit price
      variant.update_column(:price, variant.price / variant.pac_size)
    end
  end

  def down
    # Reversing requires knowing original pack prices - skip or handle separately
    raise ActiveRecord::IrreversibleMigration
  end
end
```

**Step 5: Update tests**

Update test expectations to use unit pricing.

**Step 6: Update admin product forms**

Update admin product variant forms to clarify price is per-unit, with pack size as separate field.

**Step 7: Commit**

```bash
git add .
git commit -m "Refactor standard products to use unit pricing

- Add unit_price helper to ProductVariant
- Update product displays to show price per unit
- Show pack size as informational metadata
- Consistent unit pricing across all product types
- Cart already handles units correctly

Tests: All tests passing with unit pricing"
```

**Note:** This task ensures consistent UX where all products (standard and customizable) use unit-based pricing and quantities.

---

### Task 34: Replace cart quantity inputs with intelligent dropdowns

**Background:** After unit pricing refactor (Task 33), all products use unit quantities. Replace text field quantity editors with smart dropdowns that respect stock availability and minimum orders.

**Files:**
- Modify: `app/views/cart_items/_cart_item.html.erb`
- Modify: `app/views/products/_standard_product.html.erb`

**Implementation:**

For cart items, replace the Alpine.js +/- buttons with a dropdown:
```erb
<%
  variant = cart_item.product_variant
  min_order = variant.pac_size || 1
  available_stock = variant.stock_quantity
  max_qty = [available_stock, 10000].min

  # Generate options in appropriate increments
  if min_order >= 500
    # Bulk products: 500 unit increments
    quantity_options = (min_order..max_qty).step(500).to_a
  else
    # Standard products: 1, 2, 3, 5, 10, 20, 50, 100...
    quantity_options = [1, 2, 3, 5, 10, 20, 50, 100, 200, 500].select { |q| q >= min_order && q <= max_qty }
  end

  # Always include current quantity and available stock
  quantity_options << cart_item.quantity unless quantity_options.include?(cart_item.quantity)
  quantity_options << available_stock if available_stock <= max_qty && !quantity_options.include?(available_stock)
  quantity_options.sort!
%>

<%= form_with(model: cart_item, url: cart_cart_item_path(cart_item), method: :patch, local: false) do |form| %>
  <%= form.select :quantity,
                  options_for_select(quantity_options.map { |q| [number_with_delimiter(q), q] }, cart_item.quantity),
                  {},
                  class: "select select-sm select-bordered",
                  onchange: "this.form.requestSubmit()" %>
<% end %>
```

**Benefits:**
- Respects available stock (can't order more than available)
- Smart increments (1s for small items, 500s for bulk)
- Shows current quantity if non-standard
- Auto-submits on change (no +/- buttons needed)
- Consistent with reorder page UX

**Commit:**
```bash
git add .
git commit -m "Replace cart quantity inputs with stock-aware dropdowns

- Smart quantity options based on product type and stock
- Bulk products (pac_size >= 500): 500 unit increments
- Standard products: 1, 2, 3, 5, 10, 20, 50, 100...
- Respects available stock limits
- Auto-submit on selection change
- Consistent UX with reorder pages

Tests: Cart functionality tests passing"
```

---

### Task 35: Make add to cart open drawer for branded products

**Background:** Currently, adding a configured product to cart redirects to `/cart`. For consistency with standard products, it should open the cart drawer/sidebar instead.

**Files:**
- Modify: `app/frontend/javascript/controllers/branded_configurator_controller.js`
- Verify: Cart drawer Stimulus controller exists and is accessible

**Implementation:**

**Step 1: Check how standard products open the drawer**

In `app/views/products/_standard_product.html.erb`, the form has:
```erb
data: { controller: "cart-drawer", action: "turbo:submit-end->cart-drawer#open" }
```

**Step 2: Update branded configurator to trigger drawer**

In `branded_configurator_controller.js`, change the `addToCart` method:

From:
```javascript
if (response.ok) {
  window.location.href = "/cart"
}
```

To:
```javascript
if (response.ok) {
  // Trigger Turbo Stream to update cart
  // Then dispatch event to open cart drawer
  const event = new CustomEvent('cart:item-added')
  window.dispatchEvent(event)

  // If cart drawer controller exists, open it
  const drawerController = this.application.getControllerForElementAndIdentifier(
    document.querySelector('[data-controller~="cart-drawer"]'),
    'cart-drawer'
  )
  if (drawerController) {
    drawerController.open()
  }
}
```

**Step 3: Alternative approach - Use Turbo Stream response**

Update `CartItemsController#create_configured_cart_item` to return Turbo Stream:
```ruby
if cart_item.save
  respond_to do |format|
    format.html { redirect_to cart_path, notice: "Configured product added to cart" }
    format.turbo_stream {
      render turbo_stream: [
        turbo_stream.replace("cart-drawer-content", partial: "shared/drawer_cart_content"),
        turbo_stream.append("notifications", partial: "shared/notification", locals: { message: "Added to cart" })
      ]
    }
    format.json { render json: { success: true, cart_item: cart_item }, status: :created }
  end
end
```

And update JavaScript to make Turbo Stream request:
```javascript
const response = await fetch("/cart/cart_items", {
  method: "POST",
  headers: {
    "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
    "Accept": "text/vnd.turbo-stream.html"
  },
  body: formData
})
```

**Step 4: Test both product types**

- Add standard product → cart drawer opens ✓
- Add configured product → cart drawer opens ✓
- Cart drawer shows both product types correctly ✓

**Step 5: Commit**

```bash
git add .
git commit -m "Make branded products open cart drawer on add

- Updated branded configurator to trigger cart drawer
- Consistent UX: both standard and configured products open drawer
- Uses Turbo Stream for seamless cart updates
- No full page redirect needed

UX: Faster, smoother add-to-cart experience"
```

---

### Task 36: Add finish selection to branded product configurator

**Background:** Allow customers to choose between Matt and Gloss finish for branded cups, matching BrandYour's offering.

**Implementation:** Add finish selection step with buttons, update configuration storage, renumber steps.

**Commit:** "Add finish selection (Matt/Gloss) to configurator"

---

### Task 37: Add input validation and error messaging to configurator

**Background:** Improve UX with better validation feedback, visual completion indicators, and proper disabled button styling.

**Implementation:** Add step completion checkmarks, inline error messages, dimmed disabled button state, file upload validation feedback.

**Commit:** "Add validation feedback and visual states to configurator"

---

## Implementation Complete!

This plan provides **37 comprehensive tasks** covering:

✅ **Phase 1**: Organizations & Product Options foundation
✅ **Phase 2**: Product model enhancements
✅ **Phase 3**: Branded product pricing system
✅ **Phase 4**: Cart & order updates
✅ **Phase 5**: Branded configurator UI (Stimulus + views)
✅ **Phase 6**: Cart integration for configurations
✅ **Phase 7**: Customer dashboard
✅ **Phase 8**: Admin fulfillment workflow
✅ **Phase 9**: Instance product creation service
✅ **Phase 10**: Checkout & organization integration
✅ **Phase 11**: Standard product refactoring
✅ **Phase 12**: Seed data & migrations
✅ **Phase 13**: System tests & integration
✅ **Final**: Documentation, verification, cleanup

Each task follows **RED-GREEN-REFACTOR TDD** with:
- Exact file paths
- Complete code samples
- Test commands with expected output
- Commit messages

**Total estimated implementation time**: 20-30 hours for experienced developer

The plan is ready for execution!
