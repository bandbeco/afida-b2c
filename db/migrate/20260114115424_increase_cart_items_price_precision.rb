class IncreaseCartItemsPricePrecision < ActiveRecord::Migration[8.1]
  def change
    # Increase precision to match branded_product_prices.price_per_unit (scale: 4)
    # This allows storing unit prices like £0.1234 without rounding
    change_column :cart_items, :price, :decimal, precision: 10, scale: 4, null: false
  end
end
