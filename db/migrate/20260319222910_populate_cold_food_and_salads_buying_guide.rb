class PopulateColdFoodAndSaladsBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    buying_guide = <<~MARKDOWN
      Cold food packaging covers everything from salad boxes and deli pots to sandwich and wrap containers. Getting your cold food packaging right keeps grab-and-go items fresh, presentable, and easy to transport, all of which directly affect whether customers come back.

      ## Key Factors to Consider

      ### Material and Composition

      The most common materials for cold food packaging are PLA (a plant-based clear plastic alternative), rPET (recycled plastic), kraft cardboard, and bagasse (sugarcane fibre). PLA and rPET offer excellent clarity, letting customers see the contents, which is particularly important for salad boxes where visual appeal drives purchases. Kraft card is a strong, natural-looking option that works well for sandwich packaging and wrap boxes. Bagasse is rigid, grease-resistant, and fully compostable, making it a solid all-rounder for deli pots and food containers with lids.

      ### Size and Capacity

      Salad boxes typically range from 500ml to 1,000ml. A 750ml container suits most individual meal-sized salads, while smaller deli pots in the 8oz to 16oz range work well for sides, dips, and grain bowls. Sandwich packaging needs to accommodate different formats: wedge boxes for triangular-cut sandwiches, longer containers for wraps and baguettes, and platter boxes for catering. Ordering a mix of sizes lets you cover your full menu without forcing food into containers that are too large or too tight.

      ### Temperature and Use Case

      All materials in this category are designed for cold and ambient foods, but not all handle moisture equally. Salads with heavy dressings or juicy fruits need leak-proof containers with secure lids. Kraft containers can soften over time when in contact with wet ingredients, so look for options with a PLA or wax lining if your menu includes dressed salads. If you need freezer-to-display flexibility for pre-made items, check that the packaging is rated for freezer use; PLA can become brittle at very low temperatures.

      ### Sustainability and Compliance

      Compostable food packaging is now a baseline expectation for many customers, not a differentiator. PLA, bagasse, and unlined kraft are all commercially compostable, but only if your local waste infrastructure supports it. Look for OK Compost or BPI certification to verify claims. Be aware of evolving single-use plastic regulations; rPET is recyclable but may fall under plastic packaging restrictions in some regions. PFAS-free certification is increasingly important for any food-contact packaging, so confirm this with your supplier.

      ### Cost and Value

      Kraft and bagasse containers are generally the most cost-effective options per unit. PLA and rPET sit at a slight premium, justified when product visibility matters, as it does for disposable salad bowls and layered salads. Buying in case quantities of 300 to 500 units brings meaningful savings. Consider total cost rather than unit price alone: a container with an integrated hinged lid eliminates the separate lid purchase and speeds up service.

      ### Branding and Presentation

      Cold food is often displayed in cabinets or fridges where customers browse visually. Clear-lidded containers let the food sell itself, while branded kraft boxes with your logo create a premium, artisan feel that works well for sandwich packaging. Custom printing is available on most kraft and bagasse lines, typically from 1,000 units. Sticker labels are a lower-commitment alternative for smaller operations wanting a branded look.

      ## Pro Tips

      - Order samples of your top two or three container options and pack them with your actual menu items. Fit, leak resistance, and presentation vary more than spec sheets suggest.
      - If you use hinged-lid containers, test the hinge durability by opening and closing it 20 times; weak hinges crack in transit and frustrate customers.
      - For catering and platters, choose containers with flat, stackable lids to simplify delivery logistics.
      - Check that your containers fit your display fridge shelves before committing to a bulk order. An oversized salad box that does not fit your cabinet is wasted stock.

      ## Summary

      The right cold food packaging balances visibility, durability, and sustainability for your specific menu and service style. Start with your highest-volume items, whether that is salad boxes, sandwich containers, or deli pots, and select materials that keep those products looking fresh through to the moment your customer opens them. Practical testing with real food always beats guessing from a product description.
    MARKDOWN

    Category.find_by(slug: "cold-food-and-salads")&.update!(buying_guide: buying_guide)
  end

  def down
    Category.find_by(slug: "cold-food-and-salads")&.update!(buying_guide: nil)
  end
end
