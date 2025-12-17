class CreateReorderScheduleItems < ActiveRecord::Migration[8.1]
  def change
    create_table :reorder_schedule_items do |t|
      t.references :reorder_schedule, null: false, foreign_key: true
      t.references :product_variant, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.decimal :price, precision: 10, scale: 2, null: false

      t.timestamps
    end

    add_index :reorder_schedule_items, [ :reorder_schedule_id, :product_variant_id ],
              unique: true, name: "idx_schedule_items_unique"
  end
end
