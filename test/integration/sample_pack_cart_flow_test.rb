require "test_helper"

class SamplePackCartFlowTest < ActionDispatch::IntegrationTest
  setup do
    @sample_pack = collections(:coffee_shop_sample_pack)
    @sample_product_1 = products(:sample_cup_8oz)
    @sample_product_2 = products(:sample_cup_12oz)
  end

  # ==========================================================================
  # Full user journey: Browse samples → View pack → Add to cart → View cart
  # ==========================================================================

  test "guest user can browse sample packs, request pack, and view cart" do
    # Step 1: Visit samples index
    get samples_path
    assert_response :success
    assert_match @sample_pack.name, response.body

    # Step 2: Click through to sample pack landing page
    get sample_pack_path(@sample_pack.slug)
    assert_response :success
    assert_match @sample_pack.name, response.body

    # Verify sample products are displayed
    assert_match @sample_product_1.name, response.body
    assert_match @sample_product_2.name, response.body

    # Verify "Order Your Free Samples" CTA is present
    assert_match(/Order.*Free.*Samples/i, response.body)

    # Step 3: Request the sample pack
    post request_pack_sample_pack_path(@sample_pack.slug)
    assert_redirected_to cart_path

    # Step 4: Follow redirect to cart and verify items
    follow_redirect!
    assert_response :success

    # Verify flash message shows samples were added
    assert_match(/samples/i, flash[:notice])

    # Verify products appear in cart
    assert_match @sample_product_1.name, response.body
    assert_match @sample_product_2.name, response.body

    # Verify items are marked as samples (price = £0.00)
    assert_match(/£0\.00/, response.body)
  end

  test "authenticated user can request sample pack" do
    user = users(:one)
    sign_in_as(user)

    # Visit sample pack landing page and request it
    get sample_pack_path(@sample_pack.slug)
    assert_response :success

    post request_pack_sample_pack_path(@sample_pack.slug)
    assert_redirected_to cart_path

    follow_redirect!
    assert_response :success
    assert_match(/samples/i, flash[:notice])
  end

  # ==========================================================================
  # Cart state verification
  # ==========================================================================

  test "sample pack items are added with correct attributes" do
    get samples_path  # Initialize session

    post request_pack_sample_pack_path(@sample_pack.slug)
    assert_redirected_to cart_path

    # Get the cart that was created
    cart = Cart.order(created_at: :desc).first
    assert cart.present?, "Cart should be created"

    # Verify cart items
    sample_items = cart.cart_items.where(is_sample: true)
    expected_count = [ @sample_pack.sample_eligible_products.count, Cart::SAMPLE_LIMIT ].min
    assert_equal expected_count, sample_items.count

    sample_items.each do |item|
      assert item.is_sample, "Item should be marked as sample"
      assert_equal 0, item.price, "Sample price should be 0"
      assert_equal 1, item.quantity, "Sample quantity should be 1"
      assert item.product.sample_eligible?, "Product should be sample eligible"
    end
  end

  test "cart correctly identifies samples-only state" do
    get samples_path

    post request_pack_sample_pack_path(@sample_pack.slug)
    follow_redirect!

    cart = Cart.order(created_at: :desc).first
    assert cart.only_samples?, "Cart with only sample pack items should be samples-only"
    assert_equal 0, cart.subtotal_amount, "Samples-only cart should have £0 subtotal"
  end

  # ==========================================================================
  # Fixed pack behavior (clears existing samples)
  # ==========================================================================

  test "requesting pack clears existing samples" do
    get samples_path

    # Add pack first time
    post request_pack_sample_pack_path(@sample_pack.slug)
    assert_redirected_to cart_path

    cart = Cart.order(created_at: :desc).first
    initial_sample_count = cart.cart_items.samples.count

    # Request pack again - should clear and re-add
    post request_pack_sample_pack_path(@sample_pack.slug)
    follow_redirect!

    cart.reload
    # Count should be the same (cleared and re-added)
    assert_equal initial_sample_count, cart.cart_items.samples.count
  end

  test "sample limit is enforced" do
    get samples_path

    post request_pack_sample_pack_path(@sample_pack.slug)
    assert_redirected_to cart_path

    cart = Cart.order(created_at: :desc).first
    assert cart.sample_count <= Cart::SAMPLE_LIMIT, "Sample count should not exceed limit"
  end

  # ==========================================================================
  # Error handling
  # ==========================================================================

  test "returns 404 for non-existent sample pack" do
    get samples_path
    post request_pack_sample_pack_path("non-existent-pack")
    assert_response :not_found
  end

  test "returns 404 when trying to request regular collection as sample pack" do
    regular_collection = collections(:coffee_shop_essentials)
    get samples_path
    post request_pack_sample_pack_path(regular_collection.slug)
    assert_response :not_found
  end

  # ==========================================================================
  # URL routing verification
  # ==========================================================================

  test "sample pack landing page is accessible at /sample-packs/:slug" do
    get "/sample-packs/#{@sample_pack.slug}"
    assert_response :success
    assert_match @sample_pack.name, response.body
  end

  test "sample pack URL differs from collection URL" do
    # Sample packs use /sample-packs/:slug
    get "/sample-packs/#{@sample_pack.slug}"
    assert_response :success

    # Regular collections use /collections/:slug
    regular_collection = collections(:coffee_shop_essentials)
    get "/collections/#{regular_collection.slug}"
    assert_response :success

    # Verify they're different pages
    assert_not_equal @sample_pack.slug, regular_collection.slug
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
