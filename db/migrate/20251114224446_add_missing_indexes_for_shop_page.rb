class AddMissingIndexesForShopPage < ActiveRecord::Migration[8.1]
  def change
    # Index on categories.slug for in_categories scope JOIN
    add_index :categories, :slug unless index_exists?(:categories, :slug)

    # Index on products.colour for search scope
    add_index :products, :colour

    # Index on products.position for default scope ordering
    add_index :products, :position unless index_exists?(:products, :position)
  end
end
