class AddUniqueIndexOnDefaultAddress < ActiveRecord::Migration[8.1]
  def change
    # Partial unique index: ensures only ONE default address per user
    # This prevents race conditions in ensure_single_default callback
    add_index :addresses, :user_id,
              unique: true,
              where: '"default" = true',
              name: "index_addresses_on_user_id_where_default"
  end
end
