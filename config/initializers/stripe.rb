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

# Webhook IP allowlist for defense-in-depth security
# Source: https://stripe.com/files/ips/ips_webhooks.json
# Subscribe to changes: https://groups.google.com/a/lists.stripe.com/g/api-announce
#
# Note: Signature verification is the primary security measure.
# IP allowlisting is an additional layer that may be skipped in development.
#
STRIPE_WEBHOOK_IPS = %w[
  3.18.12.63
  3.130.192.231
  13.235.14.237
  13.235.122.149
  18.211.135.69
  35.154.171.200
  52.15.183.38
  54.88.130.119
  54.88.130.237
  54.187.174.169
  54.187.205.235
  54.187.216.72
].freeze

Rails.configuration.stripe = {
  publishable_key: Rails.application.credentials.dig(:stripe, :publishable_key),
  secret_key: Rails.application.credentials.dig(:stripe, :secret_key),
  api_version: STRIPE_API_VERSION,
  webhook_ips: STRIPE_WEBHOOK_IPS
}

Stripe.api_key = Rails.configuration.stripe[:secret_key]
Stripe.api_version = STRIPE_API_VERSION
