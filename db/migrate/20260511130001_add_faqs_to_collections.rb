class AddFaqsToCollections < ActiveRecord::Migration[8.1]
  def change
    add_column :collections, :faqs, :jsonb, default: []
  end
end
