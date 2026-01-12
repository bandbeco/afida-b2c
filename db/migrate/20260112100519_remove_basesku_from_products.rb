class RemoveBaseskuFromProducts < ActiveRecord::Migration[8.1]
  def change
    remove_column :products, :base_sku, :string
  end
end
