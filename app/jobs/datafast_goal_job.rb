# frozen_string_literal: true

# Background job for tracking DataFast goals.
#
# Wraps DatafastService in an async job to avoid blocking user requests.
# Failed API calls are retried with exponential backoff.
#
# Usage:
#   DatafastGoalJob.perform_later("add_to_cart", visitor_id: "abc123", metadata: { product_id: 1 })
#
class DatafastGoalJob < ApplicationJob
  queue_as :default

  # Retry transient failures with exponential backoff: ~3s, ~18s, ~83s
  retry_on HTTP::Error, HTTP::TimeoutError, wait: :polynomially_longer, attempts: 3

  # Discard permanent failures after logging
  discard_on StandardError do |job, error|
    Rails.logger.error("[DataFast] Job permanently failed for goal '#{job.arguments.first}': #{error.message}")
  end

  # @param name [String] Goal name (e.g., "add_to_cart", "purchase")
  # @param visitor_id [String] DataFast visitor ID from cookie
  # @param metadata [Hash] Optional metadata
  def perform(name, visitor_id:, metadata: {})
    success = DatafastService.track(name, visitor_id: visitor_id, metadata: metadata)

    # Emit tracking event for observability in Logtail
    Rails.event.notify("datafast.goal_tracked",
      name: name,
      success: success,
      visitor_id_present: visitor_id.present?
    )
  end
end
