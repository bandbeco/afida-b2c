class AddSubscriptionToOrders < ActiveRecord::Migration[8.1]
  def change
    add_reference :orders, :subscription, null: true, foreign_key: true
  end
end
