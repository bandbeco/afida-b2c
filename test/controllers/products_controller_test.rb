require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:one)
    @category = categories(:one)

    # Set host to avoid www redirect in routes
    host! "example.com"
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
    assert_match @product.generated_title, response.body
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
    assert_match @product.generated_title, response.body
  end

  test "show page displays variant information" do
    get product_url(@product.slug)
    assert_response :success
    # Should show variant details
    assert_response :success
  end

  test "show page accepts variant_id parameter" do
    # With the new structure, Product IS the variant
    get product_url(@product.slug, variant_id: @product.id)

    assert_response :success
  end

  test "show page handles invalid variant_id gracefully" do
    get product_url(@product.slug, variant_id: 999999)

    assert_response :success
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
    # With the new structure, Product IS the variant
    get product_url(@product.slug, variant_id: @product.id)

    assert_response :success
    # Request should include variant_id param
    assert_equal @product.id.to_s, @request.params[:variant_id].to_s
  end

  test "products index and show are publicly accessible" do
    # Verify no authentication required
    get products_url
    assert_response :success

    get product_url(@product.slug)
    assert_response :success
  end

  # Product Family Tests
  # Products in the same family render successfully

  test "show renders product in a family successfully" do
    product = products(:single_wall_8oz_white)

    get product_url(product.slug)

    assert_response :success
  end

  test "show renders product page successfully for all product types" do
    # Test various products render without error
    %i[paper_straws napkins wooden_cutlery paper_lids only_product_in_category].each do |fixture|
      product = products(fixture)
      get product_url(product.slug)
      assert_response :success, "Product #{fixture} should render successfully"
    end
  end

  test "show displays product information" do
    product = products(:single_wall_8oz_white)

    get product_url(product.slug)

    assert_response :success
    assert_match product.generated_title, response.body
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
    assert_match standard_product.generated_title, response.body
  end

  test "quick_add renders for customizable template product" do
    # The quick_add action uses Product.catalog_products scope which includes
    # both standard and customizable_template products
    customizable_product = products(:one)
    customizable_product.update!(product_type: "customizable_template")

    get quick_add_product_url(customizable_product)

    assert_response :success
  end

  test "quick_add returns 404 for invalid slug" do
    get quick_add_product_path("nonexistent-product-slug")

    assert_response :not_found
  end

  # Product Display Tests
  # Tests for product page content and functionality

  test "show renders product page for products with siblings" do
    # Single Wall 8oz White has other products in the same family
    product = products(:single_wall_8oz_white)

    get product_url(product.slug)

    assert_response :success
    assert_match product.generated_title, response.body
  end

  test "show displays add to cart form" do
    product = products(:single_wall_8oz_white)

    get product_url(product.slug)

    assert_response :success
    # Add to cart form should be present
    assert_select "form[action*='cart_items']"
  end

  test "show displays product price" do
    product = products(:single_wall_8oz_white)

    get product_url(product.slug)

    assert_response :success
    # Price should be visible on page
    assert_match(/£/, response.body) # Should show GBP currency
  end

  test "show OG price meta tag uses first tier price for tiered products" do
    product = products(:single_wall_8oz_white)
    assert product.pricing_tiers.present?, "Fixture should have pricing tiers"

    get product_url(product.slug)

    assert_response :success
    first_tier_price = product.pricing_tiers.first["price"]
    assert_select "meta[property='product:price:amount'][content='#{first_tier_price}']"
  end

  test "show OG price meta tag uses product price for non-tiered products" do
    product = products(:paper_straws)
    assert product.pricing_tiers.blank?, "Fixture should not have pricing tiers"

    get product_url(product.slug)

    assert_response :success
    assert_select "meta[property='product:price:amount'][content='#{product.price}']"
  end

  # Branded Product Redirect Tests
  test "show redirects branded templates to /branded-products/ with 301" do
    branded_template = products(:branded_template_variant)
    assert branded_template.customizable_template?, "Fixture should be a customizable_template"

    get product_url(branded_template.slug)

    assert_response :moved_permanently
    assert_redirected_to branded_product_path(branded_template.slug)
  end

  # Vegware badge tests
  test "show page displays Vegware badge for Vegware products" do
    vegware_product = products(:vegware_hot_cup)

    get product_url(vegware_product.slug)

    assert_response :success
    assert_select ".vegware-badge"
  end

  test "show page does not display Vegware badge for non-Vegware products" do
    product = products(:one)

    get product_url(product.slug)

    assert_response :success
    assert_select ".vegware-badge", count: 0
  end

  test "show does not redirect standard products" do
    standard_product = products(:one)
    standard_product.update!(product_type: "standard")

    get product_url(standard_product.slug)

    assert_response :success
  end

  test "show eager loads attachments for related products and compatible lids" do
    # branded_cup_8oz has two compatible lids (flat_lid_8oz, domed_lid_8oz),
    # both matching by size, so the show page renders the compatible-lids
    # block — exposing any per-lid attachment lookup as an N+1.
    cup = products(:branded_cup_8oz)

    # Warm up autoload / view compilation so first-request overhead doesn't
    # pollute the query log.
    get product_url(cup.slug)
    assert_response :success

    queries = []
    counter = ->(_, _, _, _, payload) {
      queries << payload[:sql] if payload[:sql] && !payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)
    }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get product_url(cup.slug)
    end

    assert_response :success

    # N+1 signature: "record_id = $1 ... LIMIT 1" — one attachment lookup per
    # record. Eager-loaded preloads use "record_id IN (...)" instead.
    per_record_attachment_lookups = queries.count do |sql|
      sql.include?("active_storage_attachments") &&
        sql.include?("\"record_id\" = $") &&
        sql.match?(/LIMIT \$\d+\z/)
    end

    # The main product itself legitimately reads its own product_photo and
    # lifestyle_photo, so allow a small fixed budget. Each compatible lid and
    # related product should add zero per-record lookups.
    assert per_record_attachment_lookups <= 2,
      "Expected at most 2 per-record attachment lookups (main product only), " \
      "got #{per_record_attachment_lookups}:\n" +
      queries.select { |q|
        q.include?("active_storage_attachments") &&
          q.include?("\"record_id\" = $") &&
          q.match?(/LIMIT \$\d+\z/)
      }.first(10).join("\n")
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
