class CreateCollectionItems < ActiveRecord::Migration[8.1]
  def change
    create_table :collection_items do |t|
      t.references :collection, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :collection_items, [ :collection_id, :product_id ], unique: true
    add_index :collection_items, [ :collection_id, :position ]
  end
end
