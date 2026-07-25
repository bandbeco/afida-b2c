require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  # ==========================================================================
  # free_shipping_threshold_display - formatted free-shipping threshold
  # ==========================================================================

  test "free_shipping_threshold_display formats the threshold as whole pounds" do
    assert_equal "£100", free_shipping_threshold_display
  end

  test "free_shipping_threshold_display delegates to Shipping" do
    assert_equal Shipping.formatted_free_shipping_threshold, free_shipping_threshold_display
  end

  test "free_shipping_threshold_display derives from Shipping::FREE_SHIPPING_THRESHOLD" do
    original = Shipping::FREE_SHIPPING_THRESHOLD
    Shipping.send(:remove_const, :FREE_SHIPPING_THRESHOLD)
    Shipping.const_set(:FREE_SHIPPING_THRESHOLD, BigDecimal("150"))

    assert_equal "£150", free_shipping_threshold_display
  ensure
    Shipping.send(:remove_const, :FREE_SHIPPING_THRESHOLD)
    Shipping.const_set(:FREE_SHIPPING_THRESHOLD, original)
  end

  # ==========================================================================
  # free_delivery_promise - the free-shipping claim, qualified by zone
  # ==========================================================================

  test "free_delivery_promise qualifies the claim as mainland UK" do
    assert_match(/mainland UK/i, free_delivery_promise)
  end

  test "free_delivery_promise states the threshold" do
    assert_includes free_delivery_promise, free_shipping_threshold_display
  end

  test "free_delivery_promise tracks a changed threshold" do
    original = Shipping::FREE_SHIPPING_THRESHOLD
    Shipping.send(:remove_const, :FREE_SHIPPING_THRESHOLD)
    Shipping.const_set(:FREE_SHIPPING_THRESHOLD, BigDecimal("150"))

    assert_includes free_delivery_promise, "£150"
  ensure
    Shipping.send(:remove_const, :FREE_SHIPPING_THRESHOLD)
    Shipping.const_set(:FREE_SHIPPING_THRESHOLD, original)
  end

  test "non_mainland_delivery_note points non-mainland customers somewhere" do
    assert_match(/highland|island|northern ireland/i, non_mainland_delivery_note)
  end

  # ==========================================================================
  # delivery_zone_name - the customer-facing name for a ShippingZone
  # ==========================================================================

  test "delivery_zone_name names every deliverable zone in plain words" do
    ShippingZone::ZONES.each do |zone|
      name = delivery_zone_name(zone)

      assert name.present?, "expected a name for #{zone}"
      assert_no_match(/_/, name, "#{zone} is shown to customers, so it can't read like a symbol")
    end
  end

  test "delivery_zone_name uses the customer's words, not ours" do
    assert_equal "mainland UK", delivery_zone_name(:mainland)
    assert_equal "Northern Ireland", delivery_zone_name(:northern_ireland)
    assert_equal "the Scottish Highlands", delivery_zone_name(:highlands)
  end

  # ==========================================================================
  # delivery_destination_known? - drives whether the cart offers checkout.
  # Checkout is refused without a destination, so the cart must not present a
  # button that will bounce the customer straight back.
  # ==========================================================================

  test "delivery_destination_known? is false for a cart with no postcode" do
    assert_not delivery_destination_known?(Cart.new)
  end

  test "delivery_destination_known? is true once a valid postcode is entered" do
    cart = Cart.new
    cart.delivery_postcode = "BT1 6EE"

    assert delivery_destination_known?(cart)
  end

  test "delivery_destination_known? is false for an unusable postcode" do
    cart = Cart.new
    cart.delivery_postcode = "not a postcode"

    assert_not delivery_destination_known?(cart)
  end

  test "delivery_destination_known? is true when a usable address is selected" do
    # A logged-in customer with a saved address never has to retype it, so the
    # cart offers checkout on the strength of that address alone.
    cart = Cart.new

    assert delivery_destination_known?(cart, address_postcode: "WD18 9SB")
  end

  test "delivery_destination_known? is false when the selected address is unusable" do
    # Mirrors the controller: a non-UK or malformed saved postcode can't be
    # priced, so it must not enable a button that checkout will refuse.
    cart = Cart.new

    assert_not delivery_destination_known?(cart, address_postcode: "00000")
  end

  test "delivery_destination_known? ignores a saved address that is not selected" do
    # The bug this guards: enabling the button because the user has SOME saved
    # address, while the controller checks the SELECTED one. Choosing "enter a
    # different address" with no postcode then loops cart -> guard -> cart.
    cart = Cart.new

    assert_not delivery_destination_known?(cart, address_postcode: nil)
  end
end
