require "test_helper"

class ProductVariantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @variant = product_variants(:single_wall_8oz_white)
    @inactive_variant = product_variants(:two)
    @inactive_variant.update_column(:active, false)
  end

  test "show displays variant page" do
    get product_variant_path(@variant.slug)
    assert_response :success
  end

  test "show assigns variant" do
    get product_variant_path(@variant.slug)
    assert_response :success
    assert_select "title", text: /#{Regexp.escape(@variant.name)}/i
  end

  test "show returns 404 for invalid slug" do
    get "/products/nonexistent-slug-that-does-not-exist"
    assert_response :not_found
  end

  test "show returns 404 for inactive variant" do
    get "/products/#{@inactive_variant.slug}"
    assert_response :not_found
  end

  test "show loads product and category for breadcrumbs" do
    get product_variant_path(@variant.slug)
    assert_response :success
    # Breadcrumbs should contain product category and product name
    assert_select "nav[aria-label='Breadcrumb']" do
      assert_select "a", text: @variant.product.category.name
    end
  end

  test "show loads related variants from same product" do
    get product_variant_path(@variant.slug)
    assert_response :success
    # The page should render successfully even with related variants
    # Detailed testing of the "See also" section will be in system tests
  end
end
