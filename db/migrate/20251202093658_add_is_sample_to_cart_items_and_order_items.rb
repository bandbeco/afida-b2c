class AddIsSampleToCartItemsAndOrderItems < ActiveRecord::Migration[8.1]
  def change
    add_column :cart_items, :is_sample, :boolean, default: false, null: false
    add_column :order_items, :is_sample, :boolean, default: false, null: false

    add_index :cart_items, :is_sample
    add_index :order_items, :is_sample
  end
end
