# This migration comes from seo_ai_engine (originally 20251116160948)
class CreateSeoAiContentItems < ActiveRecord::Migration[8.1]
  def change
    create_table :seo_ai_content_items do |t|
      t.references :seo_ai_content_draft, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.string :meta_title
      t.string :meta_description
      t.string :target_keywords, array: true, default: []
      t.datetime :published_at, null: false
      t.string :author_credit, default: "Afida Editorial Team"
      t.integer :related_product_ids, array: true, default: []
      t.integer :related_category_ids, array: true, default: []

      t.timestamps
    end

    add_index :seo_ai_content_items, :slug, unique: true
    add_index :seo_ai_content_items, :published_at
  end
end
