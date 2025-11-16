# This migration comes from seo_ai_engine (originally 20251116160950)
class CreateSeoAiBudgetTracking < ActiveRecord::Migration[8.1]
  def change
    create_table :seo_ai_budget_trackings do |t|
      t.date :month, null: false
      t.integer :gsc_requests, default: 0
      t.integer :serpapi_requests, default: 0
      t.integer :llm_requests, default: 0
      t.decimal :llm_cost_gbp, precision: 10, scale: 2, default: 0
      t.decimal :serpapi_cost_gbp, precision: 10, scale: 2, default: 0
      t.decimal :total_cost_gbp, precision: 10, scale: 2, default: 0
      t.integer :content_pieces_generated, default: 0
      t.decimal :avg_cost_per_piece, precision: 10, scale: 2

      t.timestamps
    end

    add_index :seo_ai_budget_trackings, :month, unique: true
  end
end
