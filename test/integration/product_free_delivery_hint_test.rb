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
end
