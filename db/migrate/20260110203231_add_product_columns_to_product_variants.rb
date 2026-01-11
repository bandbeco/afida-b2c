class AddProductColumnsToProductVariants < ActiveRecord::Migration[8.1]
  def change
    # Add foreign keys
    add_reference :product_variants, :category, foreign_key: true
    add_reference :product_variants, :product_family, foreign_key: true

    # Add product type enum (stored as string in Rails 7+)
    add_column :product_variants, :product_type, :string, default: "standard"

    # Add description fields
    add_column :product_variants, :description_short, :text
    add_column :product_variants, :description_standard, :text
    add_column :product_variants, :description_detailed, :text

    # Add SEO fields
    add_column :product_variants, :meta_title, :string
    add_column :product_variants, :meta_description, :text

    # Add display/filtering fields from Product
    add_column :product_variants, :b2b_priority, :string
    add_column :product_variants, :best_seller, :boolean, default: false
    add_column :product_variants, :featured, :boolean, default: false
    add_column :product_variants, :material, :string
    add_column :product_variants, :colour, :string
    add_column :product_variants, :base_sku, :string
    add_column :product_variants, :short_description, :text
    add_column :product_variants, :vat_rate, :decimal, precision: 6, scale: 4

    # Add organization reference (for B2B)
    add_reference :product_variants, :organization, foreign_key: true

    # Add parent product reference (for customized instances)
    add_column :product_variants, :parent_product_id, :bigint

    # Add sort order (position already exists as 'position')
    # Rename position to sort_order for consistency
    # Actually, both have 'position' so we can keep it

    # Add indexes for common queries
    add_index :product_variants, :product_type
    add_index :product_variants, :best_seller
    add_index :product_variants, :featured
  end
end
