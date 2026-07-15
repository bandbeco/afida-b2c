require "test_helper"

class LeadTest < ActiveSupport::TestCase
  test "requires source, external_id and business_name" do
    lead = Lead.new

    assert_not lead.valid?
    assert_includes lead.errors[:source], "can't be blank"
    assert_includes lead.errors[:external_id], "can't be blank"
    assert_includes lead.errors[:business_name], "can't be blank"
  end

  test "external_id must be unique within a source" do
    existing = leads(:fhrs_cafe)
    lead = Lead.new(source: existing.source, external_id: existing.external_id, business_name: "Copycat")

    assert_not lead.valid?
    assert_includes lead.errors[:external_id], "has already been taken"
  end

  test "status defaults to new_lead" do
    lead = Lead.create!(source: "fhrs", external_id: "999001", business_name: "Fresh Cafe")

    assert_predicate lead, :new_lead?
  end

  test "an unknown status is a validation error, not an exception" do
    lead = leads(:fhrs_cafe)

    assert_nothing_raised { lead.status = "garbage" }
    assert_not lead.valid?
    assert_includes lead.errors[:status], "is not included in the list"
  end

  test "recent_first orders newest first" do
    older = leads(:fhrs_cafe)
    older.update_column(:created_at, 2.weeks.ago)
    newer = Lead.create!(source: "fhrs", external_id: "999002", business_name: "Newest Cafe")

    ordered = Lead.recent_first.to_a
    assert_operator ordered.index(newer), :<, ordered.index(older)
  end

  test "payload defaults to an empty hash" do
    lead = Lead.create!(source: "fhrs", external_id: "999003", business_name: "Payloadless Cafe")

    assert_equal({}, lead.reload.payload)
  end
end
