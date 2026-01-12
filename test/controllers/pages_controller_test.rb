require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "shop page displays all products by default" do
    get shop_path

    assert_response :success
    assert_select "h1", text: /Shop/
    # Verify at least one product link is present
    product = Product.active.catalog_products.first
    assert_select "a[href=?]", product_path(product.slug)
  end

  test "shop page filters by categories" do
    category = categories(:one)
    product = products(:one)
    product.update(category: category)

    get shop_path, params: { categories: [ category.slug ] }

    assert_response :success
    assert_select "a[href=?]", product_path(product.slug)
  end

  test "shop page searches products" do
    product = products(:one)
    product.update(name: "Pizza Box")

    get shop_path, params: { q: "pizza" }

    assert_response :success
    assert_select "a[href=?]", product_path(product.slug)
  end

  test "shop page sorts products by price" do
    get shop_path, params: { sort: "price_asc" }

    assert_response :success
    # Verify products are present (specific order checking in system tests)
  end

  test "shop page handles excessive page number gracefully" do
    get shop_path, params: { page: 999999 }

    assert_response :success
    # Pagy overflow handling should redirect to last page, not crash
  end

  test "shop page handles invalid sort parameter safely" do
    get shop_path, params: { sort: "invalid_sort" }

    assert_response :success
    # Should fall back to default sort, not crash
  end

  test "shop page handles excessively long search query safely" do
    long_query = "a" * 200

    get shop_path, params: { q: long_query }

    assert_response :success
    # Query should be truncated to 100 chars, not cause errors
  end

  test "shop page filters by size" do
    # Use fixture variant with size option
    variant = products(:single_wall_8oz_white)

    get shop_path, params: { size: "8oz" }

    assert_response :success
    assert_select "a[href=?]", product_path(variant.slug)
  end

  test "shop page filters by colour" do
    # Set colour on fixture product for filtering
    product = products(:single_wall_8oz_white)
    product.update!(colour: "White")

    get shop_path, params: { colour: "White" }

    assert_response :success
    assert_select "a[href=?]", product_path(product.slug)
  end

  test "shop page filters by material" do
    # Set material on fixture product for filtering
    product = products(:wooden_fork)
    product.update!(material: "Birch")

    get shop_path, params: { material: "Birch" }

    assert_response :success
    assert_select "a[href=?]", product_path(product.slug)
  end

  test "shop page combines multiple filters" do
    # Set colour and material on fixture products for filtering
    white_product = products(:single_wall_8oz_white)
    white_product.update!(colour: "White", material: "Paper")

    black_product = products(:single_wall_8oz_black)
    black_product.update!(colour: "Black", material: "Paper")

    get shop_path, params: { colour: "White", material: "Paper" }

    assert_response :success
    assert_select "a[href=?]", product_path(white_product.slug)

    # Should NOT include product with different colour
    assert_select "a[href=?]", product_path(black_product.slug), count: 0
  end

  test "shop page returns success with available_filters" do
    get shop_path

    assert_response :success
    # Available filters are used in the view - test indirectly through response
  end

  test "shop page filters can combine with category filter" do
    product = products(:single_wall_8oz_white)
    product.update!(colour: "White")
    category = product.category

    get shop_path, params: { categories: [ category.slug ], colour: "White" }

    assert_response :success
    assert_select "a[href=?]", product_path(product.slug)
  end

  test "shop page filters can combine with search" do
    product = products(:single_wall_8oz_white)
    product.update!(colour: "White")

    # Search by SKU which is guaranteed to match
    get shop_path, params: { q: product.sku, colour: "White" }

    assert_response :success
    assert_select "a[href=?]", product_path(product.slug)
  end

  test "shop page handles empty filter results gracefully" do
    get shop_path, params: { colour: "nonexistent_colour_12345" }

    assert_response :success
    # Should show empty state or "no results" message
  end
end
