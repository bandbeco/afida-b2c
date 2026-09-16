require "test_helper"

class LeadMonitor::DiscoverTest < ActiveSupport::TestCase
  def record(id)
    { source: "fhrs", external_id: id, business_name: "Café #{id}", address: "1 High Street", payload: {} }
  end

  def discover(records)
    LeadMonitor::Discover.new(source: "fhrs", fetcher: stub(fetch: records)).call
  end

  test "initial snapshot is silent and subsequent identities become unqualified leads exactly once" do
    run = discover([ record("1") ])
    assert_equal "seeded", run.status
    assert_equal 0, LeadMonitor::Lead.count
    assert_equal 1, LeadMonitor::Sighting.count
    run = discover([ record("1"), record("2"), record("2") ])
    assert_equal 1, run.new_count
    assert_equal "possible", LeadMonitor::Lead.sole.classification
    assert_equal run.id, LeadMonitor::Lead.sole.run_id
    assert_equal 0, discover([ record("2") ]).new_count
    assert_equal 1, LeadMonitor::Lead.count
  end

  test "a successful empty seed is still a seed" do
    assert_equal "seeded", discover([]).status
    assert_equal 1, discover([ record("1") ]).new_count
  end

  test "fetch failures do not seed and remain visible as pending digest runs" do
    fetcher = mock
    fetcher.expects(:fetch).raises(LeadMonitor::FhrsFetcher::FetchFailed, "broken page")
    Sentry.expects(:capture_exception).with(instance_of(LeadMonitor::FhrsFetcher::FetchFailed)).once
    run = LeadMonitor::Discover.new(source: "fhrs", fetcher: fetcher).call
    assert_equal "failed", run.status
    assert_equal "LeadMonitor::FhrsFetcher::FetchFailed: broken page", run.error
    assert_nil run.notified_at
    assert_nil LeadMonitor::Source.find_by!(name: "fhrs").seeded_at
    assert_equal 0, LeadMonitor::Sighting.count
    assert_equal "seeded", discover([ record("1") ]).status
  end

  test "failed lead persistence rolls back sightings and can be recovered next run" do
    discover([ record("1") ])
    LeadMonitor::Lead.expects(:create!).raises(ActiveRecord::RecordInvalid).once
    assert_equal "failed", discover([ record("1"), record("2") ]).status
    assert_equal [ "1" ], LeadMonitor::Sighting.pluck(:external_id)
    LeadMonitor::Lead.unstub(:create!)
    assert_equal 1, discover([ record("1"), record("2") ]).new_count
  end

  test "the snapshot is fetched before the source row is locked" do
    depth_outside = LeadMonitor::Record.connection.open_transactions
    fetcher = mock
    fetcher.expects(:fetch).with { LeadMonitor::Record.connection.open_transactions == depth_outside }.returns([])
    assert_equal "seeded", LeadMonitor::Discover.new(source: "fhrs", fetcher: fetcher).call.status
  end

  test "a different source has an independent seed" do
    discover([ record("1") ])
    run = LeadMonitor::Discover.new(source: "other", fetcher: stub(fetch: [ record("1").merge(source: "other") ])).call
    assert_equal "seeded", run.status
    assert_equal 2, LeadMonitor::Sighting.count
  end

  test "source payload cannot set qualification or contact fields" do
    discover([])
    run = discover([ record("1").merge(classification: "existing", contact_email: "imported@example.com") ])
    assert_equal "completed", run.status
    assert_equal "possible", LeadMonitor::Lead.sole.classification
    assert_nil LeadMonitor::Lead.sole.contact_email
  end
end
