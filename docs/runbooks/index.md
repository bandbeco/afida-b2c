# Runbooks

Operational knowledge for running and maintaining the Afida shop: procedures and hard-won gotchas that the code cannot show.

# Operations

* [Deploying to Production](/runbooks/deploying.md) - Why plain kamal deploy silently fails and how to boot by version and verify the served HTML.
* [Rails Credentials](/runbooks/credentials.md) - The shared production vault, how to edit it safely, and how test credentials behave in CI.

# Integrations

* [Stripe Checkout Gotchas](/runbooks/stripe-checkout.md) - Zero-total payment status, line_items pagination, and welcome coupon application.
* [Datafast Tracking Architecture](/runbooks/datafast-tracking.md) - App-owned visitor id, purchase goal routing, the pageview gate, and API key scopes.
