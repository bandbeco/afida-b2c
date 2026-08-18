# The customer's billing address, collected at Stripe Checkout via
# billing_address_collection: "required" (Checkout::SessionBuilder) and read
# from the completed session's customer_details. Nullable and NOT validated for
# presence, unlike the shipping_* columns: orders created before this feature
# have none, and some sessions (Link/wallet reuse, zero-total
# no_payment_required) may legitimately return no billing address. A missing
# billing address must never block order creation - see
# Checkout::SessionDetails.billing_address.
class AddBillingAddressToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :billing_name, :string
    add_column :orders, :billing_address_line1, :string
    add_column :orders, :billing_address_line2, :string
    add_column :orders, :billing_city, :string
    add_column :orders, :billing_postal_code, :string
    add_column :orders, :billing_country, :string
  end
end
