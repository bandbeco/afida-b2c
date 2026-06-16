# frozen_string_literal: true

# Sends Klaviyo marketing events / profile updates asynchronously via Solid Queue.
#
# Fire-and-forget: no retries. A dropped marketing sync is acceptable (the same
# stance as DatafastGoalJob); it must never block or fail a customer-facing flow.
#
# Operations:
#   perform_later("track", metric:, email:, properties:, value:)
#   perform_later("upsert_profile", email:, first_name:, last_name:, properties:)
class KlaviyoEventJob < ApplicationJob
  queue_as :default
  discard_on StandardError

  def perform(operation, metric: nil, email:, first_name: nil, last_name: nil, properties: {}, value: nil)
    case operation
    when "track"
      KlaviyoService.track(metric, email: email, properties: properties, value: value)
    when "upsert_profile"
      KlaviyoService.upsert_profile(email: email, first_name: first_name, last_name: last_name, properties: properties)
    else
      Rails.logger.info("[Klaviyo] Ignoring unknown job operation '#{operation}'")
    end
  end
end
