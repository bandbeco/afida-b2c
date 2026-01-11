class CreateProductFamilies < ActiveRecord::Migration[8.1]
  def change
    create_table :product_families do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :sort_order, default: 0

      t.timestamps
    end

    add_index :product_families, :slug, unique: true
  end
end
