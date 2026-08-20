require "test_helper"

# The buy box runs quantity -> attach -> total -> Add to Cart with nothing in
# between. The contact and sample routes are real, but they are exits, and an
# exit placed mid-purchase is taken by buyers who were about to commit.
class ProductBuyBoxOrderTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:sample_cup_8oz)
  end

  test "the sample and contact routes come after the add-to-cart button" do
    get product_path(@product)

    body = @response.body
    cta = body.index("add-to-cart-form")
    sample = body.index("product-sample-cta")
    contact = body.index("Can't find what you're looking for?")

    assert cta, "expected the add-to-cart form on the page"
    assert sample && sample > cta, "the sample block must sit below the add-to-cart form"
    assert contact && contact > cta, "the contact prompt must sit below the add-to-cart form"
  end

  test "the sample route keeps its pay-only-delivery framing" do
    get product_path(@product)

    assert_select "[data-test='product-sample-cta']", text: /only pay for delivery/i
  end

  test "the buy box keeps the delivery countdown and trust strip" do
    get product_path(@product)

    assert_select "[data-delivery-countdown-target='countdown']"
    assert_select "[data-test='product-trust-strip']"
  end
end
