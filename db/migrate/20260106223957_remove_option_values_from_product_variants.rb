class RemoveOptionValuesFromProductVariants < ActiveRecord::Migration[8.1]
  def change
    # Remove JSONB column - data now lives in variant_option_values join table
    # This is irreversible since we're using re-seed approach (pre-launch site)
    remove_column :product_variants, :option_values, :jsonb
  end
end
