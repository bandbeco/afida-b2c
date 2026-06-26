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

  # A Stripe Checkout line item for the standard shipping charge, carrying the UK
  # VAT tax rate. Shipping is a line item (not a shipping_option) because manual
  # tax rates only tax line items, so this is what makes Stripe apply VAT to the
  # delivery charge. The product metadata lets SessionAmounts find this line when
  # splitting the persisted order amounts back out.
  #
  # The free-shipping / samples decision lives with the caller (SessionBuilder),
  # which knows the cart; this builder always charges STANDARD_COST.
  def self.shipping_line_item(tax_rate_id:)
    {
      quantity: 1,
      price_data: {
        currency: CURRENCY,
        unit_amount: STANDARD_COST,
        tax_behavior: "exclusive",
        product_data: {
          # Line items can't carry a delivery_estimate the way the old
          # shipping_options did, so the next-working-day promise rides in the
          # name to keep it visible in the Stripe Checkout modal.
          name: "Shipping (next working day)",
          metadata: LINE_ITEM_FLAG
        }
      },
      tax_rates: [ tax_rate_id ]
    }
  end
end
