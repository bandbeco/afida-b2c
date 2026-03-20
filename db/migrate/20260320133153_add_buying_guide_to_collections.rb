class AddBuyingGuideToCollections < ActiveRecord::Migration[8.1]
  def change
    add_column :collections, :buying_guide, :text
  end
end
