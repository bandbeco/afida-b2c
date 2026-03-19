class PopulateSuppliesAndEssentialsBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    buying_guide = <<~MARKDOWN
      Running a food service operation means staying on top of the essentials. Catering supplies and essentials, from bin liners and gloves to labels and till rolls, are the behind-the-scenes items that keep your kitchen compliant, your service efficient, and your costs under control.

      ## Key Factors to Consider

      ### Material and Composition

      The materials you choose for everyday supplies have a direct impact on performance and compliance. Food handling gloves come in vinyl, nitrile, and latex; nitrile offers the best puncture resistance and is latex-free, making it the safest default for food prep. Bin liners range from standard HDPE to compostable options made from plant starch. Compostable bin liners are increasingly expected in venues that separate food waste, and many local authorities now require them for commercial organic collections. For cleaning supplies, look for food-safe formulations that meet hygiene standards without leaving residues.

      ### Size and Capacity

      Getting sizes right avoids waste and frustration. Bin liners are typically sold in 8L, 30L, 60L, and 90L capacities; match them precisely to your bins rather than doubling up undersized bags. Gloves are sized from small to extra-large, and proper fit matters for dexterity and safety during food prep. Thermal till rolls come in standard widths (57mm for card machines, 80mm for POS terminals), so check your printer specifications before ordering. Day dot labels and allergen stickers follow standard dimensions designed to fit food containers without obscuring contents.

      ### Sustainability and Compliance

      Food safety regulations require visible date labelling on all prepared food, making day dot labels a legal necessity rather than an optional extra. Allergen stickers help you meet the requirements introduced under Natasha's Law. On the waste side, compostable bin liners certified to EN 13432 or carrying the OK Compost mark are the only liners accepted in most commercial composting schemes. Choosing certified products protects you from greenwashing claims and ensures your waste stream stays compliant.

      ### Cost and Value

      These are high-turnover, low-margin items where bulk buying makes the biggest difference. Ordering food service supplies in case quantities, rather than individual packs, typically reduces the per-unit cost by 15 to 30 percent. Labels, gloves, and till rolls are used daily in most operations, so running out mid-service is far more expensive than holding a few weeks of extra stock. Set reorder points for each item based on your weekly usage and lead times to avoid emergency purchases at premium prices.

      ### Practical Compatibility

      Compatibility between products and equipment is easy to overlook. Thermal till rolls must match your printer's core size and paper width; the wrong roll will jam or print illegibly. Centrefeed rolls need a compatible wall-mounted dispenser for hygienic, one-handed tearing. Day dot labels should adhere to both chilled and room-temperature containers without peeling. Testing a sample case before committing to bulk orders saves time and returns.

      ## Pro Tips

      - Set up a weekly checklist of consumable stock levels; running out of gloves or labels mid-shift disrupts the entire line.
      - Buy till rolls in bulk at the start of each quarter to lock in pricing and avoid last-minute orders from expensive convenience suppliers.
      - When switching to compostable bin liners, confirm with your waste collector that they accept the specific certification your liners carry.
      - Trial gloves across your team before bulk ordering; a medium from one manufacturer can fit quite differently from another.

      ## Summary

      Catering supplies and essentials may not be glamorous, but getting them right keeps your operation running smoothly and compliantly. Focus on compatibility, buy in bulk where turnover justifies it, and treat compliance items like labels and certified liners as non-negotiable rather than cost-saving opportunities.
    MARKDOWN

    Category.find_by(slug: "supplies-and-essentials")&.update!(buying_guide: buying_guide)
  end

  def down
    Category.find_by(slug: "supplies-and-essentials")&.update!(buying_guide: nil)
  end
end
