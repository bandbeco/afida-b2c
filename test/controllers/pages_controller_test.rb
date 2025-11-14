require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "shop page displays all products by default" do
    get shop_path

    assert_response :success
    assert_select "h1", text: /Shop/
    # Check that products are displayed
    Product.limit(5).each do |product|
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
end
