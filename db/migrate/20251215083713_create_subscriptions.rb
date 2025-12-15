class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :stripe_subscription_id, null: false
      t.string :stripe_customer_id, null: false
      t.string :stripe_price_id, null: false
      t.integer :frequency, null: false
      t.integer :status, null: false, default: 0
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.datetime :cancelled_at
      t.jsonb :items_snapshot, null: false, default: {}
      t.jsonb :shipping_snapshot, null: false, default: {}

      t.timestamps
    end

    add_index :subscriptions, :stripe_subscription_id, unique: true
    add_index :subscriptions, :status
  end
end
