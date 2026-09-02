# Monthly leaderboard for The Afida Stack game (/game). Entries are submitted
# from the static game page with a server-verified drop replay; the Instagram
# handle is only shown publicly once an admin approves the entry, and rejected
# entries disappear from the board entirely.
class CreateLeaderboardEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :leaderboard_entries do |t|
      t.string :name, null: false
      t.string :instagram_handle
      t.integer :score, null: false
      t.date :month, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :replay

      t.timestamps
    end

    add_index :leaderboard_entries, [ :month, :score ]
    add_index :leaderboard_entries, :status
  end
end
