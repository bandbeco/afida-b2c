class AddIndexOnAddressesUserLine1Postcode < ActiveRecord::Migration[8.1]
  def change
    # Composite index for duplicate address detection in User#has_matching_address?
    add_index :addresses, [ :user_id, :line1, :postcode ],
              name: "index_addresses_on_user_line1_postcode"
  end
end
