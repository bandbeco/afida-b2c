class AddEmailToLeaderboardEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :leaderboard_entries, :email, :string
    add_column :leaderboard_entries, :marketing_opt_in, :boolean, default: false, null: false
  end
end
