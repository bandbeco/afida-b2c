module LeadMonitor
  class DiscoverJob < ActiveJob::Base
    queue_as :lead_monitor

    def perform
      Discover.new.call
      DeliverDigestsJob.perform_later
    end
  end
end
