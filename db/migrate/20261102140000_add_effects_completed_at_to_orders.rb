class AddEffectsCompletedAtToOrders < ActiveRecord::Migration[8.1]
  # Nullable so a newly committed order can exist before its effects finish.
  # Existing rows are marked with created_at in the same migration: they
  # already had their emails and events (or predate this marker), and a nil
  # would make the new code send them again on the next completion channel.
  def up
    add_column :orders, :effects_completed_at, :datetime
    self.class.backfill
  end

  def down
    remove_column :orders, :effects_completed_at
  end

  def self.backfill
    ActiveRecord::Base.connection.exec_update(<<~SQL.squish)
      UPDATE orders
      SET effects_completed_at = created_at
      WHERE effects_completed_at IS NULL
    SQL
  end
end
