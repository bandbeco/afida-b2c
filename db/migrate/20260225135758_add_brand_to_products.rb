class AddBrandToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :brand, :string
  end
end
