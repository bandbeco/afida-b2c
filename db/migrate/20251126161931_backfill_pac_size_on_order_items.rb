class BackfillPacSizeOnOrderItems < ActiveRecord::Migration[8.1]
  def up
    # Backfill pac_size from product_variants for historical orders
    # Only updates non-configured items (standard products) that have a product_variant
    execute <<-SQL
      UPDATE order_items
      SET pac_size = product_variants.pac_size
      FROM product_variants
      WHERE order_items.product_variant_id = product_variants.id
        AND order_items.pac_size IS NULL
        AND (order_items.configuration IS NULL OR order_items.configuration = '{}')
        AND product_variants.pac_size IS NOT NULL
    SQL
  end

  def down
    # No need to undo - preserving historical data is safe
  end
end
