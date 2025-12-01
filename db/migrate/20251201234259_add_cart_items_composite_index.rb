# Adds composite index for faster duplicate checks and sample queries
# Used by uniqueness validation, create_sample_cart_item, and create_standard_cart_item
class AddCartItemsCompositeIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :cart_items, [ :cart_id, :product_variant_id ],
              name: "index_cart_items_on_cart_id_and_product_variant_id"
  end
end
