class CreateVariantOptionValues < ActiveRecord::Migration[8.1]
  def change
    create_table :variant_option_values do |t|
      t.references :product_variant, null: false, foreign_key: true
      t.references :product_option_value, null: false, foreign_key: true
      # Denormalized for constraint enforcement - copied from product_option_value on save
      t.references :product_option, null: false, foreign_key: true

      t.timestamps
    end

    # Prevent duplicate assignments of the same option value to a variant
    add_index :variant_option_values,
              [ :product_variant_id, :product_option_value_id ],
              unique: true,
              name: 'idx_variant_option_values_unique'

    # Enforce one value per option type per variant (key business rule)
    add_index :variant_option_values,
              [ :product_variant_id, :product_option_id ],
              unique: true,
              name: 'idx_variant_one_value_per_option'
  end
end
