module LeadMonitor
  class Discover
    SOURCE_FIELDS = %i[external_id business_name business_type address postcode local_authority payload].freeze

    def initialize(source: "fhrs", fetcher: FhrsFetcher.new(source: source))
      @source = source
      @fetcher = fetcher
    end

    def call
      state = Source.create_or_find_by!(name: @source)
      records = @fetcher.fetch.uniq { |record| record.fetch(:external_id) }
      state.with_lock(requires_new: true) do
        seeded = state.seeded_at.nil?
        run = Run.create!(source: @source, status: seeded ? "seeded" : "completed", fetched_count: records.size)
        known = Sighting.where(source: @source, external_id: records.map { |row| row.fetch(:external_id) }).pluck(:external_id).to_set
        new_records = records.reject { |row| known.include?(row.fetch(:external_id)) }
        unless new_records.empty?
          Sighting.insert_all!(new_records.map { |row| { source: @source, external_id: row.fetch(:external_id), created_at: Time.current } })
          unless seeded
            new_records.each { |row| Lead.create!(row.slice(*SOURCE_FIELDS).merge(source: @source, run: run)) }
            run.update!(new_count: new_records.size)
          end
        end
        state.update!(seeded_at: Time.current) if seeded
        run
      end
    rescue StandardError => e
      Rails.logger.error("[LeadMonitor] #{@source} import failed: #{e.class}: #{e.message}")
      Sentry.capture_exception(e)
      Run.create!(source: @source, status: "failed", error: "#{e.class}: #{e.message}")
    end
  end
end
