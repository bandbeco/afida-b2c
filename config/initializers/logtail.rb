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
source_token = ENV.fetch("LOGTAIL_SOURCE_TOKEN")
ingesting_host = ENV.fetch("LOGTAIL_INGESTING_HOST")

# Collapse HTTP events into a single log line per request.
# Instead of two verbose events (http_request_received + http_response_sent)
# with full headers, this produces one clean line:
#   "GET /products sent 200 OK in 45ms"
# Keeps useful HTTP metrics without header noise.
Logtail::Integrations::Rack::HTTPEvents.collapse_into_single_event = true

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
