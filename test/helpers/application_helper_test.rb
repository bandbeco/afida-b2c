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
end
