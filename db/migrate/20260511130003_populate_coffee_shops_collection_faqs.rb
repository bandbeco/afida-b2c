class PopulateCoffeeShopsCollectionFaqs < ActiveRecord::Migration[8.1]
  def up
    faqs = YAML.load_file(Rails.root.join("lib/data/collections/faqs/coffee-shops.yml"))
    Collection.find_by(slug: "coffee-shops")&.update!(faqs: faqs)
  end

  def down
    Collection.find_by(slug: "coffee-shops")&.update!(faqs: [])
  end
end
