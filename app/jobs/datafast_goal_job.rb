# frozen_string_literal: true

# Sends DataFast goal events asynchronously via Solid Queue.
# Fire-and-forget: no retries (analytics data loss is acceptable).
class DatafastGoalJob < ApplicationJob
  queue_as :default
  discard_on StandardError

  def perform(goal_name, visitor_id:, metadata: {})
    DatafastService.track(goal_name, visitor_id: visitor_id, metadata: metadata)
  end
end
