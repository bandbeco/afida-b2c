# An actionable prospect: a newly opened food business a human might contact.
# Created by LeadGen::DiscoverLeadsJob only when a Sighting first appears
# after its source's seed run, so this table never contains register backfill.
# payload holds the raw register record for future re-segmentation.
class Lead < ApplicationRecord
  enum :source, { fhrs: "fhrs" }, prefix: true
  enum :status, { new_lead: "new_lead", contacted: "contacted",
                  converted: "converted", dismissed: "dismissed" }, validate: true

  validates :source, :external_id, :business_name, presence: true
  validates :external_id, uniqueness: { scope: :source }

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
end
