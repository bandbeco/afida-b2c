# frozen_string_literal: true

# Single source of truth for the order-totals formula: given a subtotal, apply the
# free-shipping rule and the VAT rate to produce {subtotal, vat, shipping, total}.
# VAT is charged on subtotal + shipping (UK VAT applies to delivery charges), so it
# is computed after shipping is resolved.
#
# This formula used to be re-derived in three places that drifted apart — Cart, the
# pending-order snapshot builder, and a reorder view that hardcoded `subtotal * 0.2`.
# Callers still sum their own line items into a subtotal (a cart item, a snapshot
# hash and a schedule item are different shapes); OrderTotals owns only the rules,
# which are what actually duplicated and drifted.
#
# Shipping stance (see CONTEXT.md):
#   :deferred — shipping not known yet (cart, reorder preview). No shipping line;
#               VAT is on the subtotal alone and total = subtotal + vat. The cart
#               shows "calculated at checkout".
#   :charged  — shipping fixed at order time (snapshot). Free at/above the
#               free-shipping threshold, otherwise the standard cost; VAT is charged
#               on subtotal + shipping and total includes both.
#
# Components are full-precision BigDecimals so display callers can round once, at the
# view, via number_to_currency (unchanged behaviour). Callers that must persist money
# to pennies (the snapshot) call #rounded, which rounds each component to 2dp and
# keeps the parts summing to the rounded total.
#
# The VAT rate and shipping figures are read from their existing homes (VAT_RATE in
# config/initializers/vat.rb; Shipping::FREE_SHIPPING_THRESHOLD and
# Shipping.standard_cost_in_pounds) rather than redefined here.
#
# Usage:
#   totals = OrderTotals.for(cart.subtotal_amount, shipping: :deferred)
#   totals.total                       # subtotal + vat
#
#   snapshot = OrderTotals.for(subtotal, shipping: :charged).rounded
#   snapshot.vat                       # 2dp BigDecimal
class OrderTotals
  SHIPPING_STANCES = %i[deferred charged].freeze

  Result = Data.define(:subtotal, :vat, :shipping, :total, :discount) do
    # The same totals with every component rounded to 2dp. total is recomputed from
    # the rounded parts so "subtotal + shipping - discount + vat == total" holds at
    # penny precision (avoiding round-then-sum drift). Used when persisting money.
    def rounded
      rounded_subtotal = subtotal.round(2)
      rounded_vat = vat.round(2)
      rounded_shipping = shipping&.round(2)
      rounded_discount = discount.round(2)
      Result.new(
        subtotal: rounded_subtotal,
        vat: rounded_vat,
        shipping: rounded_shipping,
        discount: rounded_discount,
        total: rounded_subtotal + (rounded_shipping || 0) - rounded_discount + rounded_vat
      )
    end
  end

  # discount_rate is an optional whole-order reduction (the welcome coupon), e.g.
  # 0.10 for 10% off. The coupon is a plain Stripe percent_off with no applies_to
  # restriction, so it discounts the whole order: the subtotal AND any charged
  # (taxed) shipping. It lowers the VAT base and the total, but never the
  # free-shipping decision (which keys off the gross subtotal, as Stripe does).
  def self.for(subtotal, shipping:, discount_rate: BigDecimal("0"))
    new(subtotal, shipping_stance: shipping, discount_rate: discount_rate).result
  end

  def initialize(subtotal, shipping_stance:, discount_rate: BigDecimal("0"))
    unless SHIPPING_STANCES.include?(shipping_stance)
      raise ArgumentError, "unknown shipping stance #{shipping_stance.inspect} (expected one of #{SHIPPING_STANCES.inspect})"
    end

    @subtotal = subtotal
    @shipping_stance = shipping_stance
    @discount_rate = BigDecimal(discount_rate.to_s)
  end

  def result
    # Compute shipping first; the discount is a fraction of subtotal + shipping, and
    # VAT is charged on the post-discount amount, so both reuse the resolved shipping.
    shipping_amount = shipping
    discount_amount = discount(shipping_amount)
    vat_amount = vat(shipping_amount, discount_amount)
    Result.new(
      subtotal: @subtotal,
      vat: vat_amount,
      shipping: shipping_amount,
      discount: discount_amount,
      total: (gross(shipping_amount) - discount_amount) + vat_amount
    )
  end

  private

  # The gross (pre-discount) order value: subtotal plus any charged shipping. The
  # whole-order discount and the VAT base are both derived from this. When shipping
  # is deferred (nil) the gross is the subtotal alone.
  def gross(shipping_amount)
    @subtotal + (shipping_amount || 0)
  end

  # The whole-order discount in money: the rate applied to subtotal + shipping,
  # matching a Stripe percent_off coupon with no applies_to restriction. Zero when
  # no rate is set or (for a deferred cart) shipping is unknown but the rate is 0.
  def discount(shipping_amount)
    gross(shipping_amount) * @discount_rate
  end

  # VAT applies to the post-discount order value (Stripe taxes the discounted
  # amount, spanning products + shipping). When shipping is deferred (nil) the base
  # is the discounted subtotal.
  def vat(shipping_amount, discount_amount)
    (gross(shipping_amount) - discount_amount) * BigDecimal(VAT_RATE.to_s)
  end

  # nil when deferred (no shipping line yet); 0 or the standard cost when charged.
  # Keyed off the gross subtotal so a discount can't tip an order back below the
  # free-shipping threshold, matching SessionBuilder (which checks cart.subtotal_amount).
  def shipping
    return nil if @shipping_stance == :deferred

    @subtotal >= Shipping::FREE_SHIPPING_THRESHOLD ? BigDecimal("0") : standard_cost
  end

  def standard_cost
    BigDecimal(Shipping.standard_cost_in_pounds.to_s)
  end
end
