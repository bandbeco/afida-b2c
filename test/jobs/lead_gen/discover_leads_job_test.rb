require "test_helper"

module LeadGen
  class DiscoverLeadsJobTest < ActiveJob::TestCase
    include ActionMailer::TestHelper

    def record(external_id, overrides = {})
      {
        source: "fhrs",
        external_id: external_id,
        business_name: "Cafe #{external_id}",
        business_type: "Restaurant/Cafe/Canteen",
        address: "1 High Street, Testtown",
        postcode: "TT1 1AA",
        local_authority: "Testshire",
        payload: { "FHRSID" => external_id.to_i }
      }.merge(overrides)
    end

    test "seed run records sightings but creates no leads" do
      LeadGen::FhrsFetcher.stubs(:fetch).returns([ record("501"), record("502") ])

      assert_difference -> { Sighting.source_fhrs.count }, 2 do
        assert_no_difference -> { Lead.count } do
          LeadGen::DiscoverLeadsJob.perform_now
        end
      end

      assert_enqueued_email_with LeadDigestMailer, :weekly_digest, params: {
        sections: [ { source: "fhrs", failed: false, seeded: true,
                      fetched_count: 2, sighted_count: 2, new_lead_ids: [] } ]
      }
    end

    test "post-seed run creates leads only for new sightings" do
      Sighting.record_batch("fhrs", [ "501" ])
      LeadGen::FhrsFetcher.stubs(:fetch).returns([ record("501"), record("502") ])

      assert_difference -> { Lead.count }, 1 do
        LeadGen::DiscoverLeadsJob.perform_now
      end

      lead = Lead.find_by!(source: "fhrs", external_id: "502")
      assert_equal "Cafe 502", lead.business_name
      assert_equal "Testshire", lead.local_authority
      assert_predicate lead, :new_lead?

      assert_enqueued_email_with LeadDigestMailer, :weekly_digest, params: {
        sections: [ { source: "fhrs", failed: false, seeded: false,
                      fetched_count: 2, sighted_count: 1, new_lead_ids: [ lead.id ] } ]
      }
    end

    test "duplicate external_ids within one fetch produce a single lead" do
      Sighting.record_batch("fhrs", [ "500" ])
      LeadGen::FhrsFetcher.stubs(:fetch).returns([ record("503"), record("503") ])

      assert_difference -> { Lead.count }, 1 do
        LeadGen::DiscoverLeadsJob.perform_now
      end
    end

    test "a failed fetch persists nothing and still sends the digest" do
      LeadGen::FhrsFetcher.stubs(:fetch).returns(nil)

      assert_no_difference [ -> { Sighting.count }, -> { Lead.count } ] do
        LeadGen::DiscoverLeadsJob.perform_now
      end

      assert_enqueued_email_with LeadDigestMailer, :weekly_digest, params: {
        sections: [ { source: "fhrs", failed: true } ]
      }
    end

    test "rerunning with the same register data reports zero new" do
      LeadGen::FhrsFetcher.stubs(:fetch).returns([ record("501"), record("502") ])

      LeadGen::DiscoverLeadsJob.perform_now
      assert_no_difference [ -> { Sighting.count }, -> { Lead.count } ] do
        LeadGen::DiscoverLeadsJob.perform_now
      end

      assert_enqueued_emails 2
      assert_enqueued_email_with LeadDigestMailer, :weekly_digest, params: {
        sections: [ { source: "fhrs", failed: false, seeded: false,
                      fetched_count: 2, sighted_count: 0, new_lead_ids: [] } ]
      }
    end

    test "a lead-creation failure rolls back the sightings recorded in the same run" do
      Sighting.record_batch("fhrs", [ "500" ])
      LeadGen::FhrsFetcher.stubs(:fetch).returns([ record("504") ])
      Lead.stubs(:create!).raises(ActiveRecord::RecordInvalid.new(Lead.new))

      assert_no_difference -> { Sighting.count } do
        LeadGen::DiscoverLeadsJob.perform_now
      end

      assert_enqueued_email_with LeadDigestMailer, :weekly_digest, params: {
        sections: [ { source: "fhrs", failed: true } ]
      }
    end
  end
end
