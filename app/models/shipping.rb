# Shipping configuration for checkout
#
# Amounts are in pence/cents (GBP)
# To change shipping costs, update the values below and restart the server

class Shipping
  # Standard shipping option (used for orders < £100 and samples-only orders)
  STANDARD_COST = ENV.fetch("STANDARD_SHIPPING_COST", "699").to_i  # £6.99
  STANDARD_MIN_DAYS = 1
  STANDARD_MAX_DAYS = 1

  # Allowed shipping countries (ISO 3166-1 alpha-2 codes)
  ALLOWED_COUNTRIES = %w[GB].freeze

  # Free shipping threshold in pounds (subtotal excluding VAT)
  FREE_SHIPPING_THRESHOLD = BigDecimal(ENV.fetch("FREE_SHIPPING_THRESHOLD", "100"))

  # Currency
  CURRENCY = "gbp"

  # Get shipping options based on cart subtotal (excluding VAT)
  # - Orders >= £100: Free shipping only
  # - Orders < £100: Standard shipping only
  def self.shipping_options_for_subtotal(subtotal)
    if subtotal >= FREE_SHIPPING_THRESHOLD
      [ free_shipping_option ]
    else
      [ standard_shipping_option ]
    end
  end

  def self.standard_shipping_option
    {
      shipping_rate_data: {
        type: "fixed_amount",
        fixed_amount: {
          amount: STANDARD_COST,
          currency: CURRENCY
        },
        display_name: "Standard Shipping",
        delivery_estimate: {
          minimum: { unit: "business_day", value: STANDARD_MIN_DAYS },
          maximum: { unit: "business_day", value: STANDARD_MAX_DAYS }
        }
      }
    }
  end

  def self.free_shipping_option
    {
      shipping_rate_data: {
        type: "fixed_amount",
        fixed_amount: {
          amount: 0,
          currency: CURRENCY
        },
        display_name: "Free Shipping",
        delivery_estimate: {
          minimum: { unit: "business_day", value: STANDARD_MIN_DAYS },
          maximum: { unit: "business_day", value: STANDARD_MAX_DAYS }
        }
      }
    }
  end

  # Shipping option for samples-only orders (same cost as standard)
  def self.sample_only_shipping_option
    {
      shipping_rate_data: {
        type: "fixed_amount",
        fixed_amount: {
          amount: STANDARD_COST,
          currency: CURRENCY
        },
        display_name: "Standard Shipping",
        delivery_estimate: {
          minimum: { unit: "business_day", value: STANDARD_MIN_DAYS },
          maximum: { unit: "business_day", value: STANDARD_MAX_DAYS }
        }
      }
    }
  end
end
