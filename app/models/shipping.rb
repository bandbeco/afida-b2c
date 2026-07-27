# Shipping configuration for checkout
#
# Amounts are in pence/cents (GBP)
# To change shipping costs, update the values below and restart the server

class Shipping
  # Standard shipping cost (charged for orders < £100 and samples-only orders)
  STANDARD_COST = ENV.fetch("STANDARD_SHIPPING_COST", "699").to_i  # £6.99

  # Allowed shipping countries (ISO 3166-1 alpha-2 codes)
  ALLOWED_COUNTRIES = %w[GB].freeze

  # Free shipping threshold in pounds (subtotal excluding VAT)
  FREE_SHIPPING_THRESHOLD = BigDecimal(ENV.fetch("FREE_SHIPPING_THRESHOLD", "100"))

  # Currency
  CURRENCY = "gbp"

  # Product metadata flag set on the shipping line item so the completed session
  # can identify it on read-back (SessionAmounts) regardless of display name.
  # The key/value are exposed so the reader can reference them instead of
  # re-declaring the literal string, which would silently desync on a rename.
  LINE_ITEM_FLAG_KEY = "shipping_line"
  LINE_ITEM_FLAG_VALUE = "true"
  # String key (Stripe serialises it as a string on the wire either way) so the
  # in-memory hash matches how SessionAmounts reads it back: LINE_ITEM_FLAG[KEY].
  LINE_ITEM_FLAG = { LINE_ITEM_FLAG_KEY => LINE_ITEM_FLAG_VALUE }.freeze

  # Standard shipping cost in pounds, e.g. 6.99. Single conversion point from
  # the pence-denominated STANDARD_COST so display code never repeats the maths.
  def self.standard_cost_in_pounds
    STANDARD_COST / 100.0
  end

  # Standard shipping cost formatted as a GBP string, e.g. "£6.99".
  def self.formatted_standard_cost
    ActiveSupport::NumberHelper.number_to_currency(standard_cost_in_pounds, unit: "£")
  end

  # Free-shipping threshold formatted as a whole-pound GBP string, e.g. "£100".
  # The threshold is always a round figure, so no decimals.
  def self.formatted_free_shipping_threshold
    ActiveSupport::NumberHelper.number_to_currency(FREE_SHIPPING_THRESHOLD, unit: "£", precision: 0)
  end

  # A Stripe Checkout line item for the shipping charge, carrying the UK VAT tax
  # rate. Shipping is a line item (not a shipping_option) because manual tax
  # rates only tax line items, so this is what makes Stripe apply VAT to the
  # delivery charge. The product metadata lets SessionAmounts find this line when
  # splitting the persisted order amounts back out.
  #
  # The free-shipping / samples decision lives with the caller (SessionBuilder),
  # which knows the cart; this builder always charges.
  #
  # zone is the ShippingZone the order is going to. It adds that zone's surcharge
  # and names its real transit time, so a non-mainland order is neither priced
  # nor promised as if it were local. It defaults to mainland for callers that
  # have not captured a destination postcode.
  def self.shipping_line_item(tax_rate_id:, zone: :mainland)
    {
      quantity: 1,
      price_data: {
        currency: CURRENCY,
        unit_amount: cost_for_zone(zone),
        tax_behavior: "exclusive",
        product_data: {
          # Line items can't carry a delivery_estimate the way the old
          # shipping_options did, so the delivery promise rides in the name to
          # keep it visible in the Stripe Checkout modal.
          name: "Shipping (#{ShippingZone.transit_label(zone)})",
          metadata: LINE_ITEM_FLAG
        }
      },
      tax_rates: [ tax_rate_id ]
    }
  end

  # The delivery charge to a zone, in pence.
  #
  # Off-mainland zones declare their own flat charge, which REPLACES the standard
  # cost rather than adding to it (£25 off-mainland is the total the customer
  # pays, not a surcharge on top of £6.99). Zones with no charge of their own,
  # mainland included, fall through to STANDARD_COST. Rounded rather than
  # truncated so a rate like 25.50 can never lose a penny to representation.
  def self.cost_for_zone(zone)
    zone_cost = ShippingZone.delivery_cost(zone)
    return STANDARD_COST unless zone_cost

    (zone_cost * 100).round.to_i
  end

  # The delivery charge to a zone in pounds, for display and for OrderTotals.
  def self.cost_for_zone_in_pounds(zone)
    BigDecimal(cost_for_zone(zone).to_s) / 100
  end
end
