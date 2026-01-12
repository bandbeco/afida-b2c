class RemoveShortDescriptionFromProducts < ActiveRecord::Migration[8.1]
  def change
    remove_column :products, :short_description, :text
  end
end
