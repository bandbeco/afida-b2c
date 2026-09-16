require "test_helper"
require "webmock/minitest"

class LeadMonitor::FhrsFetcherTest < ActiveSupport::TestCase
  def setup
    @fetcher = LeadMonitor::FhrsFetcher.new
    @fetcher.stubs(:sleep)
  end

  def page(records = [], number: 1, pages: 1, count: records.length)
    { establishments: records, meta: { pageNumber: number, totalPages: pages, totalCount: count } }
  end

  def establishment(id = 1)
    { FHRSID: id, BusinessName: "Café", AddressLine1: "1 High Street", PostCode: "SW1A 1AA" }
  end

  def stub_types(body)
    stub_request(:get, LeadMonitor::FhrsFetcher::ENDPOINT).with(query: hash_including("ratingKey" => "AwaitingInspection"))
      .to_return(body: body.to_json)
  end

  test "normalizes a complete snapshot without writing to the database" do
    stub_types(page([ establishment ]))
    assert_no_difference "LeadMonitor::Sighting.count" do
      records = @fetcher.fetch
      assert_equal "1", records.first[:external_id]
      assert_equal "1 High Street", records.first[:address]
      assert_equal "fhrs", records.first[:source]
    end
  end

  test "records carry the source name the fetcher was built for" do
    stub_types(page([ establishment ]))
    assert_equal "other", LeadMonitor::FhrsFetcher.new(source: "other").tap { |fetcher| fetcher.stubs(:sleep) }.fetch.first[:source]
  end

  test "fetches all pages and target types" do
    LeadMonitor::FhrsFetcher::BUSINESS_TYPE_IDS.each do |type|
      [ 1, 2 ].each do |number|
        stub_request(:get, LeadMonitor::FhrsFetcher::ENDPOINT)
          .with(query: hash_including("businessTypeId" => type.to_s, "pageNumber" => number.to_s))
          .to_return(body: page([ establishment(type * 10 + number) ], number: number, pages: 2, count: 2).to_json)
      end
    end
    assert_equal 8, @fetcher.fetch.size
  end

  test "malformed successful responses fail the whole snapshot" do
    [ {}, { establishments: [] }, page.merge(establishments: nil),
      page([ { BusinessName: "Missing identity" } ]), page([ establishment ]).merge(meta: { totalPages: 2 }),
      page([], pages: 2, count: 2), page([ establishment ], number: 2),
      page([ establishment ], count: 2) ].each do |body|
      stub_types(body)
      assert_raises(LeadMonitor::FhrsFetcher::FetchFailed, body.inspect) { @fetcher.fetch }
    end
  end

  test "later page failure never returns partial results" do
    stub_request(:get, LeadMonitor::FhrsFetcher::ENDPOINT).with(query: hash_including("pageNumber" => "1"))
      .to_return(body: page([ establishment ], pages: 2, count: 2).to_json)
    stub_request(:get, LeadMonitor::FhrsFetcher::ENDPOINT).with(query: hash_including("pageNumber" => "2"))
      .to_return(status: 503)
    assert_raises(LeadMonitor::FhrsFetcher::FetchFailed) { @fetcher.fetch }
  end

  test "rate limit retries are bounded" do
    request = stub_request(:get, LeadMonitor::FhrsFetcher::ENDPOINT).with(query: hash_including("businessTypeId" => "1"))
      .to_return(status: 429, headers: { "Retry-After" => "99999" })
    assert_raises(LeadMonitor::FhrsFetcher::FetchFailed) { @fetcher.fetch }
    assert_requested request, times: 3
  end

  test "zero page metadata cannot describe a nonempty snapshot" do
    stub_types(page([ establishment ], pages: 0))
    assert_raises(LeadMonitor::FhrsFetcher::FetchFailed) { @fetcher.fetch }
  end

  test "a snapshot that changes during pagination is fetched again once" do
    stub_request(:get, LeadMonitor::FhrsFetcher::ENDPOINT).with(query: hash_including("pageNumber" => "1"))
      .to_return(body: page([ establishment ], pages: 2, count: 2).to_json)
    stub_request(:get, LeadMonitor::FhrsFetcher::ENDPOINT).with(query: hash_including("pageNumber" => "2"))
      .to_return(body: page([ establishment(2) ], number: 2, pages: 2, count: 3).to_json)
      .then.to_return(body: page([ establishment(2) ], number: 2, pages: 2, count: 2).to_json)
    assert_equal 2, @fetcher.fetch.size
  end

  test "a changing count or a repeated identity across pages rejects the snapshot" do
    [ page([ establishment(2) ], number: 2, pages: 2, count: 3),
      page([ establishment ], number: 2, pages: 2, count: 2) ].each do |second|
      stub_request(:get, LeadMonitor::FhrsFetcher::ENDPOINT).with(query: hash_including("pageNumber" => "1"))
        .to_return(body: page([ establishment ], pages: 2, count: 2).to_json)
      stub_request(:get, LeadMonitor::FhrsFetcher::ENDPOINT).with(query: hash_including("pageNumber" => "2"))
        .to_return(body: second.to_json)
      assert_raises(LeadMonitor::FhrsFetcher::FetchFailed) { @fetcher.fetch }
    end
  end
end
