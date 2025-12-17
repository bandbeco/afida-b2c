class AddStripeCustomerIdToUsers < ActiveRecord::Migration[8.1]
  def change
    # Column already exists from prior subscription work
    unless column_exists?(:users, :stripe_customer_id)
      add_column :users, :stripe_customer_id, :string
    end

    unless index_exists?(:users, :stripe_customer_id)
      add_index :users, :stripe_customer_id, unique: true
    end
  end
end
