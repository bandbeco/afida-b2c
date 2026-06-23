# frozen_string_literal: true

# Single source of truth for the order-totals formula: given a subtotal, apply the
# VAT rate and the free-shipping rule to produce {subtotal, vat, shipping, total}.
#
# This formula used to be re-derived in three places that drifted apart — Cart, the
# pending-order snapshot builder, and a reorder view that hardcoded `subtotal * 0.2`.
# Callers still sum their own line items into a subtotal (a cart item, a snapshot
# hash and a schedule item are different shapes); OrderTotals owns only the rules,
# which are what actually duplicated and drifted.
#
# Shipping stance (see CONTEXT.md):
#   :deferred — shipping not known yet (cart, reorder preview). No shipping line;
#               total = subtotal + vat. The cart shows "calculated at checkout".
#   :charged  — shipping fixed at order time (snapshot). Free at/above the
#               free-shipping threshold, otherwise the standard cost; total includes it.
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

  Result = Data.define(:subtotal, :vat, :shipping, :total) do
    # The same totals with every component rounded to 2dp. total is recomputed from
    # the rounded parts so "subtotal + vat + shipping == total" holds at penny
    # precision (avoiding round-then-sum drift). Used when persisting money.
    def rounded
      rounded_subtotal = subtotal.round(2)
      rounded_vat = vat.round(2)
      rounded_shipping = shipping&.round(2)
      Result.new(
        subtotal: rounded_subtotal,
        vat: rounded_vat,
        shipping: rounded_shipping,
        total: rounded_subtotal + rounded_vat + (rounded_shipping || 0)
      )
    end
  end

  def self.for(subtotal, shipping:)
    new(subtotal, shipping_stance: shipping).result
  end

  def initialize(subtotal, shipping_stance:)
    unless SHIPPING_STANCES.include?(shipping_stance)
      raise ArgumentError, "unknown shipping stance #{shipping_stance.inspect} (expected one of #{SHIPPING_STANCES.inspect})"
    end

    @subtotal = subtotal
    @shipping_stance = shipping_stance
  end

  def result
    # Compute each component once; total reuses both, so locals avoid recomputing
    # vat and shipping a second time.
    vat_amount = vat
    shipping_amount = shipping
    Result.new(
      subtotal: @subtotal,
      vat: vat_amount,
      shipping: shipping_amount,
      total: @subtotal + vat_amount + (shipping_amount || 0)
    )
  end

  private

  def vat
    @subtotal * BigDecimal(VAT_RATE.to_s)
  end

  # nil when deferred (no shipping line yet); 0 or the standard cost when charged.
  def shipping
    return nil if @shipping_stance == :deferred

    @subtotal >= Shipping::FREE_SHIPPING_THRESHOLD ? BigDecimal("0") : standard_cost
  end

  def standard_cost
    BigDecimal(Shipping.standard_cost_in_pounds.to_s)
  end
end
