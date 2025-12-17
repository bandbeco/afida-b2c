class AddAddressFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :default_shipping_address, :jsonb, default: {}, null: false
    add_column :users, :default_billing_address, :jsonb, default: {}, null: false
  end
end
