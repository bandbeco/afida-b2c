# frozen_string_literal: true

# Currency configuration
#
# Stripe and most payment APIs use minor currency units (pence for GBP, cents for USD).
# This module provides constants and helpers for currency conversion.

module Currency
  # Multiplier to convert major units (pounds/dollars) to minor units (pence/cents)
  # £1.00 = 100 pence, $1.00 = 100 cents
  MINOR_UNIT_MULTIPLIER = 100

  # Convert major units to minor units
  # @param amount [Numeric] Amount in major units (e.g., pounds)
  # @return [Integer] Amount in minor units (e.g., pence)
  def self.to_minor(amount)
    (amount * MINOR_UNIT_MULTIPLIER).to_i
  end

  # Convert minor units to major units
  # @param amount [Numeric] Amount in minor units (e.g., pence)
  # @return [BigDecimal] Amount in major units (e.g., pounds)
  def self.to_major(amount)
    amount / MINOR_UNIT_MULTIPLIER.to_f
  end
end
