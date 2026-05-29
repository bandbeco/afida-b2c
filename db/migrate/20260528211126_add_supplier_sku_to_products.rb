class AddSupplierSkuToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :supplier_sku, :string
    add_index :products, :supplier_sku
  end
end
