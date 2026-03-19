class PopulateFoodContainersBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    buying_guide = <<~MARKDOWN
      Food containers and lids are the backbone of any takeaway, deli, or grab-and-go operation. Whether you are packing portion pots of sauce, deli-counter salads, or full meal boxes, the right disposable food containers keep your food secure, presentable, and at the correct temperature from counter to customer.

      ## Key Factors to Consider

      ### Material and Composition

      The main materials for food containers are kraft card, PLA (a plant-based clear plastic), rPET (recycled plastic), bagasse (sugarcane fibre), and standard PP plastic. PLA portion pots offer glass-like clarity for sauces, dressings, and dips, letting customers see exactly what they are getting. Kraft containers provide a natural, premium look and are popular for street food and deli counters. Bagasse is rigid, grease-resistant, and fully compostable, making it ideal for hot and oily foods. PP plastic microwaveable containers remain the practical choice for meal prep and reheatable takeaway dishes.

      ### Size and Capacity

      Portion pots start at 1oz for condiments and run up to 25oz for larger servings. For main meal containers, standard sizes are 500cc, 650cc, 750cc, and 1,000cc; most food service operations find 650cc and 750cc cover the majority of their menu. Food pails in the 26oz to 32oz range suit noodle dishes and larger portions. Stocking two or three core sizes rather than five or six simplifies your operation and lets you buy in higher volumes at better prices.

      ### Temperature and Use Case

      Not all food containers handle heat equally. PP plastic microwaveable containers are rated for reheating and suit hot meal delivery. Kraft containers with a PE lining handle warm, greasy food well, while unlined kraft softens with moisture over time. PLA is designed for cold and ambient use only; it warps above 40°C. If your menu spans hot mains and cold sides, you will need at least two container types. Vented lids are worth considering for hot food, as they release steam and prevent condensation from making food soggy.

      ### Sustainability and Compliance

      Compostable food packaging is increasingly expected rather than optional. PLA, bagasse, and unlined kraft are all commercially compostable when processed through industrial composting facilities. Check whether your local waste collection accepts these materials; without the right infrastructure, compostable packaging ends up in landfill regardless of its certifications. Look for OK Compost or BPI certification to back up environmental claims. PFAS-free certification is also becoming a key requirement for any food-contact packaging.

      ### Cost and Value

      Prices start from around £0.01 per unit for small portion pots bought in bulk (packs of 2,500 to 5,000) and range up to £0.15 per unit for larger kraft food trays. PP microwaveable containers with lids sit around £0.10 to £0.12 per unit in cases of 250. Buying food containers and lids as an integrated set, or choosing hinged containers that combine both, removes a separate purchase and ensures a reliable fit every time. The cheapest per-unit option is rarely the best value if lids do not seal properly or containers collapse under weight.

      ### Lids and Compatibility

      Lid fit is one of the most overlooked details when sourcing takeaway containers. Vented lids work best for hot food; flat or domed lids suit cold items. Anti-mist lids, available in rPET, keep condensation from obscuring the contents in chilled display cabinets. Always confirm that lids are sold to match your specific container line, as even containers of the same stated capacity can have different rim diameters across ranges.

      ## Pro Tips

      - Order sample packs of your shortlisted containers and test them with your actual menu items. Grease resistance, lid seal, and stacking stability vary significantly between products.
      - If you serve both hot and cold food, standardise on one lid size that fits multiple container sizes within a range to reduce stock complexity.
      - For catering jobs, choose containers that stack securely without sliding. A collapsed stack in a delivery bag costs you more in remakes than the container itself.
      - Check that your portion pots are compatible across your sauce, dressing, and side dishes. One or two sizes should cover most uses.

      ## Summary

      Choosing the right food containers and lids comes down to matching materials, sizes, and lid types to your actual menu and service style. Start with your highest-volume items, test with real food before committing to bulk, and treat lid compatibility as a non-negotiable requirement. Reliable disposable food containers protect your margins and your reputation with every order that leaves your counter.
    MARKDOWN

    Category.find_by(slug: "food-containers")&.update!(buying_guide: buying_guide)
  end

  def down
    Category.find_by(slug: "food-containers")&.update!(buying_guide: nil)
  end
end
