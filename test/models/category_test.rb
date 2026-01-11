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
end
