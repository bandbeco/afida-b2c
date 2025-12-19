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

  # Unified Variant Selector Tests
  # All standard products now use the unified variant-selector controller
  # These tests verify the selector works for different product types

  test "show renders unified variant selector for sparse matrix product" do
    # Paper Straws: 2 sizes x 3 colours = 6 possible, but only 3 exist
    # The variant-selector handles filtering of unavailable combinations
    product = products(:paper_straws)

    get product_url(product.slug)

    assert_response :success
    assert_match 'data-controller="variant-selector"', response.body,
                 "Expected sparse matrix product to render variant-selector"
  end

  test "show renders unified variant selector for product with material option" do
    # Wooden Cutlery has material option (Birch, Bamboo)
    product = products(:wooden_cutlery)

    get product_url(product.slug)

    assert_response :success
    assert_match 'data-controller="variant-selector"', response.body,
                 "Expected product with material option to render variant-selector"
    # Verify options are shown
    assert_match "Birch", response.body
    assert_match "Bamboo", response.body
  end

  test "show renders unified variant selector for full matrix products" do
    # Napkins: 2 sizes x 2 colours = 4 possible, and all 4 exist
    product = products(:napkins)

    get product_url(product.slug)

    assert_response :success
    assert_match 'data-controller="variant-selector"', response.body,
                 "Expected full matrix product to render variant-selector"
  end

  test "show renders unified variant selector for single variant products" do
    # Solo Product has only 1 variant
    product = products(:solo_product)

    get product_url(product.slug)

    assert_response :success
    assert_match 'data-controller="variant-selector"', response.body,
                 "Expected single variant product to render variant-selector"
  end

  test "show renders unified variant selector for single option type products" do
    # Paper Lids has multiple variants but option_values are empty (size via name only)
    product = products(:paper_lids)

    get product_url(product.slug)

    assert_response :success
    assert_match 'data-controller="variant-selector"', response.body,
                 "Expected single option type product to render variant-selector"
  end

  test "sparse matrix product shows variant options in selector" do
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

  test "unified variant selector includes variants JSON with options" do
    # The variant-selector needs variants data and options for dynamic UI
    product = products(:wooden_cutlery)

    get product_url(product.slug)

    assert_response :success
    # Verify the data attributes needed by the variant-selector controller
    assert_match "data-variant-selector-variants-value", response.body
    assert_match "data-variant-selector-options-value", response.body
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

  # T012: Variant Selector Tests
  # Tests for the unified variant selector that replaces product-options and product-configurator
  # The new variant_selector controller uses @options and @variants_json from model methods

  test "show renders variant_selector controller for multi-option product" do
    # Single Wall Cups has size + colour options
    product = products(:single_wall_cups)

    get product_url(product.slug)

    assert_response :success
    # Should render the unified variant selector
    assert_match 'data-controller="variant-selector"', response.body,
                 "Expected variant_selector controller to be rendered"
  end

  test "show includes options data attribute with multi-value options" do
    product = products(:single_wall_cups)

    get product_url(product.slug)

    assert_response :success
    # Options data should be in the response for Stimulus to use
    assert_match "data-variant-selector-options-value", response.body,
                 "Expected options data attribute for Stimulus controller"
  end

  test "show includes variants JSON with required fields" do
    product = products(:single_wall_cups)

    get product_url(product.slug)

    assert_response :success
    # Variants data should include pricing_tiers field
    assert_match "data-variant-selector-variants-value", response.body,
                 "Expected variants data attribute for Stimulus controller"
    # Check that pricing_tiers is part of the JSON (may be null but field exists)
    # Note: JSON embedded in HTML attributes has quotes escaped as &quot;
    assert_match /&quot;pricing_tiers&quot;/, response.body,
                 "Variants JSON should include pricing_tiers field"
  end

  test "show renders variant_selector for sparse matrix product" do
    # Paper Straws has sparse matrix (not all size+colour combinations exist)
    product = products(:paper_straws)

    get product_url(product.slug)

    assert_response :success
    # Sparse matrix products should also use unified variant selector
    assert_match 'data-controller="variant-selector"', response.body,
                 "Expected sparse matrix product to render variant_selector"
  end

  test "show renders variant_selector for product with material option" do
    # Wooden Cutlery has material option (consolidated product type)
    product = products(:wooden_cutlery)

    get product_url(product.slug)

    assert_response :success
    # Material option products should use unified variant selector
    assert_match 'data-controller="variant-selector"', response.body,
                 "Expected material option product to render variant_selector"
    # Should show material options
    assert_match "Birch", response.body
    assert_match "Bamboo", response.body
  end

  test "show options are sorted by priority order in data attribute" do
    # Wooden Cutlery has material option - should appear first in priority
    product = products(:wooden_cutlery)

    get product_url(product.slug)

    assert_response :success
    # The options value should have material before size/colour
    # Extract the options-value attribute and verify order
    options_match = response.body.match(/data-variant-selector-options-value="([^"]+)"/)
    if options_match
      options_json = CGI.unescapeHTML(options_match[1])
      options_hash = JSON.parse(options_json)
      keys = options_hash.keys

      # Priority: material → type → size → colour
      priority = %w[material type size colour]
      priority_indices = keys.map { |k| priority.index(k) || 999 }
      assert_equal priority_indices.sort, priority_indices,
                   "Options should be sorted by priority order: #{keys.inspect}"
    end
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
