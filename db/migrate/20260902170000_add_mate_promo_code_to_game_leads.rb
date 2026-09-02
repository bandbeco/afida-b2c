class AddMatePromoCodeToGameLeads < ActiveRecord::Migration[8.1]
  def change
    add_column :game_leads, :mate_promo_code, :string
  end
end
