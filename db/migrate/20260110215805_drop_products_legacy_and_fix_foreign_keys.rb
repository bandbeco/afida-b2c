class DropProductsLegacyAndFixForeignKeys < ActiveRecord::Migration[8.1]
  def up
    # Clean up branded_product_prices that reference products_legacy IDs
    # These need to be re-associated with the new products table or deleted
    execute <<~SQL
      DELETE FROM branded_product_prices
      WHERE product_id NOT IN (SELECT id FROM products)
    SQL

    # Update foreign keys on branded_product_prices
    if foreign_key_exists?(:branded_product_prices, :products_legacy, column: :product_id)
      remove_foreign_key :branded_product_prices, :products_legacy, column: :product_id
      add_foreign_key :branded_product_prices, :products, column: :product_id
    end

    # Clean up product_compatible_lids that reference products_legacy IDs
    execute <<~SQL
      DELETE FROM product_compatible_lids
      WHERE product_id NOT IN (SELECT id FROM products)
         OR compatible_lid_id NOT IN (SELECT id FROM products)
    SQL

    # Update foreign keys on product_compatible_lids
    if foreign_key_exists?(:product_compatible_lids, :products_legacy, column: :product_id)
      remove_foreign_key :product_compatible_lids, :products_legacy, column: :product_id
      add_foreign_key :product_compatible_lids, :products, column: :product_id
    end

    if foreign_key_exists?(:product_compatible_lids, :products_legacy, column: :compatible_lid_id)
      remove_foreign_key :product_compatible_lids, :products_legacy, column: :compatible_lid_id
      add_foreign_key :product_compatible_lids, :products, column: :compatible_lid_id
    end

    # Clean up product_option_assignments that reference products_legacy IDs
    execute <<~SQL
      DELETE FROM product_option_assignments
      WHERE product_id NOT IN (SELECT id FROM products)
    SQL

    # Update foreign keys on product_option_assignments
    if foreign_key_exists?(:product_option_assignments, :products_legacy, column: :product_id)
      remove_foreign_key :product_option_assignments, :products_legacy, column: :product_id
      add_foreign_key :product_option_assignments, :products, column: :product_id
    end

    # Drop the legacy products table
    drop_table :products_legacy if table_exists?(:products_legacy)
  end

  def down
    # Create the products_legacy table back (simplified version)
    create_table :products_legacy do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :sku
      t.string :base_sku
      t.references :category, foreign_key: true
      t.integer :product_type, default: 0
      t.text :description_short
      t.text :description_standard
      t.text :description_detailed
      t.string :meta_title
      t.string :meta_description
      t.boolean :active, default: true
      t.boolean :featured, default: false
      t.boolean :best_seller, default: false
      t.integer :position, default: 0
      t.timestamps
    end

    add_index :products_legacy, :slug, unique: true
    add_index :products_legacy, :sku, unique: true
    add_index :products_legacy, :active
    add_index :products_legacy, :featured
    add_index :products_legacy, :best_seller
    add_index :products_legacy, :position

    # Revert foreign keys to point to products_legacy
    if foreign_key_exists?(:branded_product_prices, :products, column: :product_id)
      remove_foreign_key :branded_product_prices, :products, column: :product_id
      add_foreign_key :branded_product_prices, :products_legacy, column: :product_id
    end

    if foreign_key_exists?(:product_compatible_lids, :products, column: :product_id)
      remove_foreign_key :product_compatible_lids, :products, column: :product_id
      add_foreign_key :product_compatible_lids, :products_legacy, column: :product_id
    end

    if foreign_key_exists?(:product_compatible_lids, :products, column: :compatible_lid_id)
      remove_foreign_key :product_compatible_lids, :products, column: :compatible_lid_id
      add_foreign_key :product_compatible_lids, :products_legacy, column: :compatible_lid_id
    end

    if foreign_key_exists?(:product_option_assignments, :products, column: :product_id)
      remove_foreign_key :product_option_assignments, :products, column: :product_id
      add_foreign_key :product_option_assignments, :products_legacy, column: :product_id
    end
  end
end
