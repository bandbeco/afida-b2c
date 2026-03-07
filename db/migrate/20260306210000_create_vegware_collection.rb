class CreateVegwareCollection < ActiveRecord::Migration[8.1]
  def up
    vegware = Collection.find_or_create_by!(slug: "vegware") do |c|
      c.name = "Vegware"
      c.description = "Browse our full range of Vegware plant-based, compostable packaging. Certified to EN 13432."
      c.meta_title = "Vegware Eco-Friendly Packaging"
      c.meta_description = "Browse our full range of Vegware plant-based compostable packaging products. Cups, containers, cutlery, napkins and more."
      c.featured = true
      c.sample_pack = false
      c.position = Collection.maximum(:position).to_i + 1
    end

    vegware_products = Product.where(brand: "Vegware").active
    vegware_products.find_each.with_index(1) do |product, index|
      CollectionItem.find_or_create_by!(collection: vegware, product: product) do |ci|
        ci.position = index
      end
    end

    say "Created Vegware collection with #{vegware.collection_items.count} products"
  end

  def down
    vegware = Collection.find_by(slug: "vegware")
    if vegware
      vegware.collection_items.destroy_all
      vegware.destroy!
      say "Removed Vegware collection"
    end
  end
end
