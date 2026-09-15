require "test_helper"

class LeadMonitor::DeliverDigestsJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper
  test "persisted pending runs survive missing enqueue and are delivered only once on normal retries" do
    run = LeadMonitor::Run.create!(source: "fhrs", status: "seeded", fetched_count: 10)
    LeadMonitor::DigestMailer.stubs(:recipient).returns("admin@example.com")
    assert_emails 1 do
      LeadMonitor::DeliverDigestsJob.perform_now
      LeadMonitor::DeliverDigestsJob.perform_now
    end
    assert run.reload.notified_at
    assert_includes ActionMailer::Base.deliveries.last.body.to_s, "seeded"
  end

  test "mailer failure leaves a run pending for a later sweep" do
    run = LeadMonitor::Run.create!(source: "fhrs", status: "failed", error: "FetchFailed")
    LeadMonitor::DigestMailer.stubs(:recipient).returns("admin@example.com")
    message = mock
    message.expects(:deliver_now).raises(IOError, "mail unavailable")
    LeadMonitor::DigestMailer.expects(:digest).with(run).returns(message)
    LeadMonitor::DeliverDigestsJob.perform_now
    assert_nil run.reload.notified_at
  end

  test "missing recipient leaves pending runs intact" do
    run = LeadMonitor::Run.create!(source: "fhrs", status: "completed")
    LeadMonitor::DigestMailer.stubs(:recipient).returns(nil)
    assert_no_emails { LeadMonitor::DeliverDigestsJob.perform_now }
    assert_nil run.reload.notified_at
  end

  test "digest labels prospects as unqualified and includes import failures" do
    LeadMonitor::DigestMailer.stubs(:recipient).returns("admin@example.com")
    run = LeadMonitor::Run.create!(source: "fhrs", status: "failed", error: "FetchFailed")
    message = LeadMonitor::DigestMailer.digest(run)
    assert_includes message.body.to_s, "FetchFailed"
    assert_includes message.body.to_s, "not proof of a new opening"
    assert_equal [ "admin@example.com" ], message.to
  end

  test "digest delivery raises failures even when storefront mail suppresses them" do
    previous = ActionMailer::Base.raise_delivery_errors
    ActionMailer::Base.raise_delivery_errors = false
    LeadMonitor::DigestMailer.stubs(:recipient).returns("admin@example.com")
    run = LeadMonitor::Run.create!(source: "fhrs", status: "seeded")
    assert LeadMonitor::DigestMailer.digest(run).raise_delivery_errors
    refute ActionMailer::Base.raise_delivery_errors
  ensure
    ActionMailer::Base.raise_delivery_errors = previous
  end

  test "disabled delivery leaves the digest pending" do
    run = LeadMonitor::Run.create!(source: "fhrs", status: "seeded")
    LeadMonitor::DigestMailer.stubs(:recipient).returns("admin@example.com")
    LeadMonitor::DigestMailer.stubs(:perform_deliveries).returns(false)
    assert_no_emails { LeadMonitor::DeliverDigestsJob.perform_now }
    assert_nil run.reload.notified_at
  end
end
