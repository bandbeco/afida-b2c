require "test_helper"

class GameLeadTest < ActiveSupport::TestCase
  test "requires a plausible email and a known source" do
    assert_not GameLead.new(email: "not-an-email", source: "win").valid?
    assert_not GameLead.new(email: "cafe@example.com", source: "mystery").valid?
    assert GameLead.new(email: "cafe@example.com", source: "win").valid?
  end

  test "capture stores one row per address, case-insensitively" do
    GameLead.capture(email: "Cafe@Example.com", source: "win")
    GameLead.capture(email: "cafe@example.com", source: "board")

    assert_equal 1, GameLead.count
    assert_equal "cafe@example.com", GameLead.first.email
  end

  test "capture keeps the first source and never downgrades marketing consent" do
    GameLead.capture(email: "cafe@example.com", source: "win", marketing_opt_in: true)
    lead = GameLead.capture(email: "cafe@example.com", source: "board", marketing_opt_in: false)

    assert_equal "win", lead.source
    assert lead.marketing_opt_in
  end

  test "capture upgrades consent when a later opt-in arrives" do
    GameLead.capture(email: "cafe@example.com", source: "win")
    lead = GameLead.capture(email: "cafe@example.com", source: "win", marketing_opt_in: true)

    assert lead.marketing_opt_in
  end
end
