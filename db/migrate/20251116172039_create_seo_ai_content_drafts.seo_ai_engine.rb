# This migration comes from seo_ai_engine (originally 20251116160947)
class CreateSeoAiContentDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :seo_ai_content_drafts do |t|
      t.references :seo_ai_content_brief, null: false, foreign_key: true, index: { unique: true }
      t.string :content_type, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.string :meta_title
      t.string :meta_description
      t.string :target_keywords, array: true, default: []
      t.string :status, null: false, default: "pending_review"
      t.integer :quality_score
      t.jsonb :review_notes, default: {}
      t.string :reviewer_model
      t.decimal :generation_cost_gbp, precision: 10, scale: 4
      t.integer :reviewed_by_id
      t.datetime :reviewed_at

      t.timestamps
    end

    add_index :seo_ai_content_drafts, [ :status, :quality_score ]
  end
end
