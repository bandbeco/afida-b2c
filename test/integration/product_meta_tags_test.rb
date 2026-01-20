require "test_helper"

class ProductMetaTagsTest < ActionDispatch::IntegrationTest
  test "uses custom meta_title when present" do
    product = products(:single_wall_cups)
    product.update(meta_title: "Custom SEO Title")

    get product_path(product)
    assert_select "title", "Custom SEO Title"
  end

  test "falls back to generated title when meta_title is blank" do
    product = products(:single_wall_cups)
    product.update(meta_title: nil)

    get product_path(product)
    assert_select "title", "#{product.generated_title} | #{product.category.name} | Afida"
  end

  test "uses custom meta_description when present" do
    product = products(:single_wall_cups)
    product.update(meta_description: "Custom SEO description")

    get product_path(product)

    # Check in the response body instead of using assert_select
    assert_includes response.body, 'name="description"'
    assert_includes response.body, "Custom SEO description"
  end

  test "falls back to product description when meta_description is blank" do
    product = products(:single_wall_cups)
    product.update(meta_description: nil, description_standard: "Fallback description text")

    get product_path(product)

    # Check in the response body
    assert_includes response.body, 'name="description"'
    assert_includes response.body, "Fallback description text"
  end
end
