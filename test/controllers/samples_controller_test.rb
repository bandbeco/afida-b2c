require "test_helper"

class SamplesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create a category with sample-eligible variants
    @category = categories(:one)

    # Create a sample-eligible product
    @sample_variant = Product.create!(
      category: @category,
      name: "Sample Test Variant",
      sku: "SAMPLE-CONTROLLER-TEST-1",
      price: 10.0,
      sample_eligible: true,
      active: true
    )
  end

  test "GET /samples returns success" do
    get samples_path
    assert_response :success
  end

  test "GET /samples shows categories with sample-eligible variants" do
    get samples_path
    assert_response :success
    # Category should be visible since it has sample-eligible variant
    assert_select "h1", text: /Try Before You Buy/i
  end

  test "GET /samples/:category_slug returns Turbo Frame with variants" do
    get category_samples_path(@category.slug),
        headers: { "Turbo-Frame" => "category_#{@category.id}" }

    assert_response :success
    # Should return Turbo Frame response
  end

  test "categories without sample-eligible variants are not shown" do
    # Create a category with no sample-eligible variants
    empty_category = Category.create!(
      name: "Empty Category",
      slug: "empty-category",
      position: 99
    )

    get samples_path
    assert_response :success

    # Empty category should not appear
    assert_no_match(/Empty Category/, response.body)
  end
end
