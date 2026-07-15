class LeadDigestMailerPreview < ActionMailer::Preview
  def weekly_digest
    ids = Lead.source_fhrs.limit(5).ids
    LeadDigestMailer.with(sections: [
      { source: "fhrs", failed: false, seeded: false,
        fetched_count: 15000, sighted_count: ids.size, new_lead_ids: ids }
    ]).weekly_digest
  end

  def weekly_digest_seeded
    LeadDigestMailer.with(sections: [
      { source: "fhrs", failed: false, seeded: true,
        fetched_count: 15000, sighted_count: 15000, new_lead_ids: [] }
    ]).weekly_digest
  end

  def weekly_digest_failed
    LeadDigestMailer.with(sections: [ { source: "fhrs", failed: true } ]).weekly_digest
  end
end
