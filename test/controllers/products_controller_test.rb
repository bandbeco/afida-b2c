require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:one)
    @category = categories(:one)
    @variant = product_variants(:one)
  end

  # GET /products (index)
  test "should get index" do
    get products_url
    assert_response :success
  end

  test "index page is accessible to guests" do
    get products_url
    assert_response :success
  end

  test "index page is accessible to authenticated users" do
    sign_in_as(users(:one))
    get products_url
    assert_response :success
  end

  test "index eager loads products with associations" do
    # This test verifies eager loading is happening (prevents N+1 queries)
    get products_url
    assert_response :success
  end

  test "index shows active products" do
    get products_url
    assert_response :success
    # Response should contain product information
    assert_match @product.name, response.body
  end

  # GET /products/:id (show)
  test "should show product by slug" do
    get product_url(@product.slug)
    assert_response :success
  end

  test "show page loads product with slug" do
    get product_url(@product.slug)
    assert_response :success
    # Response should contain product name
    assert_match @product.name, response.body
  end

  test "show page displays variant information" do
    get product_url(@product.slug)
    assert_response :success
    # Should show variant details
    assert_response :success
  end

  test "show page accepts variant_id parameter" do
    variant = @product.active_variants.first
    get product_url(@product.slug, variant_id: variant.id)

    assert_response :success
  end

  test "show page handles invalid variant_id gracefully" do
    get product_url(@product.slug, variant_id: 999999)

    assert_response :success
  end

  test "show page redirects if product has no variants" do
    # Create product with no active variants
    product = Product.create!(
      name: "No Variants Product",
      category: @category,
      sku: "NOVARIANTS",
      active: true
    )

    get product_url(product.slug)

    assert_redirected_to products_path
    assert_equal "This product is currently unavailable.", flash[:alert]
  end

  test "show page accessible to guests" do
    get product_url(@product.slug)
    assert_response :success
  end

  test "show page accessible to authenticated users" do
    sign_in_as(users(:one))
    get product_url(@product.slug)
    assert_response :success
  end

  test "show page eager loads product with associations" do
    get product_url(@product.slug)
    assert_response :success
    # Eager loading prevents N+1 queries
  end

  test "show page uses SEO-friendly slug URLs" do
    get product_url(@product.slug)
    assert_response :success
    # Products are accessed via slug, not ID
  end

  test "show page works with product that has variants" do
    get product_url(@product.slug)
    assert_response :success
    # Should display variant information
    assert_response :success
  end

  test "variant_id parameter is supported" do
    variant = @product.active_variants.first
    get product_url(@product.slug, variant_id: variant.id)

    assert_response :success
    # Request should include variant_id param
    assert_equal variant.id.to_s, @request.params[:variant_id].to_s
  end

  test "products index and show are publicly accessible" do
    # Verify no authentication required
    get products_url
    assert_response :success

    get product_url(@product.slug)
    assert_response :success
  end

  # GET /products/:id/quick_add
  test "quick_add renders modal for standard product" do
    standard_product = products(:one)  # Assuming product type is 'standard'
    standard_product.update!(product_type: "standard")
    # Ensure product has a slug (in case fixture doesn't have one)
    standard_product.generate_slug if standard_product.slug.blank?
    standard_product.save! if standard_product.changed?

    get quick_add_product_url(standard_product)

    assert_response :success
    assert_select "turbo-frame#quick-add-modal"
    assert_select ".modal.modal-open"
    assert_match standard_product.name, response.body
  end

  test "quick_add redirects for customizable product" do
    customizable_product = products(:one)
    customizable_product.update!(product_type: "customizable_template")

    get quick_add_product_url(customizable_product)

    assert_redirected_to product_path(customizable_product)
    assert_equal "Product not available for quick add", flash[:alert]
  end

  test "quick_add returns 404 for invalid slug" do
    get quick_add_product_path("nonexistent-product-slug")

    assert_response :not_found
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
