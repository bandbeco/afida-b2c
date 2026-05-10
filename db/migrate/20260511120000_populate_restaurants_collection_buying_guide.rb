class PopulateRestaurantsCollectionBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    buying_guide = File.read(Rails.root.join("lib/data/collections/buying-guides/restaurants.md"))
    Collection.find_by(slug: "restaurants")&.update!(buying_guide: buying_guide)
  end

  def down
    Collection.find_by(slug: "restaurants")&.update!(buying_guide: nil)
  end
end
