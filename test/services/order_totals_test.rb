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

  test "charged below threshold applies standard shipping" do
    totals = OrderTotals.for(BigDecimal("96.00"), shipping: :charged)

    assert_equal BigDecimal("96.00"), totals.subtotal
    assert_equal BigDecimal("19.20"), totals.vat
    assert_equal STANDARD_COST, totals.shipping
    assert_equal BigDecimal("96.00") + BigDecimal("19.20") + STANDARD_COST, totals.total
  end

  test "charged above threshold ships free" do
    totals = OrderTotals.for(BigDecimal("104.00"), shipping: :charged)

    assert_equal BigDecimal("0"), totals.shipping
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
  # VAT rate
  # ==========================================================================

  test "vat is the configured rate applied to the subtotal, unrounded" do
    # 33.33 * 0.2 = 6.666 — full precision, not yet rounded to pennies.
    totals = OrderTotals.for(BigDecimal("33.33"), shipping: :deferred)

    assert_equal BigDecimal("33.33") * BigDecimal(VAT_RATE.to_s), totals.vat
    assert_equal BigDecimal("6.666"), totals.vat
  end

  # ==========================================================================
  # .rounded — used when persisting money to 2dp (the snapshot)
  # ==========================================================================

  test "rounded returns each component at two decimal places" do
    rounded = OrderTotals.for(BigDecimal("33.33"), shipping: :charged).rounded

    assert_equal BigDecimal("33.33"), rounded.subtotal
    assert_equal BigDecimal("6.67"), rounded.vat       # 6.666 -> 6.67
    assert_equal STANDARD_COST.round(2), rounded.shipping
    assert_equal BigDecimal("46.99"), rounded.total    # 33.33 + 6.67 + 6.99
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
