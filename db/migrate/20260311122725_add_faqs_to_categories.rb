class AddFaqsToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :faqs, :jsonb, default: []
  end
end
