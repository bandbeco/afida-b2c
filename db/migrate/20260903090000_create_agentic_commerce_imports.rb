class CreateAgenticCommerceImports < ActiveRecord::Migration[8.1]
  def change
    create_table :agentic_commerce_imports do |t|
      t.string :stripe_import_id, null: false
      t.string :feed_type, null: false
      t.string :mode, null: false
      t.integer :row_count, null: false, default: 0
      t.string :status, null: false
      t.text :error_summary
      t.jsonb :skus, null: false, default: []

      t.timestamps
    end

    add_index :agentic_commerce_imports, :stripe_import_id, unique: true
    add_index :agentic_commerce_imports, [ :feed_type, :created_at ]
  end
end
