class PopulateStrawsBuyingGuide < ActiveRecord::Migration[8.0]
  def up
    Category.find_by(slug: "straws")&.update!(buying_guide: <<~MD)
      Disposable paper straws have become the standard for food service businesses since the UK banned single-use plastic straws in 2020. Whether you serve hot drinks, cocktails, smoothies, or bubble tea, choosing the right eco friendly straws means balancing durability, diameter, and material to match each drink on your menu.

      ## Key Factors to Consider

      ### Material and Composition

      Three main materials dominate the market for biodegradable drinking straws. Standard paper straws are the most affordable option and work well for most cold drinks. Bio fibre straws, made from plant-based fibres, offer significantly better resistance to sogginess; they hold their structure in liquid for hours rather than minutes. Bamboo pulp straws sit at the premium end, combining natural rigour with a smooth drinking experience. Your choice depends on how long drinks typically sit before being finished: quick-service environments do fine with paper, while dine-in cocktail bars benefit from bio fibre or bamboo pulp.

      ### Size and Diameter

      Straws are specified by two measurements: diameter (in millimetres) and length. A 6mm diameter is the standard for most cold drinks, hot beverages, and cocktails. Step up to 8mm for thicker smoothies and milkshakes, 10mm for extra-thick drinks, and 12mm for bubble tea where tapioca pearls need to pass through. Length matters too: 140mm cocktail straws suit short tumblers, 200mm fits standard highball glasses and takeaway cups, and 230mm accommodates tall cups or large bubble tea servings. Stocking two or three sizes covers most menus without cluttering your supplies.

      ### Specialty Options

      Beyond standard straight straws, consider whether your menu calls for any specialist types. Spoon straws combine a stirring function with a sipping end, ideal for slushies or frozen desserts. Angle-cut straws pierce sealed cup lids cleanly, which makes them popular for bubble tea and sealed takeaway drinks. Individually wrapped straws suit delivery and grab-and-go operations where hygiene perception matters. Each of these costs more per unit but solves a specific service problem.

      ### Sustainability and Compliance

      Since October 2020, single-use plastic straws have been banned in England, with similar legislation across the UK. All paper straws, bio fibre straws, and bamboo pulp straws are compostable and meet current regulations. If your waste goes to industrial composting, look for straws that comply with EN 13432 or carry OK Compost certification. Eco friendly paper straws also appeal to environmentally conscious customers, reinforcing your business's sustainability credentials without any operational compromise.

      ### Cost and Value

      Paper straws are the most cost-effective option, starting from around 1p per unit at bulk quantities of 5,000. Bio fibre straws run roughly 3p per unit, and bamboo pulp straws sit between 2p and 4p depending on diameter. For high-volume operations, the difference adds up quickly; a cafe serving 500 drinks per week saves over £500 annually by using paper straws instead of premium alternatives. Weigh that saving against the customer experience: if soggy straws generate complaints, the upgrade to bio fibre pays for itself in repeat business.

      ## Pro Tips

      - Match straw diameter to your cup lids. A 6mm straw will rattle loosely in a lid designed for 8mm, causing drips and a poor customer experience.
      - If paper straw sogginess is a concern but budget is tight, try bio fibre straws for dine-in service and keep paper straws for takeaway where drinks are consumed faster.
      - Store straws in a dry area away from steam and kitchen moisture. Paper and bio fibre straws absorb humidity before they ever touch a drink if stored poorly.
      - For delivery orders, individually wrapped straws add a small cost but prevent contamination complaints and look more professional.

      ## Summary

      Choosing the right paper straws for your business comes down to matching material, diameter, and length to the drinks you serve. Paper straws cover most needs at the lowest cost, while bio fibre and bamboo pulp options solve the sogginess problem for operations where drinks sit longer. Stock two or three sizes, match them to your cup lids, and store them properly to get the best performance from every pack.
    MD
  end

  def down
    Category.find_by(slug: "straws")&.update!(buying_guide: nil)
  end
end
