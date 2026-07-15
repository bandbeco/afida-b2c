require "test_helper"

class SightingTest < ActiveSupport::TestCase
  test "requires source and external_id" do
    sighting = Sighting.new

    assert_not sighting.valid?
    assert_includes sighting.errors[:source], "can't be blank"
    assert_includes sighting.errors[:external_id], "can't be blank"
  end

  test "record_batch returns only external_ids not already known" do
    Sighting.create!(source: "fhrs", external_id: "111")

    new_ids = Sighting.record_batch("fhrs", [ "111", "222", "333" ])

    assert_equal [ "222", "333" ], new_ids.sort
    assert_equal 3, Sighting.source_fhrs.count
  end

  test "record_batch is idempotent across reruns" do
    Sighting.record_batch("fhrs", [ "111", "222" ])

    assert_empty Sighting.record_batch("fhrs", [ "111", "222" ])
    assert_equal 2, Sighting.source_fhrs.count
  end

  test "record_batch dedups within a batch" do
    new_ids = Sighting.record_batch("fhrs", [ "111", "111", "222" ])

    assert_equal [ "111", "222" ], new_ids.sort
    assert_equal 2, Sighting.source_fhrs.count
  end

  test "record_batch returns empty for no ids" do
    assert_empty Sighting.record_batch("fhrs", [])
  end

  test "record_batch sets timestamps" do
    Sighting.record_batch("fhrs", [ "111" ])

    sighting = Sighting.find_by!(source: "fhrs", external_id: "111")
    assert_not_nil sighting.created_at
    assert_not_nil sighting.updated_at
  end

  test "duplicate [source, external_id] is rejected by the unique index" do
    Sighting.create!(source: "fhrs", external_id: "111")

    assert_raises(ActiveRecord::RecordNotUnique) do
      Sighting.insert_all!([ { source: "fhrs", external_id: "111" } ])
    end
  end
end
