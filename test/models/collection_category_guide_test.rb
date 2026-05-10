require "test_helper"

class CollectionCategoryGuideTest < ActiveSupport::TestCase
  def setup
    @collection = collections(:vegware)
    @category = categories(:parent_cups_and_drinks)
  end

  # Persistence tests use a fresh (collection, category) pair so they don't
  # collide with the fixture row that already pairs vegware with cups-and-drinks.
  def fresh_collection
    Collection.create!(name: "Throwaway", slug: "throwaway-#{SecureRandom.hex(4)}")
  end

  def fresh_category
    Category.create!(name: "Throwaway", slug: "throwaway-#{SecureRandom.hex(4)}")
  end

  test "buying_guide can be set and read back" do
    guide = CollectionCategoryGuide.create!(
      collection: fresh_collection,
      category: fresh_category,
      buying_guide: "## Test Guide\n\nSome content."
    )
    guide.reload
    assert_equal "## Test Guide\n\nSome content.", guide.buying_guide
  end

  test "blank buying_guide is treated as no guide" do
    guide = CollectionCategoryGuide.create!(
      collection: fresh_collection,
      category: fresh_category,
      buying_guide: ""
    )
    guide.reload
    assert_not guide.buying_guide.present?
  end

  test "nil buying_guide is treated as no guide" do
    guide = CollectionCategoryGuide.create!(
      collection: fresh_collection,
      category: fresh_category,
      buying_guide: nil
    )
    guide.reload
    assert_nil guide.buying_guide
  end

  test "(collection_id, category_id) must be unique" do
    duplicate = CollectionCategoryGuide.new(
      collection: @collection,
      category: @category,
      buying_guide: "second"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:collection_id], "has already been taken"
  end

  test "requires a collection" do
    guide = CollectionCategoryGuide.new(category: fresh_category, buying_guide: "x")
    assert_not guide.valid?
    assert_includes guide.errors[:collection], "must exist"
  end

  test "requires a category" do
    guide = CollectionCategoryGuide.new(collection: fresh_collection, buying_guide: "x")
    assert_not guide.valid?
    assert_includes guide.errors[:category], "must exist"
  end

  test "CollectionCategoryGuide.for returns the row for a (collection, category) pair" do
    expected = collection_category_guides(:vegware_cups_and_drinks)
    assert_equal expected, CollectionCategoryGuide.for(@collection, @category)
  end

  test "CollectionCategoryGuide.for returns nil when no row exists" do
    other_category = categories(:parent_hot_food)
    assert_nil CollectionCategoryGuide.for(@collection, other_category)
  end

  test "CollectionCategoryGuide.for returns nil when collection is nil" do
    assert_nil CollectionCategoryGuide.for(nil, @category)
  end

  test "CollectionCategoryGuide.for returns nil when category is nil" do
    assert_nil CollectionCategoryGuide.for(@collection, nil)
  end

  test "destroying a collection destroys its CollectionCategoryGuides" do
    collection = fresh_collection
    CollectionCategoryGuide.create!(
      collection: collection,
      category: fresh_category,
      buying_guide: "x"
    )
    assert_difference "CollectionCategoryGuide.count", -1 do
      collection.destroy
    end
  end

  test "destroying a category destroys its CollectionCategoryGuides" do
    category = fresh_category
    CollectionCategoryGuide.create!(
      collection: fresh_collection,
      category: category,
      buying_guide: "x"
    )
    assert_difference "CollectionCategoryGuide.count", -1 do
      category.destroy
    end
  end
end
