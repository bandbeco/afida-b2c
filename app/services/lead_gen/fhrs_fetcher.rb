# frozen_string_literal: true

require "http"

module LeadGen
  # Fetches every establishment currently "awaiting inspection" (i.e. recently
  # registered with its local authority) from the FSA Food Hygiene Rating
  # Scheme API, for the business types Afida targets.
  #
  # Returns an array of normalized Lead attribute hashes, or nil on ANY
  # failure. All-or-nothing on purpose: a partial result on the seed run would
  # leak thousands of old register entries as fake "new" leads over the
  # following weeks (see docs/adr/0001). It never raises and never writes;
  # persistence is the caller's job (see LeadGen::DiscoverLeadsJob).
  #
  # API reference: https://api.ratings.food.gov.uk (header x-api-version: 2,
  # no key required; pageSize is capped server-side at 5000).
  class FhrsFetcher
    ENDPOINT = "https://api.ratings.food.gov.uk/Establishments"
    # 1 Restaurant/Cafe/Canteen, 7843 Pub/bar/nightclub,
    # 7844 Takeaway/sandwich shop, 7846 Mobile caterer.
    # 7841 "Other catering premises" is deliberately excluded for volume
    # control (home caterers, institutions, contract caterers).
    BUSINESS_TYPE_IDS = [ 1, 7843, 7844, 7846 ].freeze
    PAGE_SIZE = 5000
    TIMEOUT_SECONDS = 30
    HEADERS = { "x-api-version" => "2" }.freeze
    # The API 429s when large pages are requested back-to-back (seen live
    # 2026-07-15), so pause between requests and back off on a rate limit.
    THROTTLE_SECONDS = 1
    RATE_LIMIT_BACKOFFS_SECONDS = [ 10, 30 ].freeze

    FetchFailed = Class.new(StandardError)
    private_constant :FetchFailed

    class << self
      # @return [Array<Hash>, nil] normalized lead attribute hashes, or nil on failure
      def fetch
        new.fetch
      end
    end

    def fetch
      BUSINESS_TYPE_IDS.flat_map { |type_id| fetch_business_type(type_id) }
    rescue FetchFailed, HTTP::Error, JSON::ParserError => e
      log_failure("#{e.class}: #{e.message}")
    end

    private

    def fetch_business_type(type_id)
      records = []
      page = 1
      loop do
        body = get_page(type_id, page)
        records.concat(body.fetch("establishments", []).filter_map { |e| normalize(e) })
        break if page >= body.dig("meta", "totalPages").to_i

        page += 1
      end
      records
    end

    def get_page(type_id, page)
      backoffs = RATE_LIMIT_BACKOFFS_SECONDS.dup
      loop do
        throttle
        response = HTTP.headers(HEADERS).timeout(TIMEOUT_SECONDS).get(ENDPOINT, params: {
          businessTypeId: type_id,
          ratingKey: "AwaitingInspection",
          pageSize: PAGE_SIZE,
          pageNumber: page
        })
        return JSON.parse(response.body.to_s) if response.status.success?

        unless response.status.code == 429 && backoffs.any?
          raise FetchFailed, "status #{response.status} for type #{type_id} page #{page}"
        end

        # Always consume a backoff so retries stay bounded even when the
        # server keeps sending Retry-After.
        backoff = backoffs.shift
        sleep(retry_after(response) || backoff)
      end
    end

    def throttle
      sleep(THROTTLE_SECONDS) if @requested_before
      @requested_before = true
    end

    def retry_after(response)
      seconds = response.headers["Retry-After"].to_s
      seconds.match?(/\A\d+\z/) ? seconds.to_i : nil
    end

    def normalize(establishment)
      return nil if establishment["FHRSID"].blank? || establishment["BusinessName"].blank?

      {
        source: "fhrs",
        external_id: establishment["FHRSID"].to_s,
        business_name: establishment["BusinessName"],
        business_type: establishment["BusinessType"],
        address: establishment.values_at("AddressLine1", "AddressLine2", "AddressLine3", "AddressLine4")
                              .compact_blank.join(", "),
        postcode: establishment["PostCode"].presence,
        local_authority: establishment["LocalAuthorityName"],
        payload: establishment
      }
    end

    def log_failure(message)
      Rails.logger.warn("[LeadGen::FhrsFetcher] #{message}")
      nil
    end
  end
end
