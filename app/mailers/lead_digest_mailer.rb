# Weekly internal digest of newly opened food businesses discovered by
# LeadGen::DiscoverLeadsJob. Always sent, even for 0-new or failed weeks, so
# the monitor can never fail silently (a quiet inbox must mean "no new leads",
# never "broken pipeline").
#
# Sections arrive as plain data (ids, counts, flags) so deliver_later
# serialization stays trivial; leads are hydrated here.
class LeadDigestMailer < ApplicationMailer
  RECIPIENT = "laurent@curau.me".freeze
  TABLE_ROW_CAP = 100

  def weekly_digest
    @sections = params[:sections].map { |section| hydrate(section.to_h.symbolize_keys) }
    @total_new = @sections.sum { |section| section[:new_leads].size }

    @sections.each { |section| attach_leads_csv(section) }

    mail(to: RECIPIENT, subject: subject_line)
  end

  private

  def subject_line
    return "[LeadGen] weekly run FAILED" if @sections.all? { |section| section[:failed] }

    "[LeadGen] #{@total_new} new leads this week"
  end

  def hydrate(section)
    ids = section[:new_lead_ids].presence || []
    leads = ids.any? ? Lead.where(id: ids).order(:business_type, :business_name).to_a : []
    section.merge(new_leads: leads)
  end

  # A CSV failure must never block the digest itself (same stance as
  # OrderMailer#attach_order_pdf).
  def attach_leads_csv(section)
    return if section[:new_leads].empty?

    attachments["#{section[:source]}-new-leads-#{Date.current.iso8601}.csv"] = {
      mime_type: "text/csv",
      content: LeadGen::LeadsCsv.generate(section[:new_leads])
    }
  rescue StandardError => e
    Rails.logger.error("[LeadDigestMailer] Failed to build CSV for #{section[:source]}: #{e.message}")
  end
end
