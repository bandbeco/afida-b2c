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
#   - Shipping shows "Free" / DEFERRED_LABEL (see #shipping_display), not just a
#     currency amount.
#   - the discount line is labelled with the welcome percentage (the cart has no
#     Stripe coupon code yet), not a recorded code.
#   - the Total is the cart's display_total_amount (the sum of the rounded lines, so
#     it reconciles with the lines above it and with the Stripe charge).
# The discount-visibility rule (only when a discount is actually taken) and the
# money format match OrderSummary exactly.
class CartSummary
  # What the Shipping line reads before a destination is known. It names the
  # action the customer can take right there: both cart surfaces now carry the
  # postcode field, so the old "Calculate at checkout" pointed at a later step
  # that no longer holds the answer.
  DEFERRED_LABEL = "Enter postcode"

  def self.lines(cart, placeholder_discount: false)
    new(cart, placeholder_discount: placeholder_discount).lines
  end

  def initialize(cart, placeholder_discount: false)
    @cart = cart
    @placeholder_discount = placeholder_discount
  end

  def lines
    result = [
      line(:subtotal, "Subtotal", money(@cart.subtotal_amount)),
      line(:shipping, "Shipping", shipping_display)
    ]
    if @cart.discount_amount.positive?
      result << discount_line
    elsif @placeholder_discount
      result << placeholder_discount_line
    end
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

  # An empty discount row in the discount line's canonical slot, marked
  # placeholder so the requesting surface renders it hidden. The on-site
  # checkout page asks for it: a promo code applied on-page creates a discount
  # the server never rendered, and the page's JS needs a row to unhide without
  # the view guessing where the discount slot sits. The cart surfaces never
  # pass the option, so their line set is unchanged.
  def placeholder_discount_line
    { kind: :discount, label: "Discount", amount: nil, negative: true, placeholder: true }
  end

  # "Free" at/above the free-shipping threshold, the currency amount below it, and
  # DEFERRED_LABEL whenever the cart defers shipping (shipping nil): an empty
  # cart, or one whose delivery destination we have not been told.
  #
  # The deferral rule itself lives in Cart#cart_totals, not here, so the deferred
  # shipping line and the VAT and Total that exclude it can never disagree. A
  # mainland price is not a quote we can stand behind for an address we haven't
  # been given: mainland is the cheapest zone and the only one with free
  # delivery, so showing it early understates every off-mainland customer's cost.
  def shipping_display
    shipping = @cart.shipping_amount
    return DEFERRED_LABEL if shipping.nil?

    shipping.zero? ? "Free" : money(shipping)
  end

  # One money formatter for every cart surface, matching OrderSummary's, so the cart
  # and order surfaces can never drift on currency formatting.
  def money(amount)
    ActiveSupport::NumberHelper.number_to_currency(amount, unit: "£")
  end
end
