class AddCostToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :cost, :decimal, precision: 10, scale: 2
  end
end
