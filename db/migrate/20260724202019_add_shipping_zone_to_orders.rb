# The delivery zone the order was priced and promised against, frozen at
# purchase time for the same reason estimated_delivery_on is: it records what the
# customer was actually charged and told, so a later change to the zone table or
# the DPD rate card can never rewrite the history of a shipped order.
#
# Nullable, and deliberately not backfilled: orders placed before zone pricing
# existed were charged mainland rates whatever their destination, so recording a
# zone for them would misstate what happened. Order#delivery_zone derives from
# shipping_postal_code when the column is blank, which keeps those orders
# readable without rewriting them.
class AddShippingZoneToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :shipping_zone, :string
  end
end
