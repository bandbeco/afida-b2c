# This migration comes from seo_ai_engine (originally 20251116160942)
class CreateSeoAiContentBriefs < ActiveRecord::Migration[8.1]
  def change
    create_table :seo_ai_content_briefs do |t|
      t.references :seo_ai_opportunity, null: false, foreign_key: true, index: { unique: true }
      t.string :target_keyword, null: false
      t.string :search_intent
      t.jsonb :suggested_structure, default: {}
      t.jsonb :competitor_analysis, default: {}
      t.jsonb :product_links, default: {}
      t.jsonb :internal_links, default: {}
      t.string :created_by_model
      t.decimal :generation_cost_gbp, precision: 10, scale: 4

      t.timestamps
    end
  end
end
