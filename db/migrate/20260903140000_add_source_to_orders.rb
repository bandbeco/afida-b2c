class AddSourceToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :source, :string, null: false, default: "web"
    add_index :orders, :source
    add_column :orders, :agent_name, :string
  end
end
