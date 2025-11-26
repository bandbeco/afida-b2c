class AddPacSizeToOrderItems < ActiveRecord::Migration[8.1]
  def change
    add_column :order_items, :pac_size, :integer
  end
end
