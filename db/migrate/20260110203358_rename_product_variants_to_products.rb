class RenameProductVariantsToProducts < ActiveRecord::Migration[8.1]
  def up
    # Step 1: Remove foreign key constraints that reference product_variants
    remove_foreign_key :cart_items, :product_variants
    remove_foreign_key :order_items, :product_variants
    remove_foreign_key :reorder_schedule_items, :product_variants

    # Also remove the product_id FK from order_items (references old products table)
    remove_foreign_key :order_items, :products

    # Remove FK from product_variants to old products
    remove_foreign_key :product_variants, :products

    # Step 2: Rename old products table to products_legacy
    rename_table :products, :products_legacy

    # Step 3: Rename product_variants to products
    rename_table :product_variants, :products

    # Step 4: Rename columns in related tables
    # cart_items: product_variant_id -> product_id
    rename_column :cart_items, :product_variant_id, :product_id

    # order_items: product_variant_id -> product_id (there's already a product_id column!)
    # First remove the old product_id column (which pointed to legacy products)
    remove_column :order_items, :product_id
    rename_column :order_items, :product_variant_id, :product_id

    # reorder_schedule_items: product_variant_id -> product_id
    rename_column :reorder_schedule_items, :product_variant_id, :product_id

    # Step 5: Remove the old product_id column from the new products table
    # (was pointing to legacy products)
    remove_column :products, :product_id

    # Step 6: Re-add foreign key constraints
    add_foreign_key :cart_items, :products
    add_foreign_key :order_items, :products
    add_foreign_key :reorder_schedule_items, :products

    # Step 7: Rename indexes on the new products table
    # The old product_variants indexes need to be renamed
    rename_index :products, :index_product_variants_on_product_id, :index_products_on_legacy_product_id if index_exists?(:products, :product_id, name: :index_product_variants_on_product_id)
    rename_index :products, :index_product_variants_on_sku, :index_products_on_sku if index_exists?(:products, :sku, name: :index_product_variants_on_sku)
    rename_index :products, :index_product_variants_on_slug, :index_products_on_slug if index_exists?(:products, :slug, name: :index_product_variants_on_slug)
  end

  def down
    # Step 1: Remove new foreign key constraints
    remove_foreign_key :cart_items, :products
    remove_foreign_key :order_items, :products
    remove_foreign_key :reorder_schedule_items, :products

    # Step 2: Rename columns back
    rename_column :cart_items, :product_id, :product_variant_id
    # For order_items, add back the old product_id column first
    add_column :order_items, :product_id_temp, :bigint
    rename_column :order_items, :product_id, :product_variant_id
    rename_column :order_items, :product_id_temp, :product_id
    rename_column :reorder_schedule_items, :product_id, :product_variant_id

    # Step 3: Add back the product_id column to products (pointing to legacy)
    add_column :products, :product_id, :bigint

    # Step 4: Rename tables back
    rename_table :products, :product_variants
    rename_table :products_legacy, :products

    # Step 5: Re-add foreign key constraints
    add_foreign_key :cart_items, :product_variants
    add_foreign_key :order_items, :product_variants
    add_foreign_key :reorder_schedule_items, :product_variants
    add_foreign_key :order_items, :products
    add_foreign_key :product_variants, :products
  end
end
