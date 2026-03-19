class AddBuyingGuideToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :buying_guide, :text
  end
end
