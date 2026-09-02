# The win claim is one code per address per month: persist it on the lead so
# "send again" resends, and a new month can mint a fresh one.
class AddWinPromoToGameLeads < ActiveRecord::Migration[8.1]
  def change
    add_column :game_leads, :win_promo_code, :string
    add_column :game_leads, :win_promo_month, :date
  end
end
