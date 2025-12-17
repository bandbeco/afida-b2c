class RemoveSubscriptions < ActiveRecord::Migration[8.1]
  def change
    # Remove foreign key and column from orders first
    remove_reference :orders, :subscription, foreign_key: true, index: true

    # Drop the subscriptions table
    drop_table :subscriptions do |t|
      t.bigint :user_id, null: false
      t.string :stripe_subscription_id, null: false
      t.string :stripe_customer_id, null: false
      t.string :stripe_price_id, null: false
      t.integer :frequency, null: false
      t.integer :status, default: 0, null: false
      t.jsonb :items_snapshot, null: false
      t.jsonb :shipping_snapshot, null: false
      t.datetime :current_period_end
      t.datetime :cancelled_at
      t.timestamps

      t.index :user_id
      t.index :stripe_subscription_id, unique: true
      t.index :status
    end
  end
end
