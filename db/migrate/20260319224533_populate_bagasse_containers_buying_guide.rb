class PopulateBagasseContainersBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    buying_guide = <<~MARKDOWN
      If you're looking for a direct replacement for polystyrene or plastic takeaway containers, biodegradable food packaging made from bagasse is the most practical option on the market. Made from sugarcane fibre, a by-product of sugar production, bagasse containers are naturally sturdy, grease-resistant, and fully compostable.

      ## Key Factors to Consider

      ### Material and Composition

      Bagasse is pressed sugarcane fibre, moulded into rigid containers that hold their shape even with hot, saucy, or greasy food. Unlike polystyrene, it contains no petroleum-based materials and breaks down in commercial composting facilities within 12 weeks. Standard-weight bagasse works well for lighter meals and sides, while heavyweight versions offer a thicker wall and firmer hinge for loaded burgers and fuller portions. Both are microwave-safe and freezer-friendly, which makes them versatile across different service styles.

      ### Container Types and Sizes

      The range of bagasse boxes available covers most food service needs. Clamshell containers, with their integrated hinged lid, are the most popular format and come in sizes from 5in for snacks up to 9in for full meals. Burger boxes in 5in and 6in sizes are purpose-built with deeper bases to hold stacked burgers without crushing. Gourmet bases, sold separately from their lids, range from 12oz (340ml) for side dishes to 60oz (1800ml) for sharing platters and large salads. Chip trays round out the range for open-serve items like fries and street food.

      ### Lids and Compatibility

      For gourmet bases, you have three lid options: bagasse lids for a fully compostable package, PLA lids for a clear view of the food inside, and window lids that combine both. Lids are sized (Size 3, Size 4, Size 5), so matching the right lid to the right base is essential. Check the size number on both base and lid before ordering in bulk to avoid costly mismatches.

      ### Sustainability and Compliance

      Compostable packaging is increasingly required by regulation, not just preferred by customers. Many UK councils now accept bagasse in food waste collections, and single-use plastic bans are making eco friendly food packaging the default rather than the premium option. Look for containers certified to EN 13432 or carrying the OK Compost mark, which guarantees industrial compostability. Be aware that bagasse is not suitable for home composting; it requires the higher temperatures of commercial facilities.

      ### Cost and Value

      Sustainable food packaging has closed the price gap with conventional alternatives. Standard bagasse clamshells start from around £0.05 per unit in bulk, comparable to the plastic containers they replace. Heavyweight and gourmet options sit higher, reflecting their thicker construction. Buying in case quantities of 250 to 500 delivers the best per-unit pricing. Factor in the marketing value too: customers increasingly choose businesses that use compostable takeaway containers, so the packaging pays for itself in reputation.

      ## Pro Tips

      - Order one case each of standard and heavyweight clamshells to compare rigidity with your specific menu items before committing to a full run.
      - If you use gourmet bases, standardise on one lid size across as many bases as possible to simplify stock management.
      - Bagasse absorbs moisture over time in storage; keep cases sealed and in a dry area to maintain container integrity.

      ## Summary

      Bagasse is the most versatile and cost-effective material for biodegradable food packaging in food service today. Match the container type to your menu, verify lid compatibility, and store stock properly to get the best performance from every unit.
    MARKDOWN

    Category.find_by(slug: "bagasse-containers")&.update!(buying_guide: buying_guide)
  end

  def down
    Category.find_by(slug: "bagasse-containers")&.update!(buying_guide: nil)
  end
end
