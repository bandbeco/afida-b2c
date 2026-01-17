class CreateCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :collections do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :meta_title
      t.text :meta_description
      t.boolean :featured, default: false, null: false
      t.boolean :sample_pack, default: false, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :collections, :slug, unique: true
    add_index :collections, :featured
    add_index :collections, :sample_pack
    add_index :collections, :position
  end
end
