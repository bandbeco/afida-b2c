class AddReferralPromoCodeToLeaderboardEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :leaderboard_entries, :referral_promo_code, :string
  end
end
