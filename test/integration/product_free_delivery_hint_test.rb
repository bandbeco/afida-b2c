require "test_helper"

class ProductFreeDeliveryHintTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:single_wall_8oz_white)
  end

  test "renders a visually prominent free-delivery hint on the PDP" do
    get product_path(@product)

    assert_select "[data-test='free-delivery-hint']" do
      assert_select "[data-test='free-delivery-amount']", text: /£100/
    end
  end

  test "free-delivery hint mentions free delivery" do
    get product_path(@product)

    assert_select "[data-test='free-delivery-hint']", text: /free delivery/i
  end

  # Free delivery only applies to the mainland (ShippingZone::FREE_SHIPPING_ZONES).
  # An unqualified claim here is a promise we cannot keep for Northern Ireland,
  # the Highlands or the islands, all of which have placed real orders.
  test "free-delivery hint qualifies the promise as mainland UK" do
    get product_path(@product)

    assert_select "[data-test='free-delivery-hint']", text: /mainland UK/i
  end

  # The hint is worth more as a countdown than as a poster: a buyer £12 short
  # will top up, a buyer told only "over £100" has to work it out. The server
  # supplies the threshold and what the cart already holds; the page counts down
  # as the selection changes.
  test "the buy box carries the threshold and the cart's current subtotal" do
    get product_path(@product)

    assert_select "[data-free-delivery-threshold-value='100.0']"
    assert_select "[data-free-delivery-cart-subtotal-value='0.0']"
    assert_select "[data-free-delivery-target='message']"
  end

  # Without an opening figure the hint would wait for the buyer's first click
  # before correcting itself, so someone arriving with a full cart would be told
  # to reach a threshold they had already passed.
  test "the hint knows what the page opens on before any interaction" do
    get product_path(@product)

    assert_select "[data-free-delivery-opening-total-value=?]",
                  @product.pricing_tiers.last["price"].to_f.to_s
  end

  test "a flat-priced product opens on its pack price" do
    lid = products(:flat_lid_8oz)

    get product_path(lid)

    assert_select "[data-free-delivery-opening-total-value=?]", lid.price.to_f.to_s
  end

  # With an empty cart the hint states the rule rather than counting down,
  # because "add £61 more" would mean £61 on top of a page total the buyer has
  # not committed to. The client repeats this wording in that state, so the two
  # must not drift apart.
  test "the server-rendered hint states the rule rather than a countdown" do
    get product_path(@product)

    assert_select "[data-test='free-delivery-hint']", text: /over £100/i
    assert_select "[data-test='free-delivery-hint']", text: /\Aadd /i, count: 0
  end

  test "the cart subtotal reflects what is already in the cart" do
    lid = products(:flat_lid_8oz)
    post cart_cart_items_path, params: { cart_item: { sku: lid.sku, quantity: 2 } }

    get product_path(@product)

    assert_select "[data-free-delivery-cart-subtotal-value=?]", (lid.price * 2).to_f.to_s
  end
end
