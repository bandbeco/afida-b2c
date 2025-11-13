class CreateLegacyRedirects < ActiveRecord::Migration[8.1]
  def up
    create_table :legacy_redirects do |t|
      t.string :legacy_path, limit: 500, null: false
      t.string :target_slug, limit: 255, null: false
      t.jsonb :variant_params, default: {}, null: false
      t.integer :hit_count, default: 0, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    # Functional index for case-insensitive lookups
    add_index :legacy_redirects, 'LOWER(legacy_path)', unique: true, name: 'index_legacy_redirects_on_lower_legacy_path'

    # Index for filtering active redirects
    add_index :legacy_redirects, :active

    # Index for analytics queries (most used redirects)
    add_index :legacy_redirects, :hit_count
  end

  def down
    drop_table :legacy_redirects
  end
end
