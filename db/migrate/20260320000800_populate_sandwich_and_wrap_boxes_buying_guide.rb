class PopulateSandwichAndWrapBoxesBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    buying_guide = File.read(Rails.root.join("lib/data/buying-guides/sandwich-and-wrap-boxes.md"))
    Category.find_by(slug: "sandwich-and-wrap-boxes")&.update!(buying_guide: buying_guide)
  end

  def down
    Category.find_by(slug: "sandwich-and-wrap-boxes")&.update!(buying_guide: nil)
  end
end
