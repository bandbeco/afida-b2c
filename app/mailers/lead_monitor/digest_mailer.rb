module LeadMonitor
  class DigestMailer < ActionMailer::Base
    default from: "Afida <hello@afida.com>"

    def self.recipient
      ENV["LEAD_MONITOR_DIGEST_TO"].presence
    end

    def digest(run)
      lines = [ "Lead monitor run ##{run.id}: #{run.source} #{run.status}",
        "Fetched: #{run.fetched_count}; new candidates: #{run.new_count}.",
        "First seen in the register is not proof of a new opening. Review opening evidence before outreach." ]
      lines << "Import failed: #{run.error}. No partial snapshot was imported." if run.status == "failed"
      lines << "Initial baseline recorded. No prospects created." if run.status == "seeded"
      run.leads.order(:id).limit(50).each do |lead|
        lines << "#{lead.business_name} — #{lead.postcode} — #{Lead::CLASSIFICATIONS.fetch(lead.classification)}"
      end
      lines << "Review all candidates: #{lead_monitor_leads_url}"
      mail(to: self.class.recipient, subject: "Lead monitor ##{run.id}: #{run.status}, #{run.new_count} candidates") do |format|
        format.text { render plain: lines.join("\n\n") }
      end
      # Action Mailer's setting is shared across subclasses. Override only
      # this message so failed digests stay pending without changing shop mail.
      mail.raise_delivery_errors = true
    end
  end
end
