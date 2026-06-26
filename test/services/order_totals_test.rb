# frozen_string_literal: true

require "test_helper"

# OrderTotals owns the order-totals formula: given a subtotal, apply the VAT rate
# and the free-shipping rule to produce {subtotal, vat, shipping, total}. It is the
# single home for that formula, which previously drifted across Cart, the snapshot
# builder, and a reorder view (which hardcoded `subtotal * 0.2`).
#
# Two shipping stances (see CONTEXT.md):
#   :deferred — shipping unknown yet (cart, reorder preview); total = subtotal + vat
#   :charged  — shipping fixed (snapshot); free over the threshold, else standard cost
class OrderTotalsTest < ActiveSupport::TestCase
  STANDARD_COST = BigDecimal(Shipping::STANDARD_COST.to_s) / 100 # e.g. 6.99
  THRESHOLD = Shipping::FREE_SHIPPING_THRESHOLD                  # e.g. 100

  # ==========================================================================
  # :deferred — cart / reorder preview (shipping not yet known)
  # ==========================================================================

  test "deferred omits shipping and totals subtotal plus vat" do
    totals = OrderTotals.for(BigDecimal("20.00"), shipping: :deferred)

    assert_equal BigDecimal("20.00"), totals.subtotal
    assert_equal BigDecimal("4.00"), totals.vat
    assert_nil totals.shipping
    assert_equal BigDecimal("24.00"), totals.total
  end

  test "deferred total ignores the free-shipping threshold entirely" do
    # Even a large subtotal carries no shipping line when deferred.
    totals = OrderTotals.for(BigDecimal("500.00"), shipping: :deferred)

    assert_nil totals.shipping
    assert_equal BigDecimal("600.00"), totals.total # 500 + 100 vat
  end

  # ==========================================================================
  # :charged — snapshot (shipping fixed at order time)
  # ==========================================================================

  test "charged below threshold applies standard shipping and taxes it" do
    totals = OrderTotals.for(BigDecimal("96.00"), shipping: :charged)

    # VAT is charged on subtotal + shipping: (96.00 + 6.99) * 0.2 = 20.598
    assert_equal BigDecimal("96.00"), totals.subtotal
    assert_equal (BigDecimal("96.00") + STANDARD_COST) * BigDecimal(VAT_RATE.to_s), totals.vat
    assert_equal STANDARD_COST, totals.shipping
    assert_equal BigDecimal("96.00") + STANDARD_COST + totals.vat, totals.total
  end

  test "charged above threshold ships free and so adds no shipping vat" do
    totals = OrderTotals.for(BigDecimal("104.00"), shipping: :charged)

    # Shipping is free, so subtotal + shipping == subtotal: 104.00 * 0.2 = 20.80
    assert_equal BigDecimal("0"), totals.shipping
    assert_equal BigDecimal("20.80"), totals.vat
    assert_equal BigDecimal("104.00") + BigDecimal("20.80"), totals.total
  end

  test "charged exactly at threshold ships free (boundary is inclusive)" do
    totals = OrderTotals.for(THRESHOLD, shipping: :charged)

    assert_equal BigDecimal("0"), totals.shipping
  end

  test "charged just under threshold still pays standard shipping" do
    totals = OrderTotals.for(THRESHOLD - BigDecimal("0.01"), shipping: :charged)

    assert_equal STANDARD_COST, totals.shipping
  end

  # ==========================================================================
  # discount: a whole-order reduction (the welcome coupon)
  # ==========================================================================
  #
  # The welcome coupon is a plain Stripe percent_off coupon with no applies_to
  # restriction, so it discounts the WHOLE order: products AND the (taxed) shipping
  # line. Stripe accounts for it as amount_total = amount_subtotal + amount_tax -
  # amount_discount, where amount_subtotal includes shipping and amount_tax is on the
  # post-discount amount. The discount is passed as a RATE (e.g. 0.10) and applied to
  # subtotal + shipping after shipping is resolved, so the preview matches the charge.

  test "discount rate defaults to zero so existing callers are unaffected" do
    with_default = OrderTotals.for(BigDecimal("20.00"), shipping: :deferred)
    explicit_zero = OrderTotals.for(BigDecimal("20.00"), shipping: :deferred, discount_rate: BigDecimal("0"))

    assert_equal BigDecimal("0"), with_default.discount
    assert_equal explicit_zero.total, with_default.total
  end

  test "deferred discount reduces the vat base and the total but not the subtotal line" do
    # No shipping line when deferred, so the whole-order base is just the subtotal:
    # discount 10% of 20 = 2 -> VAT on (20 - 2) = 3.60, total = 18 + 3.60 = 21.60.
    totals = OrderTotals.for(BigDecimal("20.00"), shipping: :deferred, discount_rate: BigDecimal("0.10"))

    assert_equal BigDecimal("20.00"), totals.subtotal
    assert_equal BigDecimal("2.00"), totals.discount
    assert_equal BigDecimal("3.60"), totals.vat
    assert_nil totals.shipping
    assert_equal BigDecimal("21.60"), totals.total
  end

  test "charged discount reduces the whole order including shipping, then vat is on the remainder" do
    # subtotal 20 (< threshold so shipping 6.99). Whole-order discount applies to
    # subtotal + shipping: 10% of (20 + 6.99) = 2.699. VAT base = 26.99 - 2.699 =
    # 24.291 -> VAT = 4.8582; total = 24.291 + 4.8582 = 29.1492.
    totals = OrderTotals.for(BigDecimal("20.00"), shipping: :charged, discount_rate: BigDecimal("0.10"))

    gross = BigDecimal("20.00") + STANDARD_COST
    assert_equal STANDARD_COST, totals.shipping
    assert_equal gross * BigDecimal("0.10"), totals.discount
    assert_equal BigDecimal("2.699"), totals.discount
    assert_equal (gross - totals.discount) * BigDecimal(VAT_RATE.to_s), totals.vat
    assert_equal BigDecimal("4.8582"), totals.vat
    assert_equal (gross - totals.discount) + totals.vat, totals.total
    assert_equal BigDecimal("29.1492"), totals.total
  end

  test "charged discount with free shipping discounts the subtotal alone (shipping is zero)" do
    # Above threshold so shipping is 0; the whole-order base is just the subtotal.
    # 10% of 104 = 10.40; VAT base = 104 - 10.40 = 93.60 -> VAT 18.72.
    totals = OrderTotals.for(BigDecimal("104.00"), shipping: :charged, discount_rate: BigDecimal("0.10"))

    assert_equal BigDecimal("0"), totals.shipping
    assert_equal BigDecimal("10.40"), totals.discount
    assert_equal BigDecimal("18.72"), totals.vat
    assert_equal BigDecimal("93.60") + BigDecimal("18.72"), totals.total
  end

  test "the discount does not move the free-shipping threshold (it keys off the gross subtotal)" do
    # Gross subtotal is exactly the threshold, so shipping is free even though the
    # discounted subtotal dips below it. The discount must not re-introduce shipping.
    totals = OrderTotals.for(THRESHOLD, shipping: :charged, discount_rate: BigDecimal("0.10"))

    assert_equal BigDecimal("0"), totals.shipping
  end

  test "rounded carries the discount through at two decimal places" do
    # 10% of (33.33 + 6.99) = 4.032 -> rounds to 4.03.
    rounded = OrderTotals.for(BigDecimal("33.33"), shipping: :charged, discount_rate: BigDecimal("0.10")).rounded

    assert_equal BigDecimal("4.03"), rounded.discount
  end

  # ==========================================================================
  # VAT rate
  # ==========================================================================

  test "deferred vat is the configured rate applied to the subtotal, unrounded" do
    # No shipping line when deferred, so VAT is on the subtotal alone.
    # 33.33 * 0.2 = 6.666 — full precision, not yet rounded to pennies.
    totals = OrderTotals.for(BigDecimal("33.33"), shipping: :deferred)

    assert_equal BigDecimal("33.33") * BigDecimal(VAT_RATE.to_s), totals.vat
    assert_equal BigDecimal("6.666"), totals.vat
  end

  test "charged vat is the configured rate applied to subtotal plus shipping, unrounded" do
    # (33.33 + 6.99) * 0.2 = 8.064, full precision, not yet rounded to pennies.
    totals = OrderTotals.for(BigDecimal("33.33"), shipping: :charged)

    assert_equal (BigDecimal("33.33") + STANDARD_COST) * BigDecimal(VAT_RATE.to_s), totals.vat
    assert_equal BigDecimal("8.064"), totals.vat
  end

  # ==========================================================================
  # .rounded — used when persisting money to 2dp (the snapshot)
  # ==========================================================================

  test "rounded returns each component at two decimal places" do
    rounded = OrderTotals.for(BigDecimal("33.33"), shipping: :charged).rounded

    assert_equal BigDecimal("33.33"), rounded.subtotal
    assert_equal BigDecimal("8.06"), rounded.vat       # (33.33 + 6.99) * 0.2 = 8.064 -> 8.06
    assert_equal STANDARD_COST.round(2), rounded.shipping
    assert_equal BigDecimal("48.38"), rounded.total    # 33.33 + 8.06 + 6.99
  end

  test "rounded keeps parts summing to the rounded total" do
    rounded = OrderTotals.for(BigDecimal("33.33"), shipping: :charged).rounded

    sum_of_parts = rounded.subtotal + rounded.vat + rounded.shipping
    assert_equal rounded.total, sum_of_parts
  end

  test "rounded deferred leaves shipping nil and sums subtotal plus vat" do
    rounded = OrderTotals.for(BigDecimal("33.33"), shipping: :deferred).rounded

    assert_nil rounded.shipping
    assert_equal BigDecimal("40.00"), rounded.total # 33.33 + 6.67
  end

  # ==========================================================================
  # Guard rails
  # ==========================================================================

  test "an unknown shipping stance is rejected" do
    assert_raises(ArgumentError) do
      OrderTotals.for(BigDecimal("10.00"), shipping: :whenever)
    end
  end
end
