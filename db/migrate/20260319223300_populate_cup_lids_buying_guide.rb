class PopulateCupLidsBuyingGuide < ActiveRecord::Migration[8.0]
  def up
    Category.find_by(slug: "cup-lids")&.update!(buying_guide: <<~MD)
      The right cup lids do more than prevent spills. They determine whether a customer can sip comfortably on the go, whether a smoothie arrives intact, and whether your packaging aligns with your sustainability goals. With so many lid types, materials, and sizing systems available, it pays to understand what each option does before ordering in bulk.

      ## Key Factors to Consider

      ### Material and Composition

      Cup lids come in four main materials, each suited to different drinks and priorities. PP (polypropylene) sip lids are the most affordable option for hot drinks, offering a secure fit and heat resistance at a low cost per unit. CPLA lids, made from crystallised plant-based PLA, handle hot temperatures while being industrially compostable. Paper lids with a PE lining provide a fully recyclable alternative for hot cups, though they cost more. For cold drinks, clear rPET lids and PLA lids let customers see their smoothie or iced coffee, with PLA offering the compostable advantage. Bagasse (sugarcane fibre) lids round out the range as a plastic-free hot cup option with a natural look.

      ### Lid Type and Fit

      Choosing the right lid shape depends on what you serve. Sip lids with a raised drinking slot suit hot drinks like coffee and tea, letting customers drink without removing the lid. Dome lids with a straw slot work for smoothie cups with lids, iced drinks, and anything topped with cream or foam. Flat lids with a straw slot keep a lower profile for standard cold drinks. No-hole dome and flat lids seal containers for transport, making them the right choice for delivery orders. Always check the series number or rim diameter: a lid designed for a 79-series cup will not snap onto an 89-series cup, even if the ounce size looks similar.

      ### Size Compatibility

      Cup lid sizing follows the rim diameter of the cup, not the volume. This means a single lid size often fits multiple cup capacities within the same range. For example, one lid may fit both 12oz and 16oz cups if they share the same rim width. Lid compatibility is typically specified by series (e.g. 76-series, 89-series, 96-series) or by rim measurement in millimetres (80mm, 90mm). When sourcing disposable coffee cups with lids, always confirm compatibility between your cup and lid ranges. Ordering a sample of each before committing to full packs avoids costly mismatches.

      ### Sustainability and Compliance

      If reducing plastic waste is a priority, you have several routes. CPLA and PLA lids are industrially compostable and suit businesses with access to commercial composting facilities. Paper lids with PE lining are recyclable through standard paper recycling streams. Bagasse and fibre lids are both compostable and plastic-free, appealing to customers who want to see no plastic at all. Check that your chosen lid carries relevant certifications such as EN 13432 or OK Compost if you plan to market your packaging as compostable.

      ### Cost and Value

      PP sip lids start from under 2p per unit at pack quantities of 1,000, making them the budget option for high-volume coffee shops. CPLA and PLA lids typically run 5p to 7p per unit. Paper and bagasse lids sit at the premium end, between 4p and 6p per unit. The cost difference adds up over thousands of serves, so consider where sustainability matters most to your customers and allocate your budget accordingly. Many operations use compostable lids for dine-in and front-of-house service while keeping PP lids for delivery where the packaging is less visible.

      ## Pro Tips

      - Order one sleeve of lids before committing to a full case. Test the snap fit on your cups under real service conditions; a lid that fits loosely in a quiet kitchen may pop off when a barista is rushing.
      - If you stock multiple cup sizes, check whether a single lid fits across them. Reducing lid SKUs simplifies storage and speeds up service.
      - Dome lids take up more storage space than flat lids. Factor in your available storage when deciding how many to order at once.

      ## Summary

      Getting the right cup lids means matching material, shape, and rim size to your cups and your service style. Start by confirming compatibility with your existing cup range, then choose the material that balances your sustainability goals with your cost targets. A well-fitted lid improves the customer experience on every serve.
    MD
  end

  def down
    Category.find_by(slug: "cup-lids")&.update!(buying_guide: nil)
  end
end
