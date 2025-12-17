class AddSearchAndFilterIndexesToProducts < ActiveRecord::Migration[8.1]
  def change
    # Category filtering (add if not already indexed)
    add_index :products, :category_id unless index_exists?(:products, :category_id)

    # Search by name
    add_index :products, :name unless index_exists?(:products, :name)

    # Search by SKU
    add_index :products, :sku unless index_exists?(:products, :sku)

    # Composite index for common filter: active products in category
    add_index :products, [ :active, :category_id ] unless index_exists?(:products, [ :active, :category_id ])
  end
end
