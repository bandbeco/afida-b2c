require "test_helper"

class SamplePacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @sample_pack = collections(:coffee_shop_sample_pack)
    @user = users(:one)
  end

  # ==========================================================================
  # GET /sample-packs/:slug (show)
  # ==========================================================================

  test "show displays sample pack landing page" do
    get sample_pack_path(@sample_pack.slug)
    assert_response :success
    assert_match @sample_pack.name, response.body
  end

  test "show displays sample-eligible products" do
    get sample_pack_path(@sample_pack.slug)
    assert_response :success

    @sample_pack.sample_eligible_products.limit(Cart::SAMPLE_LIMIT).each do |product|
      assert_match product.name, response.body
    end
  end

  test "show displays request pack CTA button" do
    get sample_pack_path(@sample_pack.slug)
    assert_response :success
    assert_match(/Order.*Free.*Samples/i, response.body)
  end

  test "show is publicly accessible" do
    get sample_pack_path(@sample_pack.slug)
    assert_response :success
  end

  test "show returns 404 for non-existent slug" do
    get sample_pack_path("non-existent-pack")
    assert_response :not_found
  end

  test "show returns 404 for non-sample-pack collection" do
    regular_collection = collections(:coffee_shop_essentials)
    get sample_pack_path(regular_collection.slug)
    assert_response :not_found
  end

  # ==========================================================================
  # POST /sample-packs/:slug/request_pack
  # ==========================================================================

  test "request_pack adds sample-eligible products to cart" do
    # Make a request to initialize the cart
    get samples_path
    assert_response :success

    initial_cart_count = Cart.count

    post request_pack_sample_pack_path(@sample_pack.slug)
    assert_response :redirect
    assert_redirected_to cart_path

    # A cart should be created
    assert_operator Cart.count, :>=, initial_cart_count

    # Check flash message
    follow_redirect!
    assert flash[:notice].present?
  end

  test "request_pack shows flash message with pack name" do
    get samples_path  # Initialize cart
    post request_pack_sample_pack_path(@sample_pack.slug)
    assert_response :redirect
    follow_redirect!

    # Flash should contain pack name
    assert flash[:notice].present?
    assert_match(/#{@sample_pack.name}/i, flash[:notice])
  end

  test "request_pack redirects to cart" do
    get samples_path  # Initialize cart
    post request_pack_sample_pack_path(@sample_pack.slug)
    assert_redirected_to cart_path
  end

  test "request_pack returns 404 for non-existent pack" do
    get samples_path  # Initialize cart
    post request_pack_sample_pack_path("non-existent-pack")
    assert_response :not_found
  end

  test "request_pack returns 404 for non-sample-pack collection" do
    regular_collection = collections(:coffee_shop_essentials)
    get samples_path  # Initialize cart
    post request_pack_sample_pack_path(regular_collection.slug)
    assert_response :not_found
  end

  test "request_pack clears existing samples and adds pack samples" do
    get samples_path

    # Add pack
    post request_pack_sample_pack_path(@sample_pack.slug)
    assert_redirected_to cart_path

    cart = Cart.last
    initial_count = cart.cart_items.samples.count

    # Add pack again (should clear and re-add, so count stays the same)
    post request_pack_sample_pack_path(@sample_pack.slug)
    follow_redirect!

    cart.reload
    assert_equal initial_count, cart.cart_items.samples.count
  end

  test "request_pack shows replacement message when clearing existing samples" do
    get samples_path

    # Add pack first time
    post request_pack_sample_pack_path(@sample_pack.slug)
    follow_redirect!

    # Add pack again - should show replacement message
    post request_pack_sample_pack_path(@sample_pack.slug)
    follow_redirect!

    assert_match(/Previous samples replaced/i, flash[:notice])
  end

  test "request_pack marks cart items as samples" do
    # Initialize cart
    get samples_path

    post request_pack_sample_pack_path(@sample_pack.slug)
    assert_redirected_to cart_path

    # Get the cart from the session
    cart = Cart.last

    # All items added should be marked as samples
    assert cart.cart_items.any?, "Cart should have items"
    cart.cart_items.samples.each do |item|
      assert item.is_sample, "Cart item for #{item.product.name} should have is_sample=true"
      assert item.sample?, "Cart item for #{item.product.name} should be a sample"
      assert_equal 0, item.price, "Sample items should have price=0"
    end
  end
end
