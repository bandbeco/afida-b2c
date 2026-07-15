# frozen_string_literal: true

require "test_helper"
require "csv"

module LeadGen
  class LeadsCsvTest < ActiveSupport::TestCase
    test "generates a header row plus one row per lead" do
      csv = CSV.parse(LeadGen::LeadsCsv.generate([ leads(:fhrs_cafe), leads(:fhrs_takeaway_contacted) ]), headers: true)

      assert_equal %w[source external_id business_name business_type address postcode local_authority first_seen],
                   csv.headers
      assert_equal 2, csv.size
      assert_equal "Fixture Coffee House", csv[0]["business_name"]
      assert_equal "TT1 1AA", csv[0]["postcode"]
      assert_equal leads(:fhrs_cafe).created_at.to_date.iso8601, csv[0]["first_seen"]
    end

    test "round-trips names containing commas and quotes" do
      lead = Lead.create!(source: "fhrs", external_id: "999100",
                          business_name: %(Baps, Butties & "Brews"))

      csv = CSV.parse(LeadGen::LeadsCsv.generate([ lead ]), headers: true)

      assert_equal %(Baps, Butties & "Brews"), csv[0]["business_name"]
    end

    test "generates only the header row for no leads" do
      csv = CSV.parse(LeadGen::LeadsCsv.generate([]), headers: true)

      assert_equal 0, csv.size
    end
  end
end
