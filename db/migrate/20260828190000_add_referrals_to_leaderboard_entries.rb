# Peer-invite tracking for the game's referral rewards: every entry carries a
# short shareable code, and entries submitted through someone's link record the
# referrer. Verified-invite counts drive the milestone rewards (samples box,
# free case) so they must be resistant to self-invites — see
# LeaderboardEntry#verified_referrals.
class AddReferralsToLeaderboardEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :leaderboard_entries, :ref_code, :string
    add_reference :leaderboard_entries, :referrer, foreign_key: { to_table: :leaderboard_entries }

    add_index :leaderboard_entries, :ref_code, unique: true
  end
end
