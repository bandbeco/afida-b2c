class CreateAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :addresses do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :nickname, null: false, limit: 50
      t.string :recipient_name, null: false, limit: 100
      t.string :company_name, limit: 100
      t.string :line1, null: false, limit: 200
      t.string :line2, limit: 100
      t.string :city, null: false, limit: 100
      t.string :postcode, null: false, limit: 20
      t.string :phone, limit: 30
      t.string :country, null: false, limit: 2, default: "GB"
      t.boolean :default, null: false, default: false

      t.timestamps
    end

    # Partial index for fast default address lookup
    add_index :addresses, [ :user_id, :default ],
              where: "\"default\" = true",
              name: "idx_addresses_user_default"
  end
end
