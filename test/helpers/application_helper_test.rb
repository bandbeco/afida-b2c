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

  # ============================================================
  # free_delivery_nudge - the countdown, measured against the cart alone
  # ============================================================

  # An empty cart has nothing to count down from, so it gets the rule. Telling
  # a buyer to "add £61 more" against a page total they have not committed to
  # was the original defect here.
  test "free_delivery_nudge states the rule for an empty cart" do
    assert_equal free_delivery_promise, free_delivery_nudge(0)
  end

  test "free_delivery_nudge counts down from what the cart holds" do
    assert_equal "Add £70.35 more for free mainland UK delivery",
                 free_delivery_nudge(29.65)
  end

  test "free_delivery_nudge confirms once the threshold is reached" do
    assert_match(/qualifies/i, free_delivery_nudge(100))
    assert_match(/qualifies/i, free_delivery_nudge(250))
  end

  # The gap is threshold minus cart, so it has to move with the threshold
  # rather than with a hardcoded 100.
  test "free_delivery_nudge derives the gap from the threshold" do
    original = Shipping::FREE_SHIPPING_THRESHOLD
    Shipping.send(:remove_const, :FREE_SHIPPING_THRESHOLD)
    Shipping.const_set(:FREE_SHIPPING_THRESHOLD, BigDecimal("150"))

    assert_equal "Add £50.00 more for free mainland UK delivery",
                 free_delivery_nudge(100)
  ensure
    Shipping.send(:remove_const, :FREE_SHIPPING_THRESHOLD)
    Shipping.const_set(:FREE_SHIPPING_THRESHOLD, original)
  end

  test "free_delivery_nudge keeps every state mainland-qualified" do
    [ 0, 29.65, 250 ].each do |subtotal|
      assert_match(/mainland UK/i, free_delivery_nudge(subtotal),
                   "subtotal #{subtotal} dropped the mainland qualifier")
    end
  end
end
