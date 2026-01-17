require "test_helper"

class SamplesControllerPacksTest < ActionDispatch::IntegrationTest
  setup do
    @sample_pack = collections(:coffee_shop_sample_pack)
    @user = users(:one)
  end

  # ==========================================================================
  # GET /samples/pack/:slug (pack)
  # ==========================================================================

  test "pack shows sample pack collection" do
    get pack_samples_path(@sample_pack.slug)
    assert_response :success
    assert_match @sample_pack.name, response.body
  end

  test "pack shows sample-eligible products" do
    get pack_samples_path(@sample_pack.slug)
    assert_response :success

    @sample_pack.sample_eligible_products.each do |product|
      assert_match product.name, response.body
    end
  end

  test "pack shows add all to cart button" do
    get pack_samples_path(@sample_pack.slug)
    assert_response :success
    assert_match(/add all/i, response.body)
  end

  test "pack is publicly accessible" do
    get pack_samples_path(@sample_pack.slug)
    assert_response :success
  end

  test "pack returns 404 for non-existent slug" do
    get "/samples/pack/non-existent-pack"
    assert_response :not_found
  end

  test "pack returns 404 for non-sample-pack collection" do
    regular_collection = collections(:coffee_shop_essentials)
    get "/samples/pack/#{regular_collection.slug}"
    assert_response :not_found
  end

  # ==========================================================================
  # POST /samples/add_pack (add_pack)
  # ==========================================================================

  test "add_pack adds sample-eligible products to cart" do
    # Make a request to initialize the cart
    get samples_path
    assert_response :success

    initial_cart_count = Cart.count

    post add_pack_samples_path, params: { slug: @sample_pack.slug }
    assert_response :redirect
    assert_redirected_to cart_path

    # A cart should be created
    assert_operator Cart.count, :>=, initial_cart_count

    # Check flash message
    follow_redirect!
    assert flash[:notice].present?
  end

  test "add_pack shows flash message with count" do
    get samples_path  # Initialize cart
    post add_pack_samples_path, params: { slug: @sample_pack.slug }
    assert_response :redirect
    follow_redirect!

    # Flash should contain count of samples added
    assert flash[:notice].present?
    assert_match(/\d+ samples?/i, flash[:notice])
  end

  test "add_pack redirects to cart" do
    get samples_path  # Initialize cart
    post add_pack_samples_path, params: { slug: @sample_pack.slug }
    assert_redirected_to cart_path
  end

  test "add_pack returns 404 for non-existent pack" do
    get samples_path  # Initialize cart
    post add_pack_samples_path, params: { slug: "non-existent-pack" }
    assert_response :not_found
  end

  test "add_pack returns 404 for non-sample-pack collection" do
    regular_collection = collections(:coffee_shop_essentials)
    get samples_path  # Initialize cart
    post add_pack_samples_path, params: { slug: regular_collection.slug }
    assert_response :not_found
  end

  test "add_pack does not duplicate products already in cart" do
    # Initialize cart
    get samples_path

    # Add pack first time
    post add_pack_samples_path, params: { slug: @sample_pack.slug }
    assert_redirected_to cart_path

    # Remember how many items are in cart
    get cart_path
    initial_message = flash[:notice]

    # Add pack second time
    post add_pack_samples_path, params: { slug: @sample_pack.slug }
    follow_redirect!

    # Should say "all items already in cart"
    assert_match(/already in your cart/i, flash[:notice])
  end

  test "add_pack marks cart items as samples" do
    # Initialize cart
    get samples_path

    post add_pack_samples_path, params: { slug: @sample_pack.slug }
    assert_redirected_to cart_path

    # Get the cart from the session
    cart = Cart.last

    # All items added should be marked as samples
    assert cart.cart_items.any?, "Cart should have items"
    cart.cart_items.each do |item|
      assert item.is_sample, "Cart item for #{item.product.name} should have is_sample=true"
      assert item.sample?, "Cart item for #{item.product.name} should be a sample"
      assert_equal 0, item.price, "Sample items should have price=0"
    end
  end
end
