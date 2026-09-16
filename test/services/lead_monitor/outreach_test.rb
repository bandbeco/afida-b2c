require "test_helper"

class LeadMonitor::OutreachTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  def setup
    @lead = LeadMonitor::Lead.create!(source: "fhrs", external_id: "1", business_name: "Second café",
      classification: "recent", opening_on: Date.current - 5, evidence_kind: "direct_confirmation",
      evidence_notes: "Owner confirmed this address opened five days ago", location_verified: true,
      reviewed_by: "reviewer@example.com", reviewed_at: Time.current, contact_email: "owner@example.com")
  end

  def record(kind)
    LeadMonitor::Outreach.new(@lead).record!(kind: kind, actor: "admin@example.com", notes: "Personal message by email")
  end

  test "manual sent tracking preserves evidence and never sends an email" do
    assert_no_enqueued_emails do
      assert_difference "LeadMonitor::Activity.count", 1 do
        record("sent")
      end
    end
    assert_equal "contacted", @lead.outreach_status
    assert_equal "recent", @lead.reload.classification
    assert_equal Date.current + 1, @lead.next_follow_up_on
    assert_raises(LeadMonitor::Outreach::NotEligible) { record("sent") }
  end

  test "follow ups are due on days one two and seven with no further automated sequence" do
    record("sent")
    assert_raises(LeadMonitor::Outreach::NotEligible) { record("follow_up") }
    [ 1, 2, 7 ].each do |day|
      travel_to day.days.from_now do
        record("follow_up")
      end
    end
    assert_nil @lead.next_follow_up_on
    travel 10.days do
      assert_raises(LeadMonitor::Outreach::NotEligible) { record("follow_up") }
    end
  end

  test "a reply or suppression stops follow ups" do
    record("sent")
    record("replied")
    assert_equal "replied", @lead.outreach_status
    assert_nil @lead.next_follow_up_on
    travel 1.day do
      assert_raises(LeadMonitor::Outreach::NotEligible) { record("follow_up") }
    end
    record("suppressed")
    assert_equal "suppressed", @lead.outreach_status
    assert_nil LeadMonitor::Outreach.new(@lead).template
  end

  test "late follow ups cannot be recorded repeatedly on the same day" do
    record("sent")
    travel 7.days do
      record("follow_up")
      assert_raises(LeadMonitor::Outreach::NotEligible) { record("follow_up") }
    end
  end

  test "stale qualifications cannot pass even when the operator reruns an old list" do
    travel 61.days do
      assert_nil LeadMonitor::Outreach.new(@lead).template
      assert_raises(LeadMonitor::Outreach::NotEligible) { record("sent") }
    end
    @lead.update!(classification: "possible")
    assert_raises(LeadMonitor::Outreach::NotEligible) { record("sent") }
  end

  test "future opening must be reconfirmed before follow up on the opening day" do
    @lead.update!(classification: "upcoming", opening_on: Date.current + 1)
    record("sent")
    travel 1.day do
      assert_raises(LeadMonitor::Outreach::NotEligible) { record("follow_up") }
    end
  end

  test "messages start with the kit and include the business name" do
    template = LeadMonitor::Outreach.new(@lead).template
    assert_includes template, "free Café Packaging Starter Kit"
    assert_includes template, "Second café"
  end

  test "contact details and an audit note are required for outbound tracking" do
    @lead.update!(contact_email: nil)
    assert_raises(LeadMonitor::Outreach::NotEligible) { record("sent") }
    @lead.update!(contact_phone: "01234 567890")
    assert_raises(ActiveRecord::RecordInvalid) do
      LeadMonitor::Outreach.new(@lead).record!(kind: "sent", actor: "admin", notes: "")
    end
  end
end
