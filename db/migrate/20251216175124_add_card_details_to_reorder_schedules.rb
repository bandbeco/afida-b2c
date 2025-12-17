class AddCardDetailsToReorderSchedules < ActiveRecord::Migration[8.1]
  def change
    add_column :reorder_schedules, :card_brand, :string
    add_column :reorder_schedules, :card_last4, :string
  end
end
