# This migration comes from seo_ai_engine (originally 20251116160916)
class CreateSeoAiOpportunities < ActiveRecord::Migration[8.1]
  def change
    create_table :seo_ai_opportunities do |t|
      t.string :keyword, null: false
      t.string :opportunity_type, null: false
      t.integer :score, null: false
      t.integer :search_volume
      t.integer :current_position
      t.string :competition_difficulty
      t.string :target_url
      t.jsonb :metadata, default: {}
      t.string :status, null: false, default: "pending"
      t.datetime :discovered_at, null: false

      t.timestamps
    end

    add_index :seo_ai_opportunities, :keyword, unique: true
    add_index :seo_ai_opportunities, :opportunity_type
    add_index :seo_ai_opportunities, :score
    add_index :seo_ai_opportunities, :status
    add_index :seo_ai_opportunities, :discovered_at
    add_index :seo_ai_opportunities, [ :status, :score ]
  end
end
