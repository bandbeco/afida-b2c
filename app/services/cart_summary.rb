# frozen_string_literal: true

# The cart-totals summary as an ordered list of display lines: the single source of
# truth for what the cart surfaces render, the cart-side twin of OrderSummary.
# Used by:
#   - the cart page (cart_items/_index) via CartsHelper
#   - the cart drawer (shared/_drawer_cart_content) via CartsHelper
#
# Returns the SAME shape as OrderSummary.lines so the cart and order surfaces stay
# structurally identical: each line is { kind:, label:, amount:, negative: }, in the
# order Subtotal -> Shipping -> Discount -> VAT -> Total. Each surface supplies its
# own markup (the full-page card vs the compact drawer) and iterates these lines.
#
# Differences from OrderSummary, all because the cart is a pre-checkout preview:
#   - Shipping shows "Free" / "Calculate at checkout" (see #shipping_display), not
#     just a currency amount.
#   - the discount line is labelled with the welcome percentage (the cart has no
#     Stripe coupon code yet), not a recorded code.
#   - the Total is the cart's display_total_amount (the sum of the rounded lines, so
#     it reconciles with the lines above it and with the Stripe charge).
# The discount-visibility rule (only when a discount is actually taken) and the
# money format match OrderSummary exactly.
class CartSummary
  def self.lines(cart)
    new(cart).lines
  end

  def initialize(cart)
    @cart = cart
  end

  def lines
    result = [
      line(:subtotal, "Subtotal", money(@cart.subtotal_amount)),
      line(:shipping, "Shipping", shipping_display)
    ]
    result << discount_line if @cart.discount_amount.positive?
    result << line(:vat, "VAT (#{(VAT_RATE * 100).to_i}%)", money(@cart.vat_amount))
    result << line(:total, "Total", money(@cart.display_total_amount))
    result
  end

  private

  def line(kind, label, amount)
    { kind: kind, label: label, amount: amount, negative: false }
  end

  def discount_line
    {
      kind: :discount,
      label: "Discount (#{CartsHelper::WELCOME_DISCOUNT_PERCENTAGE}%)",
      amount: "-#{money(@cart.discount_amount)}",
      negative: true
    }
  end

  # "Free" at/above the free-shipping threshold, the currency amount below it, and
  # "Calculate at checkout" for an empty cart (shipping nil, which never renders the
  # summary).
  def shipping_display
    shipping = @cart.shipping_amount
    return "Calculate at checkout" if shipping.nil?

    shipping.zero? ? "Free" : money(shipping)
  end

  # One money formatter for every cart surface, matching OrderSummary's, so the cart
  # and order surfaces can never drift on currency formatting.
  def money(amount)
    ActiveSupport::NumberHelper.number_to_currency(amount, unit: "£")
  end
end
