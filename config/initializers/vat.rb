# VAT (Value Added Tax) configuration
#
# UK VAT rate is 20% as of 2024
# This constant is used throughout the application for tax calculations
#
# Usage:
#   VAT_RATE                    # => 0.2 (20%)
#   amount * VAT_RATE           # Calculate VAT on an amount
#   amount * (1 + VAT_RATE)     # Calculate total with VAT included
#
# To change VAT rate:
# 1. Update this constant
# 2. Restart the application
# 3. Consider how this affects existing orders (they use captured amounts)
#
VAT_RATE = 0.2
# The rate as printed ("VAT (20%)"), derived so labels never drift from VAT_RATE.
VAT_RATE_PERCENT = (VAT_RATE * 100).round
