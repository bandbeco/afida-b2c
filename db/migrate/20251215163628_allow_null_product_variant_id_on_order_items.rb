class AllowNullProductVariantIdOnOrderItems < ActiveRecord::Migration[8.1]
  def change
    # Allow product_variant_id to be null for renewal orders where the variant
    # may no longer exist or the snapshot contains all needed data
    change_column_null :order_items, :product_variant_id, true
    change_column_null :order_items, :product_id, true
  end
end
