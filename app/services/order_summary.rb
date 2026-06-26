# frozen_string_literal: true

# The order-totals summary as an ordered list of display lines: the single source
# of truth for what every order surface renders. Used by:
#   - the storefront order pages (orders/show, orders/confirmation) via OrdersHelper
#   - the admin order page via OrdersHelper
#   - the customer and ops confirmation emails (HTML + text) via OrdersHelper
#   - the order PDF (OrderPdfGenerator), which calls this directly
#
# Centralising it means the line order, labels, money formatting and the
# discount-visibility rule are defined once; each surface only supplies
# medium-specific markup (Tailwind, email-safe HTML, plain text, Prawn) and
# iterates these lines.
#
# Order matches the cart summary: Subtotal -> Shipping -> Discount -> VAT ->
# Total, so the discount visibly applies to subtotal + shipping (the welcome
# coupon is whole-order). The discount line is included only when a discount was
# actually taken (amount positive), carries the code in its label when present,
# and is the only line flagged negative (rendered as -£x).
#
# Each line is a Hash: { kind:, label:, amount:, negative: }. kind (a Symbol
# :subtotal/:shipping/:discount/:vat/:total) lets markup style or emphasise a
# line without parsing its label; amount is a GBP-formatted String.
class OrderSummary
  def self.lines(order)
    new(order).lines
  end

  def initialize(order)
    @order = order
  end

  def lines
    result = [
      line(:subtotal, "Subtotal", @order.subtotal_amount),
      line(:shipping, "Shipping", @order.shipping_amount)
    ]
    result << discount_line if @order.discount_amount.positive?
    result << line(:vat, "VAT (20%)", @order.vat_amount)
    result << line(:total, "Total", @order.total_amount)
    result
  end

  private

  def line(kind, label, amount)
    { kind: kind, label: label, amount: money(amount), negative: false }
  end

  def discount_line
    {
      kind: :discount,
      label: discount_label,
      amount: "-#{money(@order.discount_amount)}",
      negative: true
    }
  end

  # "Discount (WELCOME10)" when a code is recorded, otherwise plain "Discount".
  def discount_label
    return "Discount" if @order.discount_code.blank?

    "Discount (#{@order.discount_code})"
  end

  # One money formatter for every order surface (matches the PDF's, verified
  # identical), so the surfaces can never drift on currency formatting.
  def money(amount)
    ActiveSupport::NumberHelper.number_to_currency(amount, unit: "£")
  end
end
