# Stripe API configuration
#
# Pin the API version to ensure consistent behavior across deployments.
# When upgrading, review the changelog: https://docs.stripe.com/changelog
#
# Current version pinned to match stripe-ruby gem v17.x release.
# Webhooks use the version set in Stripe Dashboard, which should match.
#
STRIPE_API_VERSION = "2025-04-30.basil"

Rails.configuration.stripe = {
  publishable_key: Rails.application.credentials.dig(:stripe, :publishable_key),
  secret_key: Rails.application.credentials.dig(:stripe, :secret_key),
  api_version: STRIPE_API_VERSION
}

Stripe.api_key = Rails.configuration.stripe[:secret_key]
Stripe.api_version = STRIPE_API_VERSION
