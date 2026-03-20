class PopulateGlovesAndCleaningBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    buying_guide = File.read(Rails.root.join("lib/data/buying-guides/gloves-and-cleaning.md"))
    Category.find_by(slug: "gloves-and-cleaning")&.update!(buying_guide: buying_guide)
  end

  def down
    Category.find_by(slug: "gloves-and-cleaning")&.update!(buying_guide: nil)
  end
end
