class DropReferralPromoCodeFromLeaderboardEntries < ActiveRecord::Migration[8.1]
  def change
    remove_column :leaderboard_entries, :referral_promo_code, :string
  end
end
