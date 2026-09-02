# Referral payout is per converted lead: the first £100+ order from this
# address pays the credited referrer £10, once.
class AddReferrerToGameLeads < ActiveRecord::Migration[8.1]
  def change
    add_reference :game_leads, :referrer, foreign_key: { to_table: :leaderboard_entries }
    add_column :game_leads, :referrer_rewarded_at, :datetime
  end
end
