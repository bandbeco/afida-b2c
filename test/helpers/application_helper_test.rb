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

  # --------------------------------------------------------------------
  # free_delivery_progress - how far the cart has come, as a percentage
  # --------------------------------------------------------------------

  test "free_delivery_progress is empty at nothing spent" do
    assert_equal 0, free_delivery_progress(0)
  end

  test "free_delivery_progress tracks the cart against the threshold" do
    assert_equal 50, free_delivery_progress(50)
    assert_equal 25, free_delivery_progress(25)
  end

  test "free_delivery_progress is full at the threshold" do
    assert_equal 100, free_delivery_progress(100)
  end

  # The bar is a width, and a width over 100% would overflow its track. A cart
  # past the threshold is simply full.
  test "free_delivery_progress never exceeds full" do
    assert_equal 100, free_delivery_progress(250)
  end

  # A negative subtotal should not invert the bar. Not reachable today, but the
  # bar renders whatever it is handed.
  test "free_delivery_progress never goes below empty" do
    assert_equal 0, free_delivery_progress(BigDecimal("-10"))
  end

  # Rounded to whole percents: the bar is a few hundred pixels wide, so
  # fractional precision buys nothing and makes the style attribute noisy.
  test "free_delivery_progress rounds to whole percents" do
    assert_equal 33, free_delivery_progress(BigDecimal("33.33"))
    assert_kind_of Integer, free_delivery_progress(BigDecimal("33.33"))
  end

  # A nearly-complete cart must not round up to a full bar: a bar reading 100%
  # beside the words "Add £0.01 more" is the same contradiction the tint rule
  # exists to prevent.
  test "free_delivery_progress stops short of full while a gap remains" do
    assert_equal 99, free_delivery_progress(BigDecimal("99.99"))
    assert_equal 99, free_delivery_progress(BigDecimal("99.999"))
  end

  # The money figure is the part of the sentence a buyer scans for, so it has to
  # be readable, not just green. DaisyUI's `success` is a bright mint that comes
  # out at 1.84:1 on the band's near-white background, well under the 4.5:1 AA
  # minimum for body text; `success-content` is the same hue darkened, and
  # measures 9.45:1. The bar fill and the icon keep the bright tone, where the
  # colour is decorative and carries no text.
  test "highlight_money marks the figure in a readable green" do
    marked = highlight_money("Add £43.96 more for free mainland UK delivery")

    assert_includes marked, "text-success-content"
    # -content is a distinct token, and \b treats the hyphen as a boundary, so
    # the bare class has to be excluded by what follows it.
    refute_match(/class="[^"]*text-success(?!-content)[^"]*"/, marked,
                 "the money figure kept the low-contrast success tone")
  end

  test "free_delivery_progress tracks a changed threshold" do
    original = Shipping::FREE_SHIPPING_THRESHOLD
    Shipping.send(:remove_const, :FREE_SHIPPING_THRESHOLD)
    Shipping.const_set(:FREE_SHIPPING_THRESHOLD, BigDecimal("200"))

    assert_equal 50, free_delivery_progress(100)
  ensure
    Shipping.send(:remove_const, :FREE_SHIPPING_THRESHOLD)
    Shipping.const_set(:FREE_SHIPPING_THRESHOLD, original)
  end
end
