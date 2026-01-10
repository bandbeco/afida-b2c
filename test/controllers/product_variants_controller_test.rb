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

  # See Also section tests
  test "show displays See Also section when sibling variants exist" do
    variant = product_variants(:single_wall_8oz_white)
    sibling = product_variants(:single_wall_8oz_black)

    get product_variant_path(variant.slug)
    assert_response :success

    # See Also heading should be present
    assert_select "h2", text: "See Also"
    # Sibling variant should be linked
    assert_select "a[href=?]", product_variant_path(sibling.slug)
  end

  test "show hides See Also section for single-variant products" do
    # Create a product with only one active variant
    product = Product.create!(
      name: "Single Variant Product",
      category: categories(:one),
      active: true
    )
    only_variant = ProductVariant.create!(
      product: product,
      name: "Only Variant",
      sku: "SINGLE-ONLY-TEST",
      price: 10.0,
      active: true
    )

    get product_variant_path(only_variant.slug)
    assert_response :success

    # See Also section should not be present
    assert_select "h2", text: "See Also", count: 0
  end

  test "show excludes inactive variants from See Also section" do
    variant = product_variants(:single_wall_8oz_white)
    inactive_sibling = product_variants(:single_wall_8oz_black)
    inactive_sibling.update!(active: false)

    get product_variant_path(variant.slug)
    assert_response :success

    # Inactive variant should not be linked
    assert_select "a[href=?]", product_variant_path(inactive_sibling.slug), count: 0
  end
end
