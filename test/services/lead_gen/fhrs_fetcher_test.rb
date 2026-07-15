# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

module LeadGen
  class FhrsFetcherTest < ActiveSupport::TestCase
    ENDPOINT = LeadGen::FhrsFetcher::ENDPOINT

    setup do
      # Politeness throttling and 429 backoff must not slow the suite down.
      LeadGen::FhrsFetcher.any_instance.stubs(:sleep)
    end

    def establishment(overrides = {})
      {
        "FHRSID" => 100001,
        "BusinessName" => "Test Cafe",
        "BusinessType" => "Restaurant/Cafe/Canteen",
        "AddressLine1" => "1 High Street",
        "AddressLine2" => "",
        "AddressLine3" => "Testtown",
        "AddressLine4" => "",
        "PostCode" => "TT1 1AA",
        "LocalAuthorityName" => "Testshire",
        "SchemeType" => "FHRS",
        "RatingValue" => "Awaiting Inspection"
      }.merge(overrides)
    end

    # Stubs one page for one business type. Unstubbed types default to empty
    # single pages via stub_remaining_types.
    def stub_fhrs(type_id, establishments:, total_pages: 1, page: 1)
      stub_request(:get, ENDPOINT)
        .with(
          query: hash_including(
            "businessTypeId" => type_id.to_s,
            "ratingKey" => "AwaitingInspection",
            "pageNumber" => page.to_s
          ),
          headers: { "x-api-version" => "2" }
        )
        .to_return(
          status: 200,
          body: {
            "establishments" => establishments,
            "meta" => { "totalPages" => total_pages, "pageNumber" => page }
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    def stub_remaining_types(*except_ids)
      (LeadGen::FhrsFetcher::BUSINESS_TYPE_IDS - except_ids).each do |type_id|
        stub_fhrs(type_id, establishments: [])
      end
    end

    test "normalizes establishments into lead attribute hashes" do
      stub_fhrs(1, establishments: [ establishment ])
      stub_remaining_types(1)

      records = LeadGen::FhrsFetcher.fetch

      assert_equal 1, records.size
      record = records.first
      assert_equal "fhrs", record[:source]
      assert_equal "100001", record[:external_id]
      assert_equal "Test Cafe", record[:business_name]
      assert_equal "Restaurant/Cafe/Canteen", record[:business_type]
      assert_equal "1 High Street, Testtown", record[:address]
      assert_equal "TT1 1AA", record[:postcode]
      assert_equal "Testshire", record[:local_authority]
      assert_equal establishment, record[:payload]
    end

    test "tolerates a missing postcode" do
      stub_fhrs(1, establishments: [ establishment("PostCode" => nil) ])
      stub_remaining_types(1)

      assert_nil LeadGen::FhrsFetcher.fetch.first[:postcode]
    end

    test "skips records without an FHRSID or business name" do
      stub_fhrs(1, establishments: [
        establishment("FHRSID" => nil),
        establishment("BusinessName" => "", "FHRSID" => 100002),
        establishment("FHRSID" => 100003)
      ])
      stub_remaining_types(1)

      records = LeadGen::FhrsFetcher.fetch

      assert_equal [ "100003" ], records.map { |r| r[:external_id] }
    end

    test "queries every configured business type" do
      LeadGen::FhrsFetcher::BUSINESS_TYPE_IDS.each_with_index do |type_id, i|
        stub_fhrs(type_id, establishments: [ establishment("FHRSID" => 200000 + i) ])
      end

      records = LeadGen::FhrsFetcher.fetch

      assert_equal LeadGen::FhrsFetcher::BUSINESS_TYPE_IDS.size, records.size
    end

    test "paginates through totalPages" do
      stub_fhrs(1, establishments: [ establishment("FHRSID" => 300001) ], total_pages: 2, page: 1)
      stub_fhrs(1, establishments: [ establishment("FHRSID" => 300002) ], total_pages: 2, page: 2)
      stub_remaining_types(1)

      records = LeadGen::FhrsFetcher.fetch

      assert_equal [ "300001", "300002" ], records.map { |r| r[:external_id] }.sort
    end

    test "returns nil when any page fails, even mid-pagination" do
      stub_fhrs(1, establishments: [ establishment ], total_pages: 2, page: 1)
      stub_request(:get, ENDPOINT)
        .with(query: hash_including("businessTypeId" => "1", "pageNumber" => "2"))
        .to_return(status: 500)
      stub_remaining_types(1)

      assert_nil LeadGen::FhrsFetcher.fetch
    end

    test "returns nil on a non-200 response" do
      stub_request(:get, ENDPOINT).with(query: hash_including({})).to_return(status: 503)

      assert_nil LeadGen::FhrsFetcher.fetch
    end

    test "returns nil on malformed JSON" do
      stub_request(:get, ENDPOINT).with(query: hash_including({})).to_return(status: 200, body: "not json")

      assert_nil LeadGen::FhrsFetcher.fetch
    end

    test "returns nil on a timeout" do
      stub_request(:get, ENDPOINT).with(query: hash_including({})).to_timeout

      assert_nil LeadGen::FhrsFetcher.fetch
    end

    test "throttles between page requests" do
      LeadGen::FhrsFetcher::BUSINESS_TYPE_IDS.each do |type_id|
        stub_fhrs(type_id, establishments: [])
      end
      LeadGen::FhrsFetcher.any_instance
                          .expects(:sleep)
                          .with(LeadGen::FhrsFetcher::THROTTLE_SECONDS)
                          .times(LeadGen::FhrsFetcher::BUSINESS_TYPE_IDS.size - 1)

      LeadGen::FhrsFetcher.fetch
    end

    test "retries a rate-limited page and succeeds" do
      stub_request(:get, ENDPOINT)
        .with(query: hash_including("businessTypeId" => "1"))
        .to_return(
          { status: 429, headers: { "Retry-After" => "7" } },
          { status: 200,
            body: { "establishments" => [ establishment ], "meta" => { "totalPages" => 1 } }.to_json,
            headers: { "Content-Type" => "application/json" } }
        )
      stub_remaining_types(1)

      records = LeadGen::FhrsFetcher.fetch

      assert_equal [ "100001" ], records.map { |r| r[:external_id] }
    end

    test "gives up after repeated rate limiting" do
      stub_request(:get, ENDPOINT)
        .with(query: hash_including("businessTypeId" => "1"))
        .to_return(status: 429)
      stub_remaining_types(1)

      assert_nil LeadGen::FhrsFetcher.fetch
    end
  end
end
