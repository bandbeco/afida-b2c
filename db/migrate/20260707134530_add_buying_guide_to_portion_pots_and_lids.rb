class AddBuyingGuideToPortionPotsAndLids < ActiveRecord::Migration[8.1]
  def up
    guide = <<~MARKDOWN
      Portion pots, also sold as sauce pots or dip pots, are the smallest containers on the counter and the easiest to get wrong. This category runs from 1oz (28ml) condiment pots to 199ml leakproof paper pots, in clear, kraft, paper, PLA and bagasse, with the matching lids. Because they ship in cases of thousands, a little thought before ordering saves a shelf of mismatched stock.

      ## Key Factors to Consider

      ### Material & Composition

      Clear pots show the sauce and let staff grab the right one fast. Kraft and paper pots match kraft bowls and boxes for a consistent bag, and souffle paper pots are the classic chip-shop style. Bagasse pots with their own lids give you a fully fibre, plastic-free unit, while PLA pots offer plant-based clarity for cold fillings. Lids follow the same split: clear, kraft paper or PLA.

      ### Size & Capacity

      1oz (28ml) is a single shot of ketchup, mayo or chilli oil; 2oz (57ml) is the standard dip size; 3oz to 4oz (85ml to 114ml) suits generous dips, olives and toppings; and the larger 142ml to 199ml pots handle dressings, small sides and dessert extras. Most menus only need two sizes, one condiment pot and one dip pot, and standardising keeps ordering simple.

      ### Temperature & Use Case

      Match the pot to the sauce temperature. PLA cold pots are strictly for cold fillings, while paper, souffle and bagasse pots take hot gravies, curry sauces and jus. For anything wet travelling on a delivery bike, the leakproof paper pots with lids exist for exactly that job.

      ### Lid Compatibility

      Fit follows rim diameter, not capacity, and one lid often spans several pot sizes: a single 62mm paper lid covers the 2oz, 3oz and 4oz paper pots, and one clear lid covers a whole run of clear pot sizes. Check the sizes listed on the lid product page and order pots and lids together, keeping the ratio one to one.

      ### Sustainability & Compliance

      Single-use plastic rules and the plastic packaging tax put pressure on conventional clear pots. Bagasse and paper pots with paper or PLA lids get you to a fully fibre or plant-based unit; PLA is certified for commercial composting rather than home composting. If dips define your menu, the pot is a cheap, visible place to make an eco claim you can stand behind.

      ### Cost & Value

      Cases run from a few hundred to 5,000 units and prices start at about a penny per pot, so per-unit cost matters less than picking the right size: an oversized pot wastes sauce on every single order, which quickly outcosts the packaging. Where pots and lids are sold separately, cost them as a pair.

      ## Pro Tips

      - Standardise on one or two pot diameters across the menu so a single lid stock covers everything you serve.
      - Read the lid listing for the pot sizes it fits; diameter decides fit, and capacity labels can mislead.
      - Use leakproof paper pots for delivery orders; a leaked dressing is the fastest way to a one-star review.
      - Portion control is the hidden saving: trial the 2oz pot before defaulting to 4oz for dips.

      ## Summary

      Pick portion pots by sauce temperature and portion size first, then standardise diameters so lids stay simple. Two well-chosen sizes of sauce pot with matching lids will cover condiments, dips and sides for most kitchens, at case prices that make experimentation cheap.
    MARKDOWN

    Category.find_by(slug: "portion-pots-and-lids")&.update!(
      buying_guide: guide,
      meta_title: "Portion Pots & Lids | Sauce Pots Wholesale UK | Afida",
      meta_description: "Sauce pots, dip pots and portion cups with lids, by the case. Compostable options for takeaways and delis. Free UK delivery over £100."
    )
  end

  def down
    # Meta fields are not restored: the pre-migration values were not recorded.
    Category.find_by(slug: "portion-pots-and-lids")&.update!(buying_guide: nil)
  end
end
