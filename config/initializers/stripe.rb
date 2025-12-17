Rails.configuration.stripe = {
  publishable_key: Rails.application.credentials.dig(:stripe, :publishable_key),
  secret_key: Rails.application.credentials.dig(:stripe, :secret_key)
}

Stripe.api_key = Rails.configuration.stripe[:secret_key]

# Use Clover API version - requires collected_information.shipping_details
# (shipping_details moved from top-level in basil release 2025-03-31)
Stripe.api_version = "2025-12-15.clover"

# Validate API version compatibility at boot time.
# The checkout flow depends on collected_information.shipping_details which
# requires Stripe API version 2025-03-31 (basil) or later.
MINIMUM_STRIPE_API_VERSION = "2025-03-31"
api_version_date = Stripe.api_version.split(".").first
if api_version_date < MINIMUM_STRIPE_API_VERSION
  raise <<~ERROR
    Stripe API version #{Stripe.api_version} is not supported.
    Minimum required version: #{MINIMUM_STRIPE_API_VERSION} (basil release)
    The checkout flow requires collected_information.shipping_details which was
    introduced in the basil release. Please update Stripe.api_version.
  ERROR
end
