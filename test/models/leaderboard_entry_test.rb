require "test_helper"

class LeaderboardEntryTest < ActiveSupport::TestCase
  def valid_attributes
    { name: "Laurent", score: 12 }
  end

  test "valid with a name and score, defaulting to pending and the current month" do
    entry = LeaderboardEntry.new(valid_attributes)

    assert entry.valid?
    entry.save!
    assert entry.pending?
    assert_equal Date.current.beginning_of_month, entry.month
  end

  test "requires a name of at most 14 characters" do
    assert_not LeaderboardEntry.new(valid_attributes.merge(name: "")).valid?
    assert_not LeaderboardEntry.new(valid_attributes.merge(name: "a" * 15)).valid?
  end

  test "requires a positive score within the ceiling" do
    assert_not LeaderboardEntry.new(valid_attributes.merge(score: 0)).valid?
    assert_not LeaderboardEntry.new(valid_attributes.merge(score: 501)).valid?
  end

  test "normalizes instagram handles to bare lowercase" do
    entry = LeaderboardEntry.new(valid_attributes.merge(instagram_handle: "@The.Roastery"))

    assert entry.valid?
    assert_equal "the.roastery", entry.instagram_handle
  end

  test "rejects instagram handles with illegal characters" do
    entry = LeaderboardEntry.new(valid_attributes.merge(instagram_handle: "https://spam.example"))

    assert_not entry.valid?
  end

  test "allows a blank instagram handle" do
    assert LeaderboardEntry.new(valid_attributes.merge(instagram_handle: "")).valid?
  end

  test "current_top returns this month's visible entries best-first, capped" do
    LeaderboardEntry.delete_all
    12.times { |i| LeaderboardEntry.create!(name: "P#{i}", score: i + 1) }
    LeaderboardEntry.create!(name: "Cheat", score: 99, status: "rejected")
    LeaderboardEntry.create!(name: "LastMonth", score: 50, month: 1.month.ago.to_date.beginning_of_month)

    top = LeaderboardEntry.current_top

    assert_equal 10, top.size
    assert_equal 12, top.first.score
    assert_not_includes top.map(&:name), "Cheat"
    assert_not_includes top.map(&:name), "LastMonth"
  end

  test "ties rank by submission order" do
    LeaderboardEntry.delete_all
    first = LeaderboardEntry.create!(name: "First", score: 10, created_at: 2.hours.ago)
    LeaderboardEntry.create!(name: "Second", score: 10, created_at: 1.hour.ago)

    assert_equal first, LeaderboardEntry.current_top.first
  end

  test "only approved entries expose their handle publicly" do
    pending_entry = LeaderboardEntry.new(valid_attributes.merge(instagram_handle: "cafe", status: "pending"))
    approved = LeaderboardEntry.new(valid_attributes.merge(instagram_handle: "cafe", status: "approved"))

    assert_nil pending_entry.public_handle
    assert_equal "cafe", approved.public_handle
  end
end
