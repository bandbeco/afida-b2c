require "test_helper"

class Admin::ProductsControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Set a modern browser user agent to pass allow_browser check
    @headers = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }
    @product = products(:one)
    @admin = users(:acme_admin)
    sign_in_as(@admin)
  end

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }, headers: @headers
  end

  test "should destroy product_photo attachment" do
    # Attach a product photo
    file = fixture_file_upload("test_image.png", "image/png")
    @product.product_photo.attach(file)
    assert @product.product_photo.attached?, "Product photo should be attached before test"

    # Delete the product photo
    delete product_photo_admin_product_path(@product), headers: @headers

    @product.reload
    assert_not @product.product_photo.attached?, "Product photo should be purged after deletion"
  end

  test "should destroy lifestyle_photo attachment" do
    # Attach a lifestyle photo
    file = fixture_file_upload("test_image.png", "image/png")
    @product.lifestyle_photo.attach(file)
    assert @product.lifestyle_photo.attached?, "Lifestyle photo should be attached before test"

    # Delete the lifestyle photo
    delete lifestyle_photo_admin_product_path(@product), headers: @headers

    @product.reload
    assert_not @product.lifestyle_photo.attached?, "Lifestyle photo should be purged after deletion"
  end

  test "update permits description_short, description_standard, description_detailed parameters" do
    patch admin_product_path(@product), params: {
      product: {
        name: @product.name,
        description_short: "Updated short description",
        description_standard: "Updated standard description text",
        description_detailed: "Updated detailed description with full information"
      }
    }, headers: @headers

    assert_response :redirect
    @product.reload
    assert_equal "Updated short description", @product.description_short
    assert_equal "Updated standard description text", @product.description_standard
    assert_equal "Updated detailed description with full information", @product.description_detailed
  end

  test "edit form includes sample eligibility field" do
    get edit_admin_product_path(@product), headers: @headers

    assert_response :success
    assert_select "input[type=checkbox][name='product[sample_eligible]']"
  end

  test "should update sample eligibility" do
    assert_not @product.sample_eligible, "Product should not be sample eligible initially"

    patch admin_product_path(@product), params: {
      product: { sample_eligible: true }
    }, headers: @headers

    # Controller redirects to index after successful update
    assert_redirected_to admin_products_path
    @product.reload
    assert @product.sample_eligible, "Product should be sample eligible after update"
    assert_equal "SAMPLE-#{@product.sku}", @product.effective_sample_sku
  end

  # Inline category editing tests

  test "inline_edit_category returns success and renders select" do
    get inline_edit_category_admin_product_path(@product), headers: @headers

    assert_response :success
    assert_select "select[name='product[category_id]']"
  end

  test "update_category updates product category" do
    new_category = categories(:child_hot_cups)

    patch update_category_admin_product_path(@product), params: {
      product: { category_id: new_category.id }
    }, headers: @headers

    assert_response :success
    @product.reload
    assert_equal new_category.id, @product.category_id
  end

  test "update_category with invalid category returns unprocessable entity" do
    # Top-level categories are invalid (must be subcategory)
    top_level = categories(:parent_cups_and_drinks)

    patch update_category_admin_product_path(@product), params: {
      product: { category_id: top_level.id }
    }, headers: @headers

    assert_response :unprocessable_entity
  end

  # Inline boolean toggle tests

  test "toggle_boolean enables active on product" do
    @product.update!(active: false)

    patch toggle_boolean_admin_product_path(@product), params: {
      field: "active", value: "1"
    }, headers: @headers

    assert_response :success
    @product.reload
    assert @product.active
  end

  test "toggle_boolean disables featured on product" do
    @product.update!(featured: true)

    patch toggle_boolean_admin_product_path(@product), params: {
      field: "featured", value: "0"
    }, headers: @headers

    assert_response :success
    @product.reload
    assert_not @product.featured
  end

  test "toggle_boolean enables sample_eligible on product" do
    assert_not @product.sample_eligible

    patch toggle_boolean_admin_product_path(@product), params: {
      field: "sample_eligible", value: "1"
    }, headers: @headers

    assert_response :success
    @product.reload
    assert @product.sample_eligible
  end

  test "toggle_boolean rejects non-allowed fields" do
    patch toggle_boolean_admin_product_path(@product), params: {
      field: "name", value: "hacked"
    }, headers: @headers

    assert_response :unprocessable_entity
  end
end
