require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  setup do
    @category = categories(:one)
    @valid_attributes = {
      name: "Test Category",
      slug: "test-category",
      position: 1
    }
  end

  # Validation tests
  test "validates presence of name" do
    category = Category.new(@valid_attributes.except(:name))
    assert_not category.valid?
    assert_includes category.errors[:name], "can't be blank"
  end

  test "validates presence of slug" do
    category = Category.new(@valid_attributes.except(:slug))
    assert_not category.valid?
    assert_includes category.errors[:slug], "can't be blank"
  end

  test "validates uniqueness of slug" do
    existing = Category.create!(@valid_attributes)
    category = Category.new(@valid_attributes)
    assert_not category.valid?
    assert_includes category.errors[:slug], "has already been taken"
  end

  test "allows same name with different slug" do
    existing = Category.create!(name: "Eco Products", slug: "eco-products", position: 10)
    category = Category.new(name: "Eco Products", slug: "eco-products-uk", position: 11)
    assert category.valid?
  end

  # Method tests
  test "generate_slug creates slug from name" do
    category = Category.new(name: "Eco Friendly Products")
    category.generate_slug
    assert_equal "eco-friendly-products", category.slug
  end

  test "generate_slug handles special characters" do
    category = Category.new(name: "Café & Restaurant Supplies")
    category.generate_slug
    assert_equal "cafe-restaurant-supplies", category.slug
  end

  test "generate_slug handles uppercase" do
    category = Category.new(name: "DISPOSABLE CUTLERY")
    category.generate_slug
    assert_equal "disposable-cutlery", category.slug
  end

  test "generate_slug does not override existing slug" do
    category = Category.new(name: "Test Category", slug: "custom-slug")
    category.generate_slug
    assert_equal "custom-slug", category.slug
  end

  test "generate_slug does nothing when name is blank" do
    category = Category.new(slug: "existing-slug")
    category.generate_slug
    assert_equal "existing-slug", category.slug
  end

  test "generate_slug does nothing when slug is already present" do
    category = Category.new(name: "New Name", slug: "old-slug")
    category.generate_slug
    assert_equal "old-slug", category.slug
  end

  test "to_param returns slug" do
    category = Category.create!(@valid_attributes)
    assert_equal "test-category", category.to_param
  end

  test "to_param returns slug for URL generation" do
    category = Category.create!(name: "Eco Products", slug: "eco-products", position: 12)
    assert_equal "eco-products", category.to_param
  end

  # Scope tests
  test "browsable scope excludes branded products category" do
    branded = categories(:branded)
    browsable = Category.browsable

    assert_not_includes browsable, branded
  end

  test "browsable scope includes non-branded categories" do
    cups = categories(:cups)
    straws = categories(:straws)
    browsable = Category.browsable

    assert_includes browsable, cups
    assert_includes browsable, straws
  end

  # Association tests
  test "has many products" do
    assert_respond_to @category, :products
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @category.products
  end

  test "can have multiple products" do
    initial_count = @category.products.count

    product1 = @category.products.create!(
      name: "Product 1",
      sku: "PROD1",
      price: 10.0,
      active: true
    )
    product2 = @category.products.create!(
      name: "Product 2",
      sku: "PROD2",
      price: 20.0,
      active: true
    )

    assert_includes @category.products, product1
    assert_includes @category.products, product2
    assert_equal initial_count + 2, @category.products.count
  end

  test "products association returns Product instances" do
    product = @category.products.create!(
      name: "Test Product",
      sku: "TEST123",
      price: 15.0,
      active: true
    )

    assert_kind_of Product, @category.products.first
  end

  # Edge cases
  test "slug with multiple spaces becomes single dash" do
    category = Category.new(name: "Multiple    Spaces    Here")
    category.generate_slug
    assert_equal "multiple-spaces-here", category.slug
  end

  test "slug removes leading and trailing spaces" do
    category = Category.new(name: "  Trimmed Category  ")
    category.generate_slug
    assert_equal "trimmed-category", category.slug
  end

  test "valid category can be saved" do
    category = Category.new(@valid_attributes.merge(slug: "unique-slug"))
    assert category.save
    assert_not_nil category.id
  end

  test "invalid category cannot be saved" do
    category = Category.new(name: nil, slug: nil)
    assert_not category.save
    assert_nil category.id
  end

  # Parent/child hierarchy tests
  test "category can have a parent" do
    child = categories(:child_hot_cups)
    parent = categories(:parent_cups_and_drinks)
    assert_equal parent, child.parent
  end

  test "parent category has many children" do
    parent = categories(:parent_cups_and_drinks)
    assert_includes parent.children, categories(:child_hot_cups)
    assert_includes parent.children, categories(:child_cold_cups)
    assert_equal 2, parent.children.count
  end

  test "top-level category has nil parent" do
    parent = categories(:parent_cups_and_drinks)
    assert_nil parent.parent_id
    assert_nil parent.parent
  end

  test "top_level scope returns only categories without parent" do
    top_level = Category.top_level
    top_level.each do |cat|
      assert_nil cat.parent_id
    end
  end

  test "subcategories scope returns only categories with parent" do
    subcategories = Category.subcategories
    subcategories.each do |cat|
      assert_not_nil cat.parent_id
    end
  end

  test "destroying parent with children is prevented" do
    parent = categories(:parent_cups_and_drinks)
    assert_not parent.destroy
  end

  test "acts_as_list is scoped to parent_id" do
    parent = categories(:parent_cups_and_drinks)
    child1 = categories(:child_hot_cups)
    child2 = categories(:child_cold_cups)
    assert_equal 1, child1.position
    assert_equal 2, child2.position
  end

  test "parent category can access products through children" do
    parent = categories(:parent_hot_food)
    child_pizza = categories(:child_pizza_boxes)
    child_takeaway = categories(:child_takeaway_boxes)

    assert child_pizza.products.exists?
    assert child_takeaway.products.exists?
    assert_equal 0, parent.products.count

    all_child_ids = parent.children.pluck(:id)
    all_products = Product.where(category_id: all_child_ids)
    assert all_products.count >= 2
  end

  test "multiple parents have independent children" do
    cups_parent = categories(:parent_cups_and_drinks)
    food_parent = categories(:parent_hot_food)

    cups_children = cups_parent.children.pluck(:id)
    food_children = food_parent.children.pluck(:id)

    assert_empty cups_children & food_children
  end

  test "parent cannot be self" do
    category = categories(:parent_cups_and_drinks)
    category.parent_id = category.id
    assert_not category.valid?
    assert_includes category.errors[:parent].join, "cannot be the category itself"
  end

  test "max nesting depth prevents three levels" do
    grandchild = Category.new(
      name: "Grandchild",
      slug: "grandchild-test",
      parent: categories(:child_hot_cups)
    )
    assert_not grandchild.valid?
    assert_includes grandchild.errors[:parent].join, "two levels"
  end
end
