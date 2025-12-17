class AddReorderScheduleIdToOrders < ActiveRecord::Migration[8.1]
  def change
    add_reference :orders, :reorder_schedule, foreign_key: true, index: true
  end
end
