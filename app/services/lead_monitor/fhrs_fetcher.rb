require "http"

module LeadMonitor
  # A complete snapshot of the target AwaitingInspection pool, not the full register.
  # No writes, no interpretation of opening dates. Any incomplete page fails closed.
  class FhrsFetcher
    ENDPOINT = "https://api.ratings.food.gov.uk/Establishments"
    BUSINESS_TYPE_IDS = [ 1, 7843, 7844, 7846 ].freeze
    PAGE_SIZE = 5000
    MAX_PAGES = 1000
    FetchFailed = Class.new(StandardError)

    def fetch
      BUSINESS_TYPE_IDS.flat_map { |type| fetch_type(type) }.uniq { |record| record[:external_id] }
    rescue HTTP::Error, JSON::ParserError, KeyError, TypeError, NoMethodError => e
      raise FetchFailed, "Invalid FHRS snapshot (#{e.class})"
    end

    private

    def fetch_type(type)
      records = []
      expected = nil
      page_number = 1
      loop do
        body = get_page(type, page_number)
        meta = body.fetch("meta")
        pages = meta.fetch("totalPages")
        count = meta.fetch("totalCount")
        entries = body.fetch("establishments")
        unless pages.is_a?(Integer) && pages.between?(0, MAX_PAGES) &&
            count.is_a?(Integer) && count >= 0 && (count.zero? || pages.positive?) && entries.is_a?(Array) &&
            meta.fetch("currentPage") == page_number
          raise FetchFailed, "Invalid pagination for type #{type}"
        end
        expected ||= [ pages, count ]
        raise FetchFailed, "Snapshot changed during pagination" unless expected == [ pages, count ]
        raise FetchFailed, "Empty page in nonempty snapshot" if entries.empty? && count.positive?
        records.concat(entries.map { |entry| normalize(entry) })
        break if page_number >= pages

        page_number += 1
      end
      unless records.size == expected.last && records.map { |row| row[:external_id] }.uniq.size == records.size
        raise FetchFailed, "Snapshot count mismatch or duplicate identities"
      end
      records
    end

    def get_page(type, page)
      backoffs = [ 10, 30 ]
      loop do
        sleep(1) if @requested_before
        @requested_before = true
        response = HTTP.headers("x-api-version" => "2").timeout(30).get(ENDPOINT, params: {
          businessTypeId: type, ratingKey: "AwaitingInspection", pageSize: PAGE_SIZE, pageNumber: page
        })
        return JSON.parse(response.body.to_s) if response.status.success?

        raise FetchFailed, "FHRS status #{response.status.code}, type #{type}, page #{page}" unless response.status.code == 429 && backoffs.any?

        delay = backoffs.shift
        retry_after = response.headers["Retry-After"].to_s
        delay = [ retry_after.to_i, 60 ].min if retry_after.match?(/\A\d+\z/)
        sleep(delay)
      end
    end

    def normalize(entry)
      unless entry.is_a?(Hash) && entry["FHRSID"].to_s.match?(/\A[1-9]\d*\z/) && entry["BusinessName"].is_a?(String) && entry["BusinessName"].present?
        raise FetchFailed, "Invalid establishment identity or name"
      end
      {
        source: "fhrs", external_id: entry.fetch("FHRSID").to_s, business_name: entry.fetch("BusinessName"),
        business_type: entry["BusinessType"],
        address: entry.values_at("AddressLine1", "AddressLine2", "AddressLine3", "AddressLine4").compact_blank.join(", "),
        postcode: entry["PostCode"], local_authority: entry["LocalAuthorityName"], payload: entry
      }
    end
  end
end
