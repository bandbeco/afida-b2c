class PopulateVegwareBagsAndWrapsBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    collection = Collection.find_by(slug: "vegware")
    category = Category.find_by(slug: "bags-and-wraps", parent_id: nil)
    return unless collection && category

    guide = File.read(Rails.root.join("lib/data/collections/buying-guides/vegware/bags-and-wraps.md"))
    CollectionCategoryGuide.find_or_initialize_by(collection: collection, category: category)
                           .update!(buying_guide: guide)
  end

  def down
    collection = Collection.find_by(slug: "vegware")
    category = Category.find_by(slug: "bags-and-wraps", parent_id: nil)
    CollectionCategoryGuide.where(collection: collection, category: category).destroy_all
  end
end
