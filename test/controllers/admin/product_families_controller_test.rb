require "test_helper"

class Admin::ProductFamiliesControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Set a modern browser user agent to pass allow_browser check
    @headers = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }
    @product_family = product_families(:single_wall_cups)
    @admin = users(:acme_admin)
    sign_in_as(@admin)
  end

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }, headers: @headers
  end

  test "should get index" do
    get admin_product_families_path, headers: @headers
    assert_response :success
    assert_match /Product Families/, response.body
    assert_match @product_family.name, response.body
  end

  test "index shows product counts" do
    get admin_product_families_path, headers: @headers
    assert_response :success
    assert_match @product_family.slug, response.body
  end

  test "should get new" do
    get new_admin_product_family_path, headers: @headers
    assert_response :success
    assert_match /New Product Family/, response.body
  end

  test "should create product family" do
    assert_difference("ProductFamily.count") do
      post admin_product_families_path, headers: @headers, params: {
        product_family: { name: "Espresso Cups", slug: "espresso-cups" }
      }
    end

    assert_redirected_to admin_product_families_path
    follow_redirect!
    assert_match /Product family was successfully created/, response.body

    family = ProductFamily.find_by(slug: "espresso-cups")
    assert_not_nil family
    assert_equal "Espresso Cups", family.name
  end

  test "should auto-generate slug when left blank on create" do
    post admin_product_families_path, headers: @headers, params: {
      product_family: { name: "Espresso Cups", slug: "" }
    }

    assert_redirected_to admin_product_families_path
    family = ProductFamily.find_by(name: "Espresso Cups")
    assert_equal "espresso-cups", family.slug
  end

  test "should get edit" do
    get edit_admin_product_family_path(@product_family), headers: @headers
    assert_response :success
    assert_match /Edit Product Family/, response.body
    assert_match @product_family.name, response.body
  end

  test "should update product family" do
    patch admin_product_family_path(@product_family), headers: @headers, params: {
      product_family: { name: "Updated Name" }
    }

    assert_redirected_to admin_product_families_path
    follow_redirect!
    assert_match /Product family was successfully updated/, response.body

    @product_family.reload
    assert_equal "Updated Name", @product_family.name
  end

  test "should update slug" do
    patch admin_product_family_path(@product_family), headers: @headers, params: {
      product_family: { slug: "new-slug" }
    }

    assert_redirected_to admin_product_families_path
    @product_family.reload
    assert_equal "new-slug", @product_family.slug
  end

  test "should regenerate slug when blanked on update" do
    patch admin_product_family_path(@product_family), headers: @headers, params: {
      product_family: { slug: "" }
    }

    assert_redirected_to admin_product_families_path
    @product_family.reload
    assert_equal "single-wall-cups", @product_family.slug
  end

  test "should not create product family with blank name" do
    assert_no_difference("ProductFamily.count") do
      post admin_product_families_path, headers: @headers, params: {
        product_family: { name: "", slug: "" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not update product family with blank name" do
    original_name = @product_family.name

    patch admin_product_family_path(@product_family), headers: @headers, params: {
      product_family: { name: "" }
    }

    assert_response :unprocessable_entity
    @product_family.reload
    assert_equal original_name, @product_family.name
  end

  test "should not update product family with malformed slug" do
    patch admin_product_family_path(@product_family), headers: @headers, params: {
      product_family: { slug: "Not A Slug!" }
    }

    assert_response :unprocessable_entity
  end

  test "should destroy product family and detach its products" do
    product = products(:single_wall_8oz_white)
    assert_equal @product_family.id, product.product_family_id

    assert_difference("ProductFamily.count", -1) do
      delete admin_product_family_path(@product_family), headers: @headers
    end

    assert_redirected_to admin_product_families_path
    follow_redirect!
    assert_match /Product family was successfully deleted/, response.body

    product.reload
    assert_nil product.product_family_id
  end

  test "should use slug in URLs" do
    get edit_admin_product_family_path(@product_family.slug), headers: @headers
    assert_response :success
  end

  test "requires authentication" do
    delete session_url, headers: @headers

    get admin_product_families_path, headers: @headers
    assert_redirected_to new_session_path
  end

  test "requires admin role" do
    sign_in_as(users(:acme_member))

    get admin_product_families_path, headers: @headers
    assert_redirected_to root_path
  end
end
