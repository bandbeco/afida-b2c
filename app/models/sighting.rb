# A business identity observed in an external register (an FHRSID today;
# later possibly a Companies House number). Pure diff state for the LeadGen
# monitor: insert-only, never shown to humans, created_at is "first seen".
# Leads are only created for sightings that first appear AFTER a source's
# seed run (see LeadGen::DiscoverLeadsJob and docs/adr/0001).
class Sighting < ApplicationRecord
  enum :source, { fhrs: "fhrs" }, prefix: true

  validates :source, :external_id, presence: true

  # Records the given [source, external_id] pairs and returns the external_ids
  # that were NOT already known (Postgres RETURNING only yields inserted rows).
  # ON CONFLICT DO NOTHING makes reruns idempotent.
  def self.record_batch(source, external_ids)
    rows = external_ids.uniq.map { |id| { source: source, external_id: id } }
    return [] if rows.empty?

    result = insert_all(rows, unique_by: [ :source, :external_id ],
                              returning: [ :external_id ], record_timestamps: true)
    result.rows.flatten
  end
end
