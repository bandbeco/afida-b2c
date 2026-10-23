# frozen_string_literal: true

# The order's shipping and billing addresses as ordered arrays of display
# lines: the single source of truth for every surface that renders an address
# (storefront order pages, admin order page, ops confirmation email HTML +
# text, and the PDF), mirroring OrderSummary's role for the money lines.
#
# Each line is { kind:, text: }. kind is the one contract surfaces style
# against - :name may be emphasised, :address and :note render plain - so no
# surface infers "the first line is the name" from position: an order whose
# billing name Stripe never returned simply has no :name line, and the
# same-as-delivery note is never mistaken for a name.
#
# billing_lines returns:
#   - [] when the order has no billing address (orders predating billing
#     collection, or a session Stripe returned none for) - render nothing.
#   - the :note line when billing matches the delivery address - render it
#     instead of repeating the block. Matching is judged on the address alone,
#     so a billed company (a billing name that is not the recipient) heads
#     the note.
#   - the full address lines otherwise.
#
# bill_to_lines and deliver_to_lines frame the same data for the invoice,
# which leads with the invoiced party: bill-to is the billing address when it
# differs, else the delivery address under the billing name; deliver-to then
# notes the match, naming the recipient when they are a different person.
class OrderAddress
  SAME_AS_SHIPPING_NOTE = "Same as delivery address"
  SAME_AS_BILLING_NOTE = "Same as billing address"

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
    return same_address_lines(order.billing_name, order.shipping_name, SAME_AS_SHIPPING_NOTE) if order.billing_same_as_shipping?

    lines(
      name: order.billing_name,
      line1: order.billing_address_line1,
      line2: order.billing_address_line2,
      city: order.billing_city,
      postal_code: order.billing_postal_code,
      country: order.billing_country
    )
  end

  def self.bill_to_lines(order)
    if separate_billing?(order)
      billing = billing_lines(order)
      # A VAT invoice must name the customer, and Stripe can return a
      # billing address without a name; the recipient is then the party.
      return billing if billing.any? { |line| line[:kind] == :name }

      return [ { kind: :name, text: order.shipping_name }, *billing ]
    end

    shipping = shipping_lines(order)
    return shipping if order.billing_name.blank?

    [ { kind: :name, text: order.billing_name }, *shipping.reject { |line| line[:kind] == :name } ]
  end

  def self.deliver_to_lines(order)
    return shipping_lines(order) if separate_billing?(order)

    same_address_lines(order.shipping_name, order.billing_name, SAME_AS_BILLING_NOTE)
  end

  def self.separate_billing?(order)
    order.billing_address? && !order.billing_same_as_shipping?
  end

  # The note for a block that repeats the other block's address, headed by
  # this block's name when it names a different person than the other.
  def self.same_address_lines(name, other_name, note_text)
    note = { kind: :note, text: note_text }
    return [ note ] if name.blank? || other_name.blank? || same_person?(name, other_name)

    [ { kind: :name, text: name }, note ]
  end

  # Stripe returns the cardholder as typed on the card ("JANE SMITH"), so
  # case and spacing differences are still one person.
  def self.same_person?(name, other)
    name.squish.casecmp?(other.squish)
  end

  def self.lines(name:, line1:, line2:, city:, postal_code:, country:)
    texts = [
      line1,
      line2.presence,
      [ city, postal_code ].select(&:present?).join(", ").presence,
      country
    ].compact

    address_lines = texts.map { |text| { kind: :address, text: text } }
    name.present? ? [ { kind: :name, text: name }, *address_lines ] : address_lines
  end
  private_class_method :lines, :separate_billing?, :same_address_lines, :same_person?
end
