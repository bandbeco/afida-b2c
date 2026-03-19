class PopulateHotFoodBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    buying_guide = <<~MARKDOWN
      Hot food containers are the backbone of any takeaway or delivery operation. Whether you run a fish and chip shop, a curry house, or a catering company, the right packaging keeps meals at serving temperature, prevents leaks in transit, and shapes how customers perceive your food before they take the first bite.

      ## Key Factors to Consider

      ### Material and Composition

      Hot food packaging comes in several core materials, each suited to different jobs. Cardboard and kraft board are versatile, lightweight, and widely used for pizza boxes, burger boxes, and chip trays. Bagasse, made from sugarcane fibre, offers natural grease resistance and strong insulation, making it ideal for saucy dishes. Polypropylene (PP) plastic containers handle high temperatures and seal tightly with clip-on lids, which makes them popular for curries, stews, and rice dishes. Aluminium foil containers conduct heat evenly and work well for oven reheating. Your choice should match the food type: dry or greasy, saucy or solid, eaten immediately or reheated later.

      ### Size and Capacity

      Hot food takeaway containers typically range from small 250ml portions to large 1,000ml meal boxes. Soup containers start around 8oz for a starter portion and go up to 32oz for family sizes. Pizza boxes follow standard diameter sizing: 7-inch for personal, 10-inch for small, 12-inch for medium, and 14-16 inch for large. Stock your best-selling sizes in bulk and carry smaller quantities of niche sizes. Getting the fit right matters; an oversized container makes a portion look stingy, while an undersized one leads to spills and poor presentation.

      ### Temperature and Use Case

      Keeping food hot during delivery is a primary concern. Double-walled and insulated containers hold heat significantly longer than single-wall alternatives. Bagasse and moulded fibre naturally retain warmth better than thin plastic. If your customers regularly reheat meals, look for microwavable food containers; polypropylene and bagasse are both microwave-safe, while aluminium and polystyrene are not. For dishes with gravy, sauce, or oil, grease resistance and leak-proof seals are non-negotiable. Vented lids can help prevent condensation turning crispy food soggy.

      ### Sustainability and Compliance

      Single-use plastic bans are expanding across the UK, and many local authorities now restrict polystyrene food packaging entirely. Bagasse containers, kraft boxes, and PLA-lined options all offer compostable or recyclable alternatives. Check for certifications such as OK Compost or BPI if you plan to market your packaging as eco-friendly. PFAS-free coatings are increasingly expected by both regulators and consumers. Switching to sustainable hot food packaging can also be a selling point: customers notice, and many actively prefer businesses that avoid unnecessary plastic.

      ### Cost and Value

      Polypropylene containers are typically the cheapest per unit for hot food, but bagasse and kraft options have become much more competitive in recent years. Buying in bulk, usually cases of 250 or 500, brings meaningful savings across all materials. Consider the total cost: a container with an integrated lid saves money and storage space compared to buying containers and lids separately. For high-volume operations, the price difference between materials often amounts to fractions of a penny per meal, so it is worth choosing the option that best suits your food rather than the absolute cheapest.

      ### Branding and Presentation

      Hot food boxes and containers are the first thing a customer sees when their order arrives. Clean, well-fitted packaging signals quality before the lid comes off. Custom-printed kraft boxes and branded stickers offer affordable ways to reinforce your identity. If custom printing is not yet in your budget, choosing a consistent colour or material, such as natural brown kraft or black containers, gives your packaging a cohesive, professional look across every order.

      ## Pro Tips

      - Order samples of two or three container types with your most popular dishes inside, then check temperature, grease resistance, and presentation after 20 minutes; this simulates a real delivery window.
      - If you serve both dry foods (chips, fried chicken) and saucy dishes (curries, stews), use vented lids for the dry items and sealed lids for the wet ones rather than using a single container type for everything.
      - Check that your lids, containers, and any inner trays are from compatible ranges. Mixing suppliers often leads to poor fits and leaks.
      - Review your local council's packaging regulations before committing to a bulk order; compliance requirements vary by region and change frequently.

      ## Summary

      Choosing the right hot food containers comes down to matching the material and design to your menu, your delivery radius, and your customers' expectations. Start with your highest-volume dishes, test a few options under real conditions, and build your packaging range from there.
    MARKDOWN

    Category.find_by(slug: "hot-food")&.update!(buying_guide: buying_guide)
  end

  def down
    Category.find_by(slug: "hot-food")&.update!(buying_guide: nil)
  end
end
