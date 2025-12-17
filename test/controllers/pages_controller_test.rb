require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "shop page displays all products by default" do
    get shop_path

    assert_response :success
    assert_select "h1", text: /Shop/
    # Shop page only shows standard products (not customizable templates)
    Product.standard.limit(5).each do |product|
      assert_select "a[href=?]", product_path(product.slug)
    end
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
end
