class AddSizeToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :size, :string
  end
end
