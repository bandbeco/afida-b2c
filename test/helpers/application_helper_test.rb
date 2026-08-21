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

  # A cart a sub-penny short was told to "Add £0.00 more", an instruction nobody
  # can follow. Reachable in production: cart_items.price is scale-4 and
  # configured items divide a total by a quantity. It asks for the penny that
  # actually closes the gap instead.
  test "free_delivery_nudge asks for a real penny when a sub-penny short" do
    assert_match(/Add £0\.01 more/, free_delivery_nudge(BigDecimal("99.999")))
    assert_match(/Add £0\.01 more/, free_delivery_nudge(BigDecimal("99.9951")))
  end

  # The nudge must never promise what checkout would refuse. Shipping decides on
  # the unrounded subtotal, so qualifying must too: a page that says "qualifies"
  # for a cart a fraction of a penny short gets caught out at payment.
  test "free_delivery_nudge never promises what checkout would refuse" do
    (99_900..100_000).each do |thousandths|
      subtotal = BigDecimal(thousandths.to_s) / 1000
      next unless free_delivery_nudge(subtotal).match?(/qualifies/i)

      assert Shipping.free_shipping?(zone: :mainland, subtotal: subtotal),
             "promised free delivery at #{subtotal.to_f}, which Shipping refuses"
    end
  end

  test "free_delivery_qualified? matches Shipping exactly" do
    [ "99.99", "99.999", "100", "100.001", "0" ].each do |value|
      subtotal = BigDecimal(value)

      assert_equal Shipping.free_shipping?(zone: :mainland, subtotal: subtotal),
                   free_delivery_qualified?(subtotal),
                   "disagreed with Shipping at #{value}"
    end
  end

  test "free_delivery_nudge never asks for zero pence" do
    (9_990..10_000).each do |tenths|
      subtotal = BigDecimal(tenths.to_s) / 100
      refute_match(/Add £0\.00 more/, free_delivery_nudge(subtotal),
                   "subtotal #{subtotal.to_f} asked for £0.00")
    end
  end

  # A sub-penny cart is still a countdown rather than the opening rule, and the
  # figure rounds UP: the true gap is £99.999, so asking for £99.99 would leave
  # the buyer short of the threshold they were told it would reach.
  test "free_delivery_nudge counts down from a sub-penny cart" do
    nudge = free_delivery_nudge(BigDecimal("0.001"))

    assert_match(/\AAdd /, nudge)
    assert_match(/Add £100\.00 more/, nudge)
  end

  test "free_delivery_nudge never asks for zero across the final pound" do
    (99_000..100_000).each do |thousandths|
      subtotal = BigDecimal(thousandths.to_s) / 1000

      refute_includes free_delivery_nudge(subtotal), "£0.00",
                      "subtotal #{subtotal.to_f} asked for £0.00"
    end
  end

  # Rounding up must never overshoot into asking for more than the gap.
  test "free_delivery_nudge never asks for more than the gap" do
    [ "0.001", "12.344", "99.5", "99.99" ].each do |value|
      subtotal = BigDecimal(value)
      asked = free_delivery_nudge(subtotal)[/£([\d,]+\.\d{2})/, 1].delete(",").to_d
      true_gap = Shipping::FREE_SHIPPING_THRESHOLD - subtotal

      assert_operator asked, :>=, true_gap.round(2),
                      "#{value}: asked £#{asked} but needs £#{true_gap}"
      assert_operator asked - true_gap, :<=, BigDecimal("0.01"),
                      "#{value}: asked £#{asked}, overshooting a gap of £#{true_gap}"
    end
  end

  test "free_delivery_nudge keeps every state mainland-qualified" do
    [ 0, 29.65, 250 ].each do |subtotal|
      assert_match(/mainland UK/i, free_delivery_nudge(subtotal),
                   "subtotal #{subtotal} dropped the mainland qualifier")
    end
  end
end
