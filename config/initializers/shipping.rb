# Shipping configuration for checkout
#
# Amounts are in pence/cents (GBP)
# To change shipping costs, update the values below and restart the server

module Shipping
  # Standard shipping option
  STANDARD_COST = ENV.fetch("STANDARD_SHIPPING_COST", "500").to_i  # £5.00
  STANDARD_MIN_DAYS = 2
  STANDARD_MAX_DAYS = 3

  # Express shipping option
  EXPRESS_COST = ENV.fetch("EXPRESS_SHIPPING_COST", "1000").to_i   # £10.00
  EXPRESS_MIN_DAYS = 1
  EXPRESS_MAX_DAYS = 2

  # Sample delivery option (for samples-only orders)
  SAMPLE_COST = ENV.fetch("SAMPLE_SHIPPING_COST", "750").to_i  # £7.50
  SAMPLE_MIN_DAYS = 3
  SAMPLE_MAX_DAYS = 5

  # Allowed shipping countries (ISO 3166-1 alpha-2 codes)
  ALLOWED_COUNTRIES = %w[GB].freeze

  # Free shipping threshold (in pence)
  FREE_SHIPPING_THRESHOLD = ENV.fetch("FREE_SHIPPING_THRESHOLD", nil)&.to_i

  # Currency
  CURRENCY = "gbp"

  # Helper method to get shipping options for Stripe
  def self.stripe_shipping_options
    options = [
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
      },
      {
        shipping_rate_data: {
          type: "fixed_amount",
          fixed_amount: {
            amount: EXPRESS_COST,
            currency: CURRENCY
          },
          display_name: "Express Shipping",
          delivery_estimate: {
            minimum: { unit: "business_day", value: EXPRESS_MIN_DAYS },
            maximum: { unit: "business_day", value: EXPRESS_MAX_DAYS }
          }
        }
      }
    ]

    # Add free shipping option if threshold is set and order qualifies
    # (This would need to be conditional based on cart total in the controller)
    # if FREE_SHIPPING_THRESHOLD && cart_total >= FREE_SHIPPING_THRESHOLD
    #   options.unshift(free_shipping_option)
    # end

    options
  end

  def self.free_shipping_option
    {
      shipping_rate_data: {
        type: "fixed_amount",
        fixed_amount: {
          amount: 0,
          currency: CURRENCY
        },
        display_name: "Free Shipping"
      }
    }
  end

  # Shipping option for samples-only orders
  def self.sample_only_shipping_option
    {
      shipping_rate_data: {
        type: "fixed_amount",
        fixed_amount: {
          amount: SAMPLE_COST,
          currency: CURRENCY
        },
        display_name: "Sample Delivery",
        delivery_estimate: {
          minimum: { unit: "business_day", value: SAMPLE_MIN_DAYS },
          maximum: { unit: "business_day", value: SAMPLE_MAX_DAYS }
        }
      }
    }
  end
end
