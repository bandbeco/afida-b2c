class CreateEmailSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :email_subscriptions do |t|
      t.string :email, null: false
      t.datetime :discount_claimed_at
      t.string :source, null: false, default: "cart_discount"

      t.timestamps
    end

    add_index :email_subscriptions, :email, unique: true
  end
end
