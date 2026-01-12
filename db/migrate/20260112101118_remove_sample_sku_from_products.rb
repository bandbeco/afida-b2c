class RemoveSampleSkuFromProducts < ActiveRecord::Migration[8.1]
  def change
    remove_column :products, :sample_sku, :string
  end
end
