require "test_helper"

class ProductSampleCtaTest < ActionDispatch::IntegrationTest
  setup do
    @sample_eligible = products(:sample_cup_12oz)
    @non_sample_eligible = products(:one)
  end

  test "renders sample CTA on a sample-eligible product page" do
    get product_path(@sample_eligible)

    assert_select "[data-test='product-sample-cta']"
  end

  test "sample CTA submits to cart_items as a free sample" do
    get product_path(@sample_eligible)

    assert_select "[data-test='product-sample-cta'] form" do
      assert_select "input[name='product_id'][value=?]", @sample_eligible.id.to_s
      assert_select "input[name='sample'][value='true']"
      assert_select "button[type='submit']", text: /Order a free sample/i
    end
  end

  test "sample CTA explains why a buyer would want a sample" do
    get product_path(@sample_eligible)

    assert_select "[data-test='product-sample-cta']", text: /Try before you buy/i
  end

  test "does not render sample CTA on a non-sample-eligible product" do
    get product_path(@non_sample_eligible)

    assert_select "[data-test='product-sample-cta']", count: 0
  end

  test "clicking the sample CTA adds the product to cart as a free sample" do
    assert_difference -> { Cart.last&.cart_items&.samples&.count.to_i }, 1 do
      post cart_cart_items_path,
           params: { product_id: @sample_eligible.id, sample: true },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    cart_item = Cart.last.cart_items.samples.last
    assert_equal @sample_eligible, cart_item.product
    assert_equal 0, cart_item.price
    assert cart_item.is_sample
  end

  test "submit-end on the sample CTA form opens the cart drawer" do
    get product_path(@sample_eligible)

    assert_select "[data-test='product-sample-cta'] form[data-controller~='cart-drawer']"
    assert_select "[data-test='product-sample-cta'] form[data-action~='turbo:submit-end->cart-drawer#open']"
  end

  test "sample-add response updates the cart counter and drawer content" do
    post cart_cart_items_path,
         params: { product_id: @sample_eligible.id, sample: true },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match(/turbo-stream action="replace" target="cart_counter"/, response.body)
    assert_match(/turbo-stream action="replace" target="drawer_cart_content"/, response.body)
  end
end
