module Game
  # Public board listing shared by the game page (first paint) and GET /game/leaderboard.
  # Play tokens live on the game page so a listing refresh cannot invalidate a round.
  def self.board
    {
      month: Date.current.strftime("%B %Y"),
      entries: LeaderboardEntry.current_top.map.with_index(1) do |entry, rank|
        { rank: rank, name: entry.name, score: entry.score, instagram_handle: entry.public_handle }
      end
    }
  end
end
