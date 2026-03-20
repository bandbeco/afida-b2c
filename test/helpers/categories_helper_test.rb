require "test_helper"

class CategoriesHelperTest < ActionView::TestCase
  test "category_question_heading for subcategory includes parent context" do
    parent = Category.new(name: "Cups & Drinks", slug: "cups-and-drinks")
    child = Category.new(name: "Hot Cups", slug: "hot-cups")
    child.parent = parent

    result = category_question_heading(child)
    assert_includes result, "?"
    assert_includes result.downcase, "hot cups"
  end

  test "category_question_heading for top-level category" do
    parent = Category.new(name: "Hot Food", slug: "hot-food")

    result = category_question_heading(parent)
    assert_includes result, "?"
    assert_includes result.downcase, "hot food"
  end

  test "category_question_heading uses custom mapping when available" do
    category = Category.new(name: "Cups & Drinks", slug: "cups-and-drinks")

    result = category_question_heading(category)
    assert_includes result, "?"
  end

  test "category_question_heading generates sensible fallback for unknown categories" do
    category = Category.new(name: "Mystery Items", slug: "mystery-items")

    result = category_question_heading(category)
    assert_includes result, "?"
    assert_includes result, "Mystery Items"
  end

  test "RELATED_CATEGORIES values are all also keys in the mapping" do
    all_keys = CategoriesHelper::RELATED_CATEGORIES.keys

    CategoriesHelper::RELATED_CATEGORIES.each do |slug, related|
      related.each do |related_slug|
        assert_includes all_keys, related_slug,
          "RELATED_CATEGORIES['#{slug}'] references '#{related_slug}' which has no mapping of its own"
      end
    end
  end

  test "RELATED_CATEGORIES does not reference itself" do
    CategoriesHelper::RELATED_CATEGORIES.each do |slug, related|
      refute_includes related, slug, "RELATED_CATEGORIES['#{slug}'] references itself"
    end
  end

  test "RELATED_CATEGORIES has at least two related categories per entry" do
    CategoriesHelper::RELATED_CATEGORIES.each do |slug, related|
      assert related.length >= 2, "RELATED_CATEGORIES['#{slug}'] should have at least 2 related categories"
    end
  end

  test "related_categories_for returns categories for a mapped slug" do
    # straws fixture exists and is in the mapping
    category = categories(:straws)
    result = related_categories_for(category)
    assert_respond_to result, :each
  end

  test "related_categories_for returns empty array for unmapped category" do
    category = categories(:one)
    result = related_categories_for(category)
    assert_equal [], result
  end

  test "related_categories_for returns empty array for nil" do
    assert_equal [], related_categories_for(nil)
  end
end
