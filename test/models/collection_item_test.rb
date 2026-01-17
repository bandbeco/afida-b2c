require "test_helper"

class CollectionItemTest < ActiveSupport::TestCase
  setup do
    @collection = collections(:coffee_shop_essentials)
    @product = products(:two)  # A product not already in this collection
    @collection_item = collection_items(:coffee_shop_cup_1)
  end

  # ==========================================================================
  # Association tests
  # ==========================================================================

  test "belongs to collection" do
    assert_respond_to @collection_item, :collection
    assert_kind_of Collection, @collection_item.collection
  end

  test "belongs to product" do
    assert_respond_to @collection_item, :product
    assert_kind_of Product, @collection_item.product
  end

  test "valid collection item can be saved" do
    item = CollectionItem.new(
      collection: collections(:empty_collection),
      product: products(:one),
      position: 1
    )
    assert item.save
    assert_not_nil item.id
  end

  # ==========================================================================
  # Validation tests
  # ==========================================================================

  test "validates uniqueness of product within collection" do
    existing_product = @collection_item.product

    duplicate = CollectionItem.new(
      collection: @collection,
      product: existing_product,
      position: 99
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:collection_id], "already contains this product"
  end

  test "allows same product in different collections" do
    product = @collection_item.product

    # This product is in coffee_shop_essentials, try adding to restaurant_supplies
    item = CollectionItem.new(
      collection: collections(:restaurant_supplies),
      product: product,
      position: 99
    )

    assert item.valid?
  end

  test "requires collection" do
    item = CollectionItem.new(product: products(:one), position: 1)
    assert_not item.valid?
    assert_includes item.errors[:collection], "must exist"
  end

  test "requires product" do
    item = CollectionItem.new(collection: @collection, position: 1)
    assert_not item.valid?
    assert_includes item.errors[:product], "must exist"
  end

  # ==========================================================================
  # Position/ordering tests
  # ==========================================================================

  test "acts_as_list assigns position on create" do
    item = CollectionItem.create!(
      collection: collections(:empty_collection),
      product: products(:one)
    )
    # acts_as_list assigns position starting from 1 (or next available)
    assert_not_nil item.position
    assert_operator item.position, :>=, 1
  end

  test "collection_items are ordered by position" do
    items = @collection.collection_items.to_a

    items.each_cons(2) do |first, second|
      assert_operator first.position, :<=, second.position,
        "Items should be ordered by position"
    end
  end

  test "acts_as_list moves item higher" do
    item = collection_items(:coffee_shop_cup_2)  # position 2
    original_position = item.position

    item.move_higher

    item.reload
    assert_operator item.position, :<, original_position
  end

  test "acts_as_list moves item lower" do
    item = collection_items(:coffee_shop_cup_1)  # position 1
    original_position = item.position

    item.move_lower

    item.reload
    assert_operator item.position, :>, original_position
  end

  # ==========================================================================
  # Cascade delete tests
  # ==========================================================================

  test "deleting product destroys collection items" do
    # Create a fresh product with no dependent records
    product = Product.create!(
      name: "Deletable Product",
      sku: "DEL-PROD-#{SecureRandom.hex(4)}",
      price: 10.0,
      category: categories(:one),
      active: true
    )

    # Add it to a collection
    collection = collections(:empty_collection)
    item = CollectionItem.create!(collection: collection, product: product)
    item_id = item.id

    # Verify item exists
    assert CollectionItem.exists?(item_id)

    # Delete product
    product.destroy

    # Item should be gone
    assert_not CollectionItem.exists?(item_id)
  end

  test "deleting collection destroys collection items" do
    collection = collections(:restaurant_supplies)
    item_count = collection.collection_items.count
    assert item_count > 0, "Should have collection items to test destruction"

    collection.destroy

    assert_equal 0, CollectionItem.where(collection_id: collection.id).count
  end
end
