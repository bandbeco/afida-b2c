class PopulateIceCreamCupsBuyingGuide < ActiveRecord::Migration[8.0]
  def up
    Category.find_by(slug: "ice-cream-cups")&.update!(buying_guide: <<~MD)
      Whether you run a gelato counter, a frozen yogurt bar, or a dessert catering operation, the ice cream cups you choose shape how customers experience your product. The right cup keeps frozen treats at serving temperature, presents them attractively, and holds up from counter to last spoonful.

      ## Key Factors to Consider

      ### Material and Composition

      Most disposable dessert cups fall into two categories: paper and plant-based compostable materials. Paper ice cream cups with a food-safe lining are the industry standard for good reason. They insulate well, resist condensation, and feel comfortable to hold. Compostable options made from PLA or similar plant-based materials offer the same functionality while meeting stricter environmental standards. Plastic cups, such as those used for knickerbocker glory or parfait-style servings, provide full visibility of layered desserts but lack insulation.

      ### Size and Capacity

      Ice cream cups typically range from 3oz taster portions up to 10oz generous servings. A 3oz to 4oz cup suits sample portions, kids' servings, or premium gelato where smaller scoops command higher prices. The 5oz to 6oz range covers standard single-scoop servings and is the most versatile choice for general use. For double scoops, sundaes, or frozen yogurt with toppings, 8oz to 10oz cups give customers room without overflow. Stock two or three sizes rather than one to match your serving menu.

      ### Lids and Accessories

      If you offer takeaway desserts, dessert cups with lids are essential. Domed lids in rPET accommodate whipped cream, sauce drizzles, or heaped scoops without crushing the presentation. Flat paper lids work for transport where a clean seal matters more than height. Confirm that lids and cups share the same rim diameter before ordering in bulk; a 4oz cup lid will not fit a 6oz cup even from the same supplier.

      ### Sustainability and Compliance

      With single-use plastic regulations tightening across the UK, paper ice cream cups and compostable alternatives keep you ahead of compliance requirements. Look for cups that are certified compostable (EN 13432 or OK Compost) if your waste stream supports it. Paper cups lined with PLA rather than PE can be industrially composted, making them a practical choice for businesses that want to reduce landfill waste without sacrificing performance.

      ### Cost and Value

      When buying ice cream tubs wholesale, the cost per unit drops significantly at pack quantities of 500 or 1,000. Paper cups in the 4oz to 6oz range typically cost between 4p and 5p per unit at wholesale volumes, while compostable options run slightly higher. Factor in whether you need lids as a separate line item. For seasonal businesses, order enough to cover peak months but avoid over-stocking materials that may degrade in humid storage.

      ### Branding and Presentation

      Colourful pre-printed designs create visual appeal without any minimum order commitment. If you want your own branding on cups, custom printing is available at higher volumes, often starting around 50,000 units. A branded cup turns every takeaway dessert into a walking advertisement for your business. For smaller operations, choosing a distinctive colour or pattern from the standard range achieves a similar effect at no extra cost.

      ## Pro Tips

      - Order a sample pack before committing to a large run, especially if you are switching sizes or materials. A cup that looks right online may feel too small or too flimsy once filled.
      - Match your cup size to your pricing tiers. Using visibly different sizes for small, medium, and large servings helps customers perceive value without you needing to weigh each portion.
      - Store paper cups in a cool, dry area away from direct heat. Humidity can weaken the paper structure before you even open the pack.
      - If you sell both eat-in and takeaway, stock domed lids only for takeaway orders. Flat lids or no lids for eat-in service keeps your costs down.

      ## Summary

      Choosing the right ice cream cups comes down to matching size, material, and lid options to your menu and service style. Paper cups remain the most practical and cost-effective choice for most food service operations, with compostable options available for businesses prioritising sustainability. Buy in bulk, confirm lid compatibility, and stock the two or three sizes that cover your serving range.
    MD
  end

  def down
    Category.find_by(slug: "ice-cream-cups")&.update!(buying_guide: nil)
  end
end
