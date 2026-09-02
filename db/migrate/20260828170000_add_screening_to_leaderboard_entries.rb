# Auto-approval support: clean entries go live immediately, and these columns
# carry what the suspicion screening found (flags) and the submitter's address
# (for burst detection), so only flagged entries wait for a human.
class AddScreeningToLeaderboardEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :leaderboard_entries, :flags, :jsonb, null: false, default: []
    add_column :leaderboard_entries, :submitter_ip, :string
    add_index :leaderboard_entries, [ :submitter_ip, :created_at ]
  end
end
