class AddManufacturerSkuToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :manufacturer_sku, :string
    add_index :products, :manufacturer_sku
  end
end
