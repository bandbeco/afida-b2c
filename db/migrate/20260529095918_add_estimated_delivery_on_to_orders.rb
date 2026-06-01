class AddEstimatedDeliveryOnToOrders < ActiveRecord::Migration[8.1]
  def change
    # The delivery date promised at purchase. A date (not a timestamp): the
    # promise is a calendar day. Nullable so legacy orders fall back to
    # computing from created_at.
    add_column :orders, :estimated_delivery_on, :date
  end
end
