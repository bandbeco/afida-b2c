# frozen_string_literal: true

require "csv"

module LeadGen
  # Renders leads as CSV bytes for the weekly digest attachment.
  # Generation only; attaching (and surviving a generation failure) is
  # LeadDigestMailer's job, mirroring the OrderPdfGenerator/OrderMailer split.
  class LeadsCsv
    HEADERS = %w[source external_id business_name business_type address postcode local_authority first_seen].freeze

    def self.generate(leads)
      CSV.generate do |csv|
        csv << HEADERS
        leads.each do |lead|
          csv << [
            lead.source,
            lead.external_id,
            lead.business_name,
            lead.business_type,
            lead.address,
            lead.postcode,
            lead.local_authority,
            lead.created_at.to_date.iso8601
          ]
        end
      end
    end
  end
end
