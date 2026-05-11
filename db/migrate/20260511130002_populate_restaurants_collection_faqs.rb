class PopulateRestaurantsCollectionFaqs < ActiveRecord::Migration[8.1]
  def up
    faqs = YAML.load_file(Rails.root.join("lib/data/collections/faqs/restaurants.yml"))
    Collection.find_by(slug: "restaurants")&.update!(faqs: faqs)
  end

  def down
    Collection.find_by(slug: "restaurants")&.update!(faqs: [])
  end
end
