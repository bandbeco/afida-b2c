class PopulateGreaseproofAndWrapsBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    buying_guide = File.read(Rails.root.join("lib/data/buying-guides/greaseproof-and-wraps.md"))
    Category.find_by(slug: "greaseproof-and-wraps")&.update!(buying_guide: buying_guide)
  end

  def down
    Category.find_by(slug: "greaseproof-and-wraps")&.update!(buying_guide: nil)
  end
end
