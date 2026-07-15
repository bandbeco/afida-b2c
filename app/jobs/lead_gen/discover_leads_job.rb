module LeadGen
  # Weekly lead discovery (see config/recurring.yml and docs/adr/0001).
  #
  # For each register source: fetch the current "recently registered" set,
  # record sightings, and create a Lead for every identity first seen after
  # that source's seed run. Always finishes by sending the digest email, even
  # for 0-new or failed weeks, so the monitor can never fail silently.
  class DiscoverLeadsJob < ApplicationJob
    queue_as :default

    FETCHERS = { "fhrs" => LeadGen::FhrsFetcher }.freeze

    def perform
      sections = FETCHERS.map { |source, fetcher| import_source(source, fetcher) }
      LeadDigestMailer.with(sections: sections).weekly_digest.deliver_later
    end

    private

    def import_source(source, fetcher)
      records = fetcher.fetch
      return failed_section(source) if records.nil?

      records = records.uniq { |record| record[:external_id] }
      seeded = false
      new_ids = []
      new_leads = []

      # One transaction so a crash can't record sightings whose leads were
      # never created; that would silently swallow those leads forever.
      ActiveRecord::Base.transaction do
        seeded = Sighting.where(source: source).none?
        new_ids = Sighting.record_batch(source, records.map { |record| record[:external_id] })
        new_leads = seeded ? [] : create_leads(records, new_ids)
      end

      Rails.logger.info(
        "[LeadGen] #{source}: fetched #{records.size}, #{new_ids.size} newly sighted, " \
        "#{new_leads.size} leads created#{' (seed run)' if seeded}"
      )
      { source: source, failed: false, seeded: seeded, fetched_count: records.size,
        sighted_count: new_ids.size, new_lead_ids: new_leads.map(&:id) }
    rescue StandardError => e
      Rails.logger.error("[LeadGen] #{source} import failed: #{e.class}: #{e.message}")
      failed_section(source)
    end

    def create_leads(records, new_external_ids)
      wanted = new_external_ids.to_set
      records.select { |record| wanted.include?(record[:external_id]) }
             .map { |attributes| Lead.create!(attributes) }
    end

    def failed_section(source)
      { source: source, failed: true }
    end
  end
end
