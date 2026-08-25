# frozen_string_literal: true

# Reports AI crawler visits to DataFast asynchronously via Solid Queue.
# Fire-and-forget: no retries (analytics data loss is acceptable).
class DatafastBotTrafficJob < ApplicationJob
  queue_as :default
  discard_on StandardError

  def perform(href:, user_agent:, ip:, status_code:)
    DatafastBotTrafficService.track(href: href, user_agent: user_agent, ip: ip, status_code: status_code)
  end
end
