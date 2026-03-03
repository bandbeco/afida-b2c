class AddDiscountFieldsToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :discount_amount, :decimal, precision: 10, scale: 2, default: 0, null: false
    add_column :orders, :discount_code, :string
  end
end
