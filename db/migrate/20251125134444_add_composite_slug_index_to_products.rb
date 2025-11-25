class AddCompositeSlugIndexToProducts < ActiveRecord::Migration[8.1]
  def change
    # Remove the old unique index on slug alone
    remove_index :products, :slug, unique: true

    # Add composite unique index on [slug, product_type]
    add_index :products, [ :slug, :product_type ], unique: true, name: "index_products_on_slug_and_product_type"
  end
end
