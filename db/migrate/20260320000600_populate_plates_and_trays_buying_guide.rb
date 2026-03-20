class PopulatePlatesAndTraysBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    buying_guide = File.read(Rails.root.join("lib/data/buying-guides/plates-and-trays.md"))
    Category.find_by(slug: "plates-and-trays")&.update!(buying_guide: buying_guide)
  end

  def down
    Category.find_by(slug: "plates-and-trays")&.update!(buying_guide: nil)
  end
end
