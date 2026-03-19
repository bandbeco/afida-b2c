class PopulateTablewareBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    buying_guide = <<~MARKDOWN
      Disposable tableware covers the plates, bowls, cutlery, napkins, and containers that keep food service running without the need for washing up. Choosing the right mix of disposable tableware for your operation affects service speed, presentation, and your bottom line.

      ## Key Factors to Consider

      ### Material and Composition

      Disposable plates and bowls come in a range of materials, each suited to different situations. Polystyrene foam is lightweight and insulating but increasingly restricted by single-use plastic regulations. Paper and cardboard options are affordable and widely recyclable, though they struggle with wet or oily foods unless coated. Bagasse, made from sugarcane fibre, offers a sturdy, compostable alternative that handles heat and moisture well. For cutlery, polypropylene remains the most common choice due to its strength and low cost, while wooden and PLA alternatives cater to operations that need plastic-free options.

      ### Size and Capacity

      Plates typically come in 7-inch (side plate), 9-inch (standard), and 10-inch (dinner) sizes. Bowls range from small 8oz dessert portions to larger 32oz options suitable for salads or pasta. Match your sizes to your menu rather than stocking every option; a 9-inch plate and a 12oz bowl cover most food service scenarios. For cutlery, standard-weight pieces suit casual dining and takeaway, while heavy-duty options are better for sit-down events where guests expect a more substantial feel.

      ### Temperature and Use Case

      Not all disposable tableware handles heat equally. Bagasse and moulded fibre plates are microwave-safe and tolerate temperatures up to around 220 degrees Celsius, making them suitable for reheating. Foam and standard plastic plates deform under high heat. If your menu includes hot, saucy, or greasy items, choose materials rated for those conditions. Aluminium containers are excellent for oven-to-table service and can move between freezer and oven without cracking.

      ### Sustainability and Compliance

      Regulations around single-use plastics are tightening across the UK and EU. Many local authorities now restrict polystyrene food containers, and PFAS-free requirements are becoming standard for food-contact materials. Compostable tableware certified to EN 13432 or carrying the OK Compost mark meets most current compliance requirements. If you market your operation as eco-friendly, these certifications give your claims credibility. Paper napkins and wooden cutlery are naturally biodegradable, making them straightforward choices where sustainability is a priority.

      ### Cost and Value

      Paper plates and basic plastic cutlery are the cheapest per unit, but cost should factor in the full picture. Flimsy plates that bend under a burger or forks that snap on first use create waste and frustrate customers. Spending slightly more on bagasse plates or heavy-duty cutlery often reduces the number of items used per serving. Buying catering tableware in bulk, typically cases of 500 to 1,000 units, unlocks meaningful discounts. Balance case sizes against your storage space and how quickly you turn through stock.

      ### Branding and Presentation

      Eco-friendly tableware in natural kraft or white finishes signals quality without custom printing. For operations that want branded tableware, printed napkins are the most cost-effective starting point, with minimum orders often as low as 5,000 units. Plates and bowls can also be custom-printed, though minimums are higher. Coordinating your tableware colours and materials across plates, bowls, cutlery, and napkins creates a cohesive look that elevates the dining experience, even at a street food stall.

      ## Pro Tips

      - Order samples across material types before committing; a plate that looks great empty can flex or leak once loaded with food.
      - Check that your cutlery is strong enough for your menu. If it cannot cut through a sausage cleanly, your customers will notice.
      - Stock compostable and conventional options separately and label them clearly, as mixing them contaminates both waste streams.
      - Buy napkins in a colour that complements your plates rather than defaulting to white; it is a low-cost way to lift presentation.

      ## Summary

      The right disposable tableware balances durability, cost, and appearance for the way you serve food. Start with the material that suits your menu and compliance needs, then build out a coordinated range of plates, cutlery, and napkins that works as a set. Getting this right means faster service, less waste, and a better impression on every customer.
    MARKDOWN

    Category.find_by(slug: "tableware")&.update!(buying_guide: buying_guide)
  end

  def down
    Category.find_by(slug: "tableware")&.update!(buying_guide: nil)
  end
end
