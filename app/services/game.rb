module Game
  # Public board payload shared by the game page (first paint) and GET /game/leaderboard.
  def self.board
    {
      month: Date.current.strftime("%B %Y"),
      token: VerifiedRun.issue_token,
      entries: LeaderboardEntry.current_top.map.with_index(1) do |entry, rank|
        { rank: rank, name: entry.name, score: entry.score, instagram_handle: entry.public_handle }
      end
    }
  end
end
