require "test_helper"
require "fugit"

class LeadMonitor::DiscoverJobTest < ActiveJob::TestCase
  test "discovery persists its result before scheduling the digest" do
    LeadMonitor::FhrsFetcher.any_instance.stubs(:fetch).returns([])
    assert_enqueued_with(job: LeadMonitor::DeliverDigestsJob) { LeadMonitor::DiscoverJob.perform_now }
    assert_equal "seeded", LeadMonitor::Run.sole.status
  end

  test "an enqueue failure cannot lose the pending digest" do
    LeadMonitor::FhrsFetcher.any_instance.stubs(:fetch).returns([])
    LeadMonitor::DeliverDigestsJob.expects(:perform_later).raises(IOError)
    assert_raises(IOError) { LeadMonitor::DiscoverJob.perform_now }
    assert_equal "seeded", LeadMonitor::Run.pending_notification.sole.status
  end

  test "production schedules include discovery and independent digest recovery" do
    schedule = YAML.load_file(Rails.root.join("config/recurring.yml")).fetch("production")
    assert_equal "LeadMonitor::DiscoverJob", schedule.fetch("discover_lead_monitor").fetch("class")
    assert_equal "LeadMonitor::DeliverDigestsJob", schedule.fetch("deliver_lead_monitor_digests").fetch("class")
    assert_equal "every hour", schedule.fetch("deliver_lead_monitor_digests").fetch("schedule")
    cron = Fugit.parse(schedule.fetch("discover_lead_monitor").fetch("schedule"))
    assert cron
    assert_equal "Europe/London", cron.zone
    %w[discover_lead_monitor deliver_lead_monitor_digests].each do |name|
      assert_equal "lead_monitor", schedule.fetch(name).fetch("queue")
      assert_equal "lead_monitor", schedule.fetch(name).fetch("class").constantize.new.queue_name
    end
  end
end
