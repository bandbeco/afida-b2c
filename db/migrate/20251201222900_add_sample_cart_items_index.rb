# Adds composite index for faster sample queries
# Used by Cart#sample_items, Cart#sample_count, and uniqueness validation
class AddSampleCartItemsIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :cart_items, [ :cart_id, :price ], name: "index_cart_items_on_cart_id_and_price"
  end
end
