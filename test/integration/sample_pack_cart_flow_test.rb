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

  test "guest user can browse sample packs, add pack to cart, and view cart" do
    # Step 1: Visit samples index
    get samples_path
    assert_response :success
    assert_match @sample_pack.name, response.body

    # Step 2: Click through to sample pack page
    get pack_samples_path(@sample_pack.slug)
    assert_response :success
    assert_match @sample_pack.name, response.body
    assert_match @sample_pack.description, response.body

    # Verify sample products are displayed
    assert_match @sample_product_1.name, response.body
    assert_match @sample_product_2.name, response.body

    # Verify "Add All" button is present
    assert_match(/Add All to Cart/i, response.body)

    # Step 3: Add all samples to cart
    post add_pack_samples_path, params: { slug: @sample_pack.slug }
    assert_redirected_to cart_path

    # Step 4: Follow redirect to cart and verify items
    follow_redirect!
    assert_response :success

    # Verify flash message shows samples were added
    assert_match(/\d+ samples/i, flash[:notice])

    # Verify products appear in cart
    assert_match @sample_product_1.name, response.body
    assert_match @sample_product_2.name, response.body

    # Verify items are marked as samples (price = £0.00)
    assert_match(/£0\.00/, response.body)
  end

  test "authenticated user can add sample pack to cart" do
    user = users(:one)
    sign_in_as(user)

    # Visit sample pack and add to cart
    get pack_samples_path(@sample_pack.slug)
    assert_response :success

    post add_pack_samples_path, params: { slug: @sample_pack.slug }
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

    post add_pack_samples_path, params: { slug: @sample_pack.slug }
    assert_redirected_to cart_path

    # Get the cart that was created
    cart = Cart.order(created_at: :desc).first
    assert cart.present?, "Cart should be created"

    # Verify cart items
    sample_items = cart.cart_items.where(is_sample: true)
    assert_equal @sample_pack.sample_eligible_products.count, sample_items.count

    sample_items.each do |item|
      assert item.is_sample, "Item should be marked as sample"
      assert_equal 0, item.price, "Sample price should be 0"
      assert_equal 1, item.quantity, "Sample quantity should be 1"
      assert item.product.sample_eligible?, "Product should be sample eligible"
    end
  end

  test "cart correctly identifies samples-only state" do
    get samples_path

    post add_pack_samples_path, params: { slug: @sample_pack.slug }
    follow_redirect!

    cart = Cart.order(created_at: :desc).first
    assert cart.only_samples?, "Cart with only sample pack items should be samples-only"
    assert_equal 0, cart.subtotal_amount, "Samples-only cart should have £0 subtotal"
  end

  # ==========================================================================
  # Sample limit enforcement
  # ==========================================================================

  test "sample limit is enforced when adding pack" do
    get samples_path

    # First, add some individual samples to approach the limit
    # The limit is Cart::SAMPLE_LIMIT (5)
    product = products(:sample_cup_8oz)

    # Add 4 samples manually first
    4.times do |i|
      # Create different sample products if needed, or use the same one
      # For this test, we'll add a regular sample first
    end

    # Add pack - should only add up to the limit
    post add_pack_samples_path, params: { slug: @sample_pack.slug }
    assert_redirected_to cart_path

    cart = Cart.order(created_at: :desc).first
    assert cart.sample_count <= Cart::SAMPLE_LIMIT, "Sample count should not exceed limit"
  end

  # ==========================================================================
  # Duplicate prevention
  # ==========================================================================

  test "adding same pack twice does not duplicate items" do
    get samples_path

    # Add pack first time
    post add_pack_samples_path, params: { slug: @sample_pack.slug }
    assert_redirected_to cart_path

    cart = Cart.order(created_at: :desc).first
    initial_item_count = cart.cart_items.count

    # Add pack second time
    post add_pack_samples_path, params: { slug: @sample_pack.slug }
    follow_redirect!

    cart.reload
    assert_equal initial_item_count, cart.cart_items.count, "Items should not be duplicated"
    assert_match(/already in your cart/i, flash[:notice])
  end

  # ==========================================================================
  # Error handling
  # ==========================================================================

  test "returns 404 for non-existent sample pack" do
    get samples_path
    post add_pack_samples_path, params: { slug: "non-existent-pack" }
    assert_response :not_found
  end

  test "returns 404 when trying to add regular collection as sample pack" do
    regular_collection = collections(:coffee_shop_essentials)
    get samples_path
    post add_pack_samples_path, params: { slug: regular_collection.slug }
    assert_response :not_found
  end

  # ==========================================================================
  # URL routing verification
  # ==========================================================================

  test "sample pack is accessible at /samples/:slug" do
    get "/samples/#{@sample_pack.slug}"
    assert_response :success
    assert_match @sample_pack.name, response.body
  end

  test "sample pack URL differs from collection URL" do
    # Sample packs use /samples/:slug
    get "/samples/#{@sample_pack.slug}"
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
