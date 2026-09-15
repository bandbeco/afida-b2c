module LeadMonitor
  class DeliverDigestsJob < ActiveJob::Base
    queue_as :lead_monitor

    def perform
      unless DigestMailer.perform_deliveries
        Rails.logger.warn("[LeadMonitor] Mail delivery disabled; digests left pending")
        return
      end

      if DigestMailer.recipient.blank?
        Rails.logger.warn("[LeadMonitor] Set LEAD_MONITOR_DIGEST_TO to deliver pending digests")
        return
      end

      Run.pending_notification.find_each do |run|
        deliver(run)
      end
    end

    private

    def deliver(run)
      run.with_lock do
        return if run.notified_at

        DigestMailer.digest(run).deliver_now
        run.update!(notified_at: Time.current)
      end
    rescue StandardError => e
      Rails.logger.error("[LeadMonitor] Digest #{run.id} failed: #{e.class}; left pending")
    end
  end
end
