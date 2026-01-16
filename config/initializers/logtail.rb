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

source_token = Rails.application.credentials.dig(:logtail, :source_token)

if source_token.present?
  # Configure Logtail with the source token
  # The logtail-rails gem automatically integrates with Rails.logger
  Logtail.configure do |config|
    config.api_key = source_token
  end

  # Create the Logtail logger and set it as the Rails logger
  # This ensures all logs (including our structured events) go to Logtail
  Rails.logger = Logtail::Logger.create_default_logger(source_token)
end
