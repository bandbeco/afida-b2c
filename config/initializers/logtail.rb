# frozen_string_literal: true

# Configure Logtail (Better Stack) for structured log aggregation
# See: https://betterstack.com/docs/logs/ruby-and-rails/
#
# Events emitted via Rails.event are formatted by EventLogSubscriber
# and sent to Logtail for querying.
#
# Query examples in Logtail:
#   event:order.placed
#   payload.email:customer@example.com
#   context.request_id:abc-123

# Support both ENV vars (Kamal) and credentials (local dev)
# Use ENV[] instead of fetch to allow build-time asset precompilation without these vars
source_token = ENV["LOGTAIL_SOURCE_TOKEN"]
ingesting_host = ENV["LOGTAIL_INGESTING_HOST"]

return unless source_token.present? && ingesting_host.present?

# Silence verbose per-request framework logging to reduce log volume.
# This suppresses individual ActionView (template render), ActiveRecord (SQL),
# and ActionController log lines. The collapsed HTTP event below still gives us
# one summary line per request ("GET /products sent 200 OK in 45ms").
# Our business events (order.placed, checkout.*, etc.) are unaffected.
Logtail::Config.instance.logrageify!

# Filter sensitive HTTP headers from logs
Logtail::Integrations::Rack::HTTPEvents.http_header_filters = %w[
  authorization
  cookie
  set-cookie
  x-csrf-token
]

# Create the Logtail logger and set it as the Rails logger
# This ensures all logs (including our structured events) go to Logtail
# The ingesting_host is required for Docker/Kamal deployments
Rails.logger = Logtail::Logger.create_default_logger(
  source_token,
  ingesting_host: ingesting_host
)
