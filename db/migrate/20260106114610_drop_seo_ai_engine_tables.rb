class DropSeoAiEngineTables < ActiveRecord::Migration[8.1]
  def up
    # Drop in order to respect foreign key constraints
    drop_table :seo_ai_performance_snapshots, if_exists: true
    drop_table :seo_ai_content_items, if_exists: true
    drop_table :seo_ai_content_drafts, if_exists: true
    drop_table :seo_ai_content_briefs, if_exists: true
    drop_table :seo_ai_opportunities, if_exists: true
    drop_table :seo_ai_budget_trackings, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot recreate SEO AI Engine tables - engine has been removed"
  end
end
