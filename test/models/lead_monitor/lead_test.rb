require "test_helper"

class LeadMonitor::LeadTest < ActiveSupport::TestCase
  def lead
    LeadMonitor::Lead.new(source: "fhrs", external_id: "123", business_name: "Second café",
      address: "1 High Street", postcode: "SW1A 1AA")
  end

  def evidence(classification: "recent", opening_on: Date.current - 10)
    { classification: classification, opening_on: opening_on, evidence_kind: "business_announcement",
      evidence_url: "https://example.com/opening", evidence_notes: "Names this venue and address",
      location_verified: true, reviewed_by: "admin@example.com", reviewed_at: Time.current }
  end

  test "discoveries start unqualified" do
    candidate = lead
    assert candidate.valid?
    assert_equal "possible", candidate.classification
    refute candidate.opening_eligible?
  end

  test "verified recent and future trading locations qualify including an existing operator's second location" do
    [ evidence, evidence(classification: "upcoming", opening_on: Date.current + 10) ].each do |attributes|
      candidate = lead
      candidate.assign_attributes(attributes)
      assert candidate.valid?, candidate.errors.full_messages.join(", ")
      assert candidate.opening_eligible?
    end
  end

  test "qualification requires a human and evidence matched to the location" do
    [ { evidence_kind: "incorporation" }, { opening_on: nil }, { evidence_url: nil },
      { reviewed_by: nil }, { reviewed_at: nil }, { location_verified: false },
      { evidence_url: "javascript:alert(1)" } ].each do |invalid|
      candidate = lead
      candidate.assign_attributes(evidence.merge(invalid))
      refute candidate.valid?, invalid.inspect
      refute candidate.opening_eligible?, invalid.inspect
    end
  end

  test "direct confirmation requires dated notes" do
    candidate = lead
    candidate.assign_attributes(evidence.merge(evidence_kind: "direct_confirmation", evidence_url: nil))
    assert candidate.valid?
    assert candidate.opening_eligible?
    candidate.evidence_notes = nil
    refute candidate.valid?
    refute candidate.opening_eligible?
  end

  test "the sixty day boundary and elapsed planned dates are rechecked at contact time" do
    candidate = lead
    candidate.assign_attributes(evidence(opening_on: Date.current - 60))
    candidate.save!
    assert candidate.opening_eligible?
    travel 1.day do
      refute candidate.reload.opening_eligible?
      assert candidate.update(contact_phone: "01234 567890")
    end

    candidate.assign_attributes(evidence(classification: "upcoming", opening_on: Date.current + 1))
    candidate.save!
    travel 1.day do
      refute candidate.reload.opening_eligible?
      assert_equal "upcoming", candidate.classification
    end
  end

  test "old openings and ownership changes cannot qualify" do
    candidate = lead
    candidate.assign_attributes(evidence(opening_on: Date.current - 61))
    refute candidate.valid?
    refute candidate.opening_eligible?
    candidate.assign_attributes(evidence(classification: "existing"))
    assert candidate.valid?
    refute candidate.opening_eligible?
  end
end
