class CreatePendingOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :pending_orders do |t|
      t.references :reorder_schedule, null: false, foreign_key: true
      t.references :order, foreign_key: true
      t.integer :status, null: false, default: 0
      t.jsonb :items_snapshot, null: false, default: {}
      t.date :scheduled_for, null: false
      t.datetime :confirmed_at
      t.datetime :expired_at

      t.timestamps
    end

    add_index :pending_orders, :scheduled_for
    add_index :pending_orders, [ :status, :scheduled_for ]
  end
end
