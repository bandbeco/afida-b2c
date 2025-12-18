require "test_helper"

class CartsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product_variant = product_variants(:one)
  end

  # GET /cart
  test "should show cart for guest" do
    get cart_url
    assert_response :success
    # A cart should be created automatically
    assert_not_nil session[:cart_id]
  end

  test "should show cart page even when empty" do
    get cart_url
    assert_response :success
  end

  test "cart page is accessible to authenticated users" do
    user = users(:one)
    sign_in_as(user)

    get cart_url
    assert_response :success
  end

  test "should create cart automatically on first visit" do
    assert_difference("Cart.count", 1) do
      get cart_url
    end
    assert_response :success
  end

  test "should use existing cart from session" do
    # First request creates cart
    get cart_url
    cart_id = session[:cart_id]

    # Second request should reuse same cart
    assert_no_difference("Cart.count") do
      get cart_url
    end
    assert_equal cart_id, session[:cart_id]
  end

  test "authenticated user gets their own cart" do
    user = users(:one)
    sign_in_as(user)

    get cart_url
    cart = Cart.find_by(user: user)
    assert_not_nil cart
    assert_response :success
  end

  # Cart item display tests for options_display
  test "cart displays standard product variant with space-separated options" do
    # First get cart to create it
    get cart_url
    cart = Cart.find(session[:cart_id])

    # Add a standard product variant (not consolidated)
    variant = product_variants(:single_wall_8oz_white)
    cart.cart_items.create!(product_variant: variant, quantity: 1, price: variant.price)

    get cart_url
    assert_response :success
    # Standard products show options space-separated (e.g., "8oz White")
    assert_match variant.options_display, response.body
  end

  test "cart displays consolidated product variant with slash-separated options" do
    # First get cart to create it
    get cart_url
    cart = Cart.find(session[:cart_id])

    # Add a consolidated product variant (wooden cutlery with material option)
    variant = product_variants(:wooden_fork)
    cart.cart_items.create!(product_variant: variant, quantity: 1, price: variant.price)

    get cart_url
    assert_response :success
    # Consolidated products show options with slashes (e.g., "Birch / Fork")
    assert_match "Birch / Fork", response.body
  end

  test "cart displays different consolidated variants correctly" do
    get cart_url
    cart = Cart.find(session[:cart_id])

    # Add two different consolidated product variants
    birch_fork = product_variants(:wooden_fork)
    bamboo_knife = product_variants(:bamboo_knife)

    cart.cart_items.create!(product_variant: birch_fork, quantity: 1, price: birch_fork.price)
    cart.cart_items.create!(product_variant: bamboo_knife, quantity: 1, price: bamboo_knife.price)

    get cart_url
    assert_response :success
    assert_match "Birch / Fork", response.body
    assert_match "Bamboo / Knife", response.body
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end
end
