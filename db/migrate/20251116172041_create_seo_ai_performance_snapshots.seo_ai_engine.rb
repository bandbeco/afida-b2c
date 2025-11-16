# This migration comes from seo_ai_engine (originally 20251116160949)
class CreateSeoAiPerformanceSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :seo_ai_performance_snapshots do |t|
      t.references :seo_ai_content_item, foreign_key: true
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.integer :impressions, default: 0
      t.integer :clicks, default: 0
      t.decimal :avg_position, precision: 5, scale: 2
      t.decimal :ctr, precision: 5, scale: 4
      t.jsonb :keyword_positions, default: {}
      t.decimal :traffic_value_gbp, precision: 10, scale: 2

      t.timestamps
    end

    add_index :seo_ai_performance_snapshots, [ :seo_ai_content_item_id, :period_end ]
    add_index :seo_ai_performance_snapshots, :period_end
  end
end
