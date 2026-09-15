require "csv"

module LeadMonitor
  class LeadsCsv
    def self.generate(leads)
      CSV.generate do |csv|
        csv << [ "Source", "External ID", "Business", "Address", "Postcode", "Classification", "Opening date",
          "Opening eligible", "Evidence kind", "Evidence URL", "Evidence notes", "Reviewer", "Checked at",
          "Contact name", "Email", "Phone", "Website", "Outreach status" ]
        leads.find_each do |lead|
          csv << [ lead.source, lead.external_id, lead.business_name, lead.address, lead.postcode, lead.classification,
            lead.opening_on, lead.opening_eligible?, lead.evidence_kind, lead.evidence_url, lead.evidence_notes,
            lead.reviewed_by, lead.reviewed_at, lead.contact_name, lead.contact_email, lead.contact_phone,
            lead.website, lead.outreach_status ].map { |value| safe_cell(value) }
        end
      end
    end

    def self.safe_cell(value)
      text = value.to_s
      text.match?(/\A[\s\u0000-\u001f]*[=+@-]/) || text.match?(/\A[\t\r\n]/) ? "'#{text}" : text
    end
    private_class_method :safe_cell
  end
end
