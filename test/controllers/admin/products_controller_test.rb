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

  test "should get variants as JSON" do
    get variants_admin_product_path(@product, format: :json), headers: @headers
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal @product.id, json["product"]["id"]
    assert_equal @product.name, json["product"]["name"]
    assert_equal @product.slug, json["product"]["slug"]
    assert json["variants"].is_a?(Array)
    assert json["variants"].length > 0

    # Check variant structure
    first_variant = json["variants"].first
    assert first_variant["id"]
    assert first_variant["name"]
    assert first_variant["display_name"]
  end

  test "variants endpoint requires authentication" do
    # Sign out
    delete session_url, headers: @headers

    get variants_admin_product_path(@product, format: :json), headers: @headers
    assert_response :redirect
    assert_redirected_to new_session_path
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

    assert_redirected_to admin_product_path(@product)
    @product.reload
    assert @product.sample_eligible, "Product should be sample eligible after update"
    assert_equal "SAMPLE-#{@product.sku}", @product.effective_sample_sku
  end
end
