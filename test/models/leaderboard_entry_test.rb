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

  test "every entry gets a shareable referral code" do
    a = LeaderboardEntry.create!(valid_attributes)
    b = LeaderboardEntry.create!(valid_attributes.merge(name: "Other"))

    assert a.ref_code.present?
    assert_equal 6, a.ref_code.length
    assert_not_equal a.ref_code, b.ref_code
  end

  test "only approved entries expose their handle publicly" do
    pending_entry = LeaderboardEntry.new(valid_attributes.merge(instagram_handle: "cafe", status: "pending"))
    approved = LeaderboardEntry.new(valid_attributes.merge(instagram_handle: "cafe", status: "approved"))

    assert_nil pending_entry.public_handle
    assert_equal "cafe", approved.public_handle
  end

  test "credited_referrer names a real entry from a different address" do
    host = LeaderboardEntry.create!(valid_attributes.merge(submitter_ip: "9.9.9.9"))

    assert_equal host, LeaderboardEntry.credited_referrer(host.ref_code, "1.1.1.1")
    assert_equal host, LeaderboardEntry.credited_referrer(host.ref_code.upcase, "1.1.1.1")
  end

  test "credited_referrer ignores a blank code, an unknown code, and a self-invite" do
    host = LeaderboardEntry.create!(valid_attributes.merge(submitter_ip: "9.9.9.9"))

    assert_nil LeaderboardEntry.credited_referrer(nil, "1.1.1.1")
    assert_nil LeaderboardEntry.credited_referrer("", "1.1.1.1")
    assert_nil LeaderboardEntry.credited_referrer("nosuch", "1.1.1.1")
    assert_nil LeaderboardEntry.credited_referrer(host.ref_code, "9.9.9.9")
  end
end
