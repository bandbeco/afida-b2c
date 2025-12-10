class AddGa4TrackingToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :ga4_purchase_tracked_at, :datetime
  end
end
