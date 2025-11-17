class RenameKeywordToQueryInOpportunities < ActiveRecord::Migration[8.1]
  def change
    rename_column :seo_ai_opportunities, :keyword, :query
  end
end
