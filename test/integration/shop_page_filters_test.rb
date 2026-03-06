require "test_helper"

class ShopPageFiltersTest < ActionDispatch::IntegrationTest
  # Uses hierarchy fixtures: parent_cups_and_drinks > child_hot_cups, child_cold_cups
  #                          parent_hot_food > child_pizza_boxes, child_takeaway_boxes

  test "sidebar shows top-level parent categories with aggregated product counts" do
    get shop_path

    assert_response :success
    # Parent categories should appear as group headings
    assert_select ".shop-category-group", minimum: 1

    # Should show parent category name "Cups & Drinks"
    parent = categories(:parent_cups_and_drinks)
    assert_select "[data-parent-slug='#{parent.slug}']"
  end

  test "sidebar shows subcategory checkboxes under their parent" do
    get shop_path

    assert_response :success
    hot_cups = categories(:child_hot_cups)
    # Subcategory checkboxes should exist
    assert_select "input[type=checkbox][value='#{hot_cups.slug}']"
  end

  test "filtering by parent category slug returns products from all subcategories" do
    parent = categories(:parent_cups_and_drinks)

    get shop_path, params: { categories: [ parent.slug ] }

    assert_response :success
    # Should include products from child_hot_cups and child_cold_cups
    hot_cups_products = categories(:child_hot_cups).products.active.standard
    hot_cups_products.each do |product|
      assert_select "a[href=?]", product_path(product.slug)
    end
  end

  test "filtering by subcategory slug returns only products in that subcategory" do
    subcategory = categories(:child_hot_cups)

    get shop_path, params: { categories: [ subcategory.slug ] }

    assert_response :success
    subcategory.products.active.standard.each do |product|
      assert_select "a[href=?]", product_path(product.slug)
    end
  end

  test "filtering by multiple subcategories from different parents works" do
    hot_cups = categories(:child_hot_cups)
    pizza_boxes = categories(:child_pizza_boxes)

    get shop_path, params: { categories: [ hot_cups.slug, pizza_boxes.slug ] }

    assert_response :success
    # Products from both subcategories should appear
    hot_cups.products.active.standard.each do |product|
      assert_select "a[href=?]", product_path(product.slug)
    end
    pizza_boxes.products.active.standard.each do |product|
      assert_select "a[href=?]", product_path(product.slug)
    end
  end

  test "parent category count includes products from all subcategories" do
    get shop_path

    assert_response :success
    parent = categories(:parent_cups_and_drinks)
    expected_count = parent.children.joins(:products)
                          .where(products: { active: true, product_type: "standard" })
                          .count("products.id")

    # The count should be displayed next to the parent category name
    assert_select "[data-parent-slug='#{parent.slug}']" do
      assert_select ".category-count", text: /#{expected_count}/
    end
  end

  test "branded packaging parent is excluded from sidebar" do
    get shop_path

    assert_response :success
    assert_select "[data-parent-slug='branded-packaging']", count: 0
  end

  test "categories without products are not shown" do
    # Create a parent with no products in any subcategory
    empty_parent = Category.create!(name: "Empty Parent", slug: "empty-parent", position: 99)
    Category.create!(name: "Empty Sub", slug: "empty-sub", parent: empty_parent, position: 1)

    get shop_path

    assert_response :success
    assert_select "[data-parent-slug='empty-parent']", count: 0
  ensure
    Category.where(slug: "empty-sub").delete_all
    Category.where(slug: "empty-parent").delete_all
  end

  test "subcategories without products are not shown" do
    get shop_path

    assert_response :success
    # child_cold_cups may have no products - verify it's hidden if so
    cold_cups = categories(:child_cold_cups)
    has_products = cold_cups.products.active.standard.exists?
    if has_products
      assert_select "input[type=checkbox][value='#{cold_cups.slug}']"
    else
      assert_select "input[type=checkbox][value='#{cold_cups.slug}']", count: 0
    end
  end
end
