class AddLabelToProductOptionValues < ActiveRecord::Migration[8.1]
  def change
    add_column :product_option_values, :label, :string
  end
end
