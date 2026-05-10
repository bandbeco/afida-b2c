class CreateCollectionCategoryGuides < ActiveRecord::Migration[8.1]
  def change
    create_table :collection_category_guides do |t|
      t.references :collection, null: false, foreign_key: { on_delete: :cascade }
      t.references :category, null: false, foreign_key: { on_delete: :cascade }
      t.text :buying_guide

      t.timestamps
    end

    add_index :collection_category_guides,
      [ :collection_id, :category_id ],
      unique: true,
      name: "index_collection_category_guides_on_collection_and_category"
  end
end
