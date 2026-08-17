# frozen_string_literal: true

# The order's shipping and billing addresses as ordered arrays of display
# lines: the single source of truth for every surface that renders an address
# (storefront order pages, admin order page, ops confirmation email HTML +
# text, and the PDF), mirroring OrderSummary's role for the money lines. Each
# surface only supplies medium-specific markup and iterates these lines; the
# name always comes first so a surface may emphasise it.
#
# billing_lines returns:
#   - [] when the order has no billing address (orders predating billing
#     collection, or a session Stripe returned none for) - render nothing.
#   - [SAME_AS_SHIPPING_NOTE] when billing matches the delivery address -
#     render the single note instead of repeating the block.
#   - the full address lines otherwise.
class OrderAddress
  SAME_AS_SHIPPING_NOTE = "Same as delivery address"

  def self.shipping_lines(order)
    lines(
      name: order.shipping_name,
      line1: order.shipping_address_line1,
      line2: order.shipping_address_line2,
      city: order.shipping_city,
      postal_code: order.shipping_postal_code,
      country: order.shipping_country
    )
  end

  def self.billing_lines(order)
    return [] unless order.billing_address?
    return [ SAME_AS_SHIPPING_NOTE ] if order.billing_same_as_shipping?

    lines(
      name: order.billing_name,
      line1: order.billing_address_line1,
      line2: order.billing_address_line2,
      city: order.billing_city,
      postal_code: order.billing_postal_code,
      country: order.billing_country
    )
  end

  def self.lines(name:, line1:, line2:, city:, postal_code:, country:)
    [
      name,
      line1,
      line2.presence,
      [ city, postal_code ].select(&:present?).join(", ").presence,
      country
    ].compact
  end
  private_class_method :lines
end
