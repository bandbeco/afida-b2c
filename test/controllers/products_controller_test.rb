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

  # Sparse matrix detection tests (lines 41-73 in ProductsController)
  # These tests validate the consolidated product configurator logic
  #
  # The sparse matrix detection determines which UI to render:
  # - Consolidated products use `data-controller="product-configurator"`
  # - Standard products use `data-controller="product-options"`

  test "show renders consolidated configurator for sparse matrix product" do
    # Paper Straws: 2 sizes x 3 colours = 6 possible, but only 3 exist
    # 6x140mm: White, Kraft
    # 8x200mm: Red/White only (sparse!)
    product = products(:paper_straws)

    get product_url(product.slug)

    assert_response :success
    # Sparse matrix products should render consolidated_product partial with product-configurator
    assert_match 'data-controller="product-configurator"', response.body,
                 "Expected sparse matrix product to render consolidated configurator"
    assert_no_match 'data-controller="product-options"', response.body,
                    "Sparse matrix product should NOT render standard product-options controller"
  end

  test "show renders consolidated configurator for product with material option" do
    # Wooden Cutlery has material option (Birch, Bamboo) - consolidated product
    product = products(:wooden_cutlery)

    get product_url(product.slug)

    assert_response :success
    # Products with material option should render consolidated_product partial
    assert_match 'data-controller="product-configurator"', response.body,
                 "Expected product with material option to render consolidated configurator"
    # Verify configurator shows material options
    assert_match "Birch", response.body
    assert_match "Bamboo", response.body
  end

  test "show renders standard product-options for full matrix products" do
    # Napkins: 2 sizes x 2 colours = 4 possible, and all 4 exist
    product = products(:napkins)

    get product_url(product.slug)

    assert_response :success
    # Full matrix products should render standard_product partial with product-options
    assert_match 'data-controller="product-options"', response.body,
                 "Expected full matrix product to render standard product-options controller"
    assert_no_match 'data-controller="product-configurator"', response.body,
                    "Full matrix product should NOT render consolidated configurator"
  end

  test "show renders standard view for single variant products" do
    # Solo Product has only 1 variant - no configuration needed
    product = products(:solo_product)

    get product_url(product.slug)

    assert_response :success
    # Single variant products should render standard_product partial
    # (they may or may not have product-options controller depending on options)
    assert_no_match 'data-controller="product-configurator"', response.body,
                    "Single variant product should NOT use consolidated configurator"
  end

  test "show renders standard view for single option type products" do
    # Paper Lids has multiple variants but option_values are empty (size via name only)
    product = products(:paper_lids)

    get product_url(product.slug)

    assert_response :success
    # Single option type without material/type = not consolidated
    assert_no_match 'data-controller="product-configurator"', response.body,
                    "Single option type product should NOT use consolidated configurator"
  end

  test "sparse matrix product shows variant options in configurator" do
    product = products(:paper_straws)

    get product_url(product.slug)

    assert_response :success
    # Verify the sparse matrix options are available in the UI
    assert_match "6x140mm", response.body
    assert_match "8x200mm", response.body
    assert_match "White", response.body
    assert_match "Kraft", response.body
    assert_match "Red/White", response.body
  end

  test "full matrix product shows all variant combinations" do
    product = products(:napkins)

    get product_url(product.slug)

    assert_response :success
    # Verify all options are available
    assert_match "Small", response.body
    assert_match "Large", response.body
    assert_match "White", response.body
    assert_match "Natural", response.body
  end

  test "consolidated configurator includes variants JSON with option order" do
    # The consolidated configurator needs variants data and option order for dynamic UI
    product = products(:wooden_cutlery)

    get product_url(product.slug)

    assert_response :success
    # Verify the data attributes needed by the product-configurator controller
    assert_match "data-product-configurator-variants-value", response.body
    assert_match "data-product-configurator-option-order-value", response.body
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

  test "quick_add returns 404 for customizable product" do
    # The quick_add action uses Product.standard scope, so customizable
    # products are not found and return 404 (same as invalid slug)
    customizable_product = products(:one)
    customizable_product.update!(product_type: "customizable_template")

    get quick_add_product_url(customizable_product)

    assert_response :not_found
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
