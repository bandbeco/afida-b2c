class CreateGameLeads < ActiveRecord::Migration[8.1]
  def change
    create_table :game_leads do |t|
      t.string :email, null: false
      t.string :source, null: false
      t.boolean :marketing_opt_in, default: false, null: false
      t.timestamps
    end
    add_index :game_leads, :email, unique: true
  end
end
