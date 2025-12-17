class CreateReorderSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :reorder_schedules do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :frequency, null: false
      t.integer :status, null: false, default: 0
      t.date :next_scheduled_date, null: false
      t.string :stripe_payment_method_id, null: false
      t.datetime :paused_at
      t.datetime :cancelled_at

      t.timestamps
    end
    add_index :reorder_schedules, :next_scheduled_date
    add_index :reorder_schedules, [ :status, :next_scheduled_date ]
  end
end
