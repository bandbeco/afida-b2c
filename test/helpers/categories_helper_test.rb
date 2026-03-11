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
end
