class AddSampleFieldsToProductVariants < ActiveRecord::Migration[8.1]
  def change
    add_column :product_variants, :sample_eligible, :boolean, default: false, null: false
    add_column :product_variants, :sample_sku, :string

    add_index :product_variants, :sample_eligible
  end
end
