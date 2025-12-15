# Stripe API configuration
#
# Pin the API version to ensure consistent behavior across deployments.
# When upgrading, review the changelog: https://docs.stripe.com/changelog
#
# Current version: 2025-11-17.clover (latest major release)
# Breaking changes reviewed:
#   - Subscription billing mode now defaults to flexible (no impact - we use Checkout)
#   - Discounts use 'source' instead of 'coupon' (no impact - we don't use coupons)
#   - currency_conversion removed from Checkout Sessions (no impact - we don't use it)
#   - redirectToCheckout removed from Stripe.js (no impact - we redirect server-side)
#
# Webhooks use the version set in Stripe Dashboard, which should match.
#
STRIPE_API_VERSION = "2025-11-17.clover"

Rails.configuration.stripe = {
  publishable_key: Rails.application.credentials.dig(:stripe, :publishable_key),
  secret_key: Rails.application.credentials.dig(:stripe, :secret_key),
  api_version: STRIPE_API_VERSION
}

Stripe.api_key = Rails.configuration.stripe[:secret_key]
Stripe.api_version = STRIPE_API_VERSION
