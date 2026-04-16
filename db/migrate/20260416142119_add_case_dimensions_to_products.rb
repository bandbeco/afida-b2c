class AddCaseDimensionsToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :case_length_in_mm, :integer
    add_column :products, :case_width_in_mm, :integer
    add_column :products, :case_depth_in_mm, :integer
    add_column :products, :case_weight_in_g, :integer
  end
end
