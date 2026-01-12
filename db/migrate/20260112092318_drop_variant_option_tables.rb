class DropVariantOptionTables < ActiveRecord::Migration[8.1]
  def up
    # Drop tables in dependency order (join tables first)
    drop_table :variant_option_values, if_exists: true
    drop_table :product_option_assignments, if_exists: true
    drop_table :product_option_values, if_exists: true
    drop_table :product_options, if_exists: true
  end

  def down
    # Recreate product_options table
    create_table :product_options do |t|
      t.string :name, null: false
      t.string :display_type, default: "dropdown"
      t.integer :position, default: 0
      t.timestamps
    end

    # Recreate product_option_values table
    create_table :product_option_values do |t|
      t.references :product_option, null: false, foreign_key: true
      t.string :value, null: false
      t.string :label
      t.integer :position, default: 0
      t.timestamps
    end

    # Recreate product_option_assignments table
    create_table :product_option_assignments do |t|
      t.references :product, null: false, foreign_key: true
      t.references :product_option, null: false, foreign_key: true
      t.integer :position, default: 0
      t.timestamps
    end

    # Recreate variant_option_values table
    create_table :variant_option_values do |t|
      t.bigint :product_variant_id, null: false
      t.references :product_option_value, null: false, foreign_key: true
      t.references :product_option, null: false, foreign_key: true
      t.timestamps
    end

    add_foreign_key :variant_option_values, :products, column: :product_variant_id
  end
end
