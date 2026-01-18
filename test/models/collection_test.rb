require "test_helper"

class CollectionTest < ActiveSupport::TestCase
  setup do
    @collection = collections(:coffee_shop_essentials)
    @valid_attributes = {
      name: "Test Collection",
      slug: "test-collection",
      position: 10
    }
  end

  # ==========================================================================
  # Validation tests
  # ==========================================================================

  test "validates presence of name" do
    collection = Collection.new(@valid_attributes.except(:name))
    assert_not collection.valid?
    assert_includes collection.errors[:name], "can't be blank"
  end

  test "validates presence of slug" do
    # Name with blank slug will auto-generate, so test with blank name too
    collection = Collection.new(name: nil, slug: nil)
    assert_not collection.valid?
    assert_includes collection.errors[:slug], "can't be blank"
  end

  test "validates uniqueness of slug" do
    existing = Collection.create!(@valid_attributes)
    collection = Collection.new(@valid_attributes)
    assert_not collection.valid?
    assert_includes collection.errors[:slug], "has already been taken"
  end

  test "allows same name with different slug" do
    existing = Collection.create!(name: "Test Collection", slug: "test-collection-1", position: 10)
    collection = Collection.new(name: "Test Collection", slug: "test-collection-2", position: 11)
    assert collection.valid?
  end

  test "valid collection can be saved" do
    collection = Collection.new(@valid_attributes.merge(slug: "unique-slug-#{SecureRandom.hex(4)}"))
    assert collection.save
    assert_not_nil collection.id
  end

  test "invalid collection cannot be saved" do
    collection = Collection.new(name: nil, slug: nil)
    assert_not collection.save
    assert_nil collection.id
  end

  # ==========================================================================
  # Slug generation tests
  # ==========================================================================

  test "generates slug from name if slug is blank" do
    collection = Collection.new(name: "Coffee Shop Essentials")
    collection.valid?  # Triggers before_validation callback
    assert_equal "coffee-shop-essentials", collection.slug
  end

  test "does not override existing slug" do
    collection = Collection.new(name: "Coffee Shop", slug: "custom-slug")
    collection.valid?
    assert_equal "custom-slug", collection.slug
  end

  test "slug handles special characters" do
    collection = Collection.new(name: "Café & Restaurant Supplies")
    collection.valid?
    assert_equal "cafe-restaurant-supplies", collection.slug
  end

  test "slug handles uppercase" do
    collection = Collection.new(name: "RESTAURANT ESSENTIALS")
    collection.valid?
    assert_equal "restaurant-essentials", collection.slug
  end

  # ==========================================================================
  # to_param tests
  # ==========================================================================

  test "to_param returns slug" do
    assert_equal "coffee-shop-essentials", @collection.to_param
  end

  test "to_param returns slug for URL generation" do
    collection = Collection.create!(name: "New Collection", slug: "new-collection", position: 99)
    assert_equal "new-collection", collection.to_param
  end

  # ==========================================================================
  # Scope tests
  # ==========================================================================

  test "featured scope returns only featured collections" do
    featured = Collection.featured

    assert_includes featured, collections(:coffee_shop_essentials)
    assert_includes featured, collections(:empty_collection)
    assert_not_includes featured, collections(:restaurant_supplies)
    assert_not_includes featured, collections(:coffee_shop_sample_pack)
  end

  test "sample_packs scope returns only sample pack collections" do
    sample_packs = Collection.sample_packs

    assert_includes sample_packs, collections(:coffee_shop_sample_pack)
    assert_not_includes sample_packs, collections(:coffee_shop_essentials)
    assert_not_includes sample_packs, collections(:restaurant_supplies)
  end

  test "regular scope excludes sample packs" do
    regular = Collection.regular

    assert_includes regular, collections(:coffee_shop_essentials)
    assert_includes regular, collections(:restaurant_supplies)
    assert_not_includes regular, collections(:coffee_shop_sample_pack)
  end

  test "by_position scope orders by position" do
    collections = Collection.regular.by_position

    assert_operator collections.first.position, :<=, collections.last.position
  end

  # ==========================================================================
  # Association tests
  # ==========================================================================

  test "has many collection_items" do
    assert_respond_to @collection, :collection_items
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @collection.collection_items
  end

  test "has many products through collection_items" do
    assert_respond_to @collection, :products
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @collection.products
  end

  test "products association returns Product instances" do
    assert @collection.products.count > 0, "Fixture should have products"
    assert_kind_of Product, @collection.products.first
  end

  test "collection can have multiple products" do
    assert_operator @collection.products.count, :>, 1
  end

  test "destroying collection destroys collection_items" do
    collection = collections(:restaurant_supplies)
    item_count = collection.collection_items.count
    assert item_count > 0, "Should have items to test destruction"

    collection.destroy

    assert_equal 0, CollectionItem.where(collection_id: collection.id).count
  end

  # ==========================================================================
  # Visible products tests
  # ==========================================================================

  test "visible_products returns active catalog products" do
    visible = @collection.visible_products

    visible.each do |product|
      assert product.active?, "Product should be active"
      assert_includes %w[standard customizable_template], product.product_type,
        "Product should be a catalog product type"
    end
  end

  test "visible_products excludes inactive products" do
    # Add an inactive product to the collection
    inactive_product = products(:inactive_product)
    @collection.collection_items.create!(product: inactive_product)

    visible = @collection.visible_products
    assert_not_includes visible, inactive_product
  end

  # ==========================================================================
  # Sample eligible products tests
  # ==========================================================================

  test "sample_eligible_products returns sample-eligible products" do
    sample_pack = collections(:coffee_shop_sample_pack)
    eligible = sample_pack.sample_eligible_products

    eligible.each do |product|
      assert product.sample_eligible?, "Product should be sample eligible"
    end
  end

  # ==========================================================================
  # Edge cases
  # ==========================================================================

  test "empty collection has no products" do
    empty = collections(:empty_collection)
    assert_equal 0, empty.products.count
  end

  test "collection can have image attachment" do
    assert_respond_to @collection, :image
  end
end
