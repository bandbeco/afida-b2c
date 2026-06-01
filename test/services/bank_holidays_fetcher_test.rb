# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class BankHolidaysFetcherTest < ActiveSupport::TestCase
  ENDPOINT = BankHolidaysFetcher::ENDPOINT

  def payload
    {
      "england-and-wales" => {
        "division" => "england-and-wales",
        "events" => [
          { "title" => "New Year's Day", "date" => "2026-01-01" },
          { "title" => "Good Friday", "date" => "2026-04-03" }
        ]
      },
      "scotland" => {
        "division" => "scotland",
        "events" => [
          { "title" => "2nd January", "date" => "2026-01-02" }
        ]
      }
    }
  end

  test "returns the england-and-wales dates on success" do
    stub_request(:get, ENDPOINT)
      .to_return(status: 200, body: payload.to_json, headers: { "Content-Type" => "application/json" })

    assert_equal [ Date.new(2026, 1, 1), Date.new(2026, 4, 3) ], BankHolidaysFetcher.fetch
  end

  test "excludes other divisions" do
    stub_request(:get, ENDPOINT)
      .to_return(status: 200, body: payload.to_json)

    result = BankHolidaysFetcher.fetch
    assert_not_includes result, Date.new(2026, 1, 2) # Scotland-only
  end

  test "returns nil on a non-200 response" do
    stub_request(:get, ENDPOINT).to_return(status: 503)

    assert_nil BankHolidaysFetcher.fetch
  end

  test "returns nil on malformed JSON" do
    stub_request(:get, ENDPOINT).to_return(status: 200, body: "not json")

    assert_nil BankHolidaysFetcher.fetch
  end

  test "returns nil when the division is missing" do
    stub_request(:get, ENDPOINT).to_return(status: 200, body: { "scotland" => { "events" => [] } }.to_json)

    assert_nil BankHolidaysFetcher.fetch
  end

  test "returns nil on a timeout" do
    stub_request(:get, ENDPOINT).to_timeout

    assert_nil BankHolidaysFetcher.fetch
  end
end
