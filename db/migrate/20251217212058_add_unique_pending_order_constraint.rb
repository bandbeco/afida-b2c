# frozen_string_literal: true

class AddUniquePendingOrderConstraint < ActiveRecord::Migration[8.0]
  def change
    # Prevent duplicate pending orders for the same schedule and date
    # This guards against race conditions when multiple Solid Queue workers
    # run CreatePendingOrdersJob concurrently
    #
    # Only enforced for pending status (0) since confirmed/expired orders
    # should not block new pending orders for the same date
    add_index :pending_orders,
              [ :reorder_schedule_id, :scheduled_for ],
              unique: true,
              where: "status = 0",
              name: "index_pending_orders_unique_pending_per_schedule"
  end
end
