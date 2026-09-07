require "test_helper"

class LeaderboardFairnessTest < ActiveSupport::TestCase
  test "ties use the same oldest-first ordering in responses and the board" do
    LeaderboardEntry.delete_all
    first = LeaderboardEntry.create!(name: "First", score: 15, status: "approved")
    second = LeaderboardEntry.create!(name: "Second", score: 15, status: "approved")
    assert_equal 1, first.rank
    assert_equal 2, second.rank
  end

  test "only a participant's best approved run occupies the leaderboard" do
    LeaderboardEntry.delete_all
    participant = GameParticipant.create!
    LeaderboardEntry.create!(name: "First run", score: 15, status: "approved", game_participant: participant)
    LeaderboardEntry.create!(name: "Best run", score: 20, status: "approved", game_participant: participant)
    assert_equal [ "Best run" ], LeaderboardEntry.current_top.map(&:name)
  end
end
