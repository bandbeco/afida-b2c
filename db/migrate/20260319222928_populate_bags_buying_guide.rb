class PopulateBagsBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    buying_guide = <<~MARKDOWN
      Paper bags are one of the most visible pieces of packaging your business uses. Whether you are handing a customer a sandwich at the counter or packing a delivery order, the bag they carry it in shapes their impression of your brand and keeps the contents safe in transit.

      ## Key Factors to Consider

      ### Material and Composition

      Most paper bags for food service are made from kraft paper, which gets its strength from long wood pulp fibres. Brown kraft paper bags are the most popular choice: they are sturdy, recyclable, and have a natural look that signals eco-friendliness. White paper bags offer a cleaner, more polished appearance and work well for bakeries or premium retail. For heavier loads, look for bags with a higher GSM (grams per square metre) rating; thicker paper resists tearing under the weight of stacked food containers.

      ### Size and Capacity

      Paper bags with handles come in a wide range of sizes, from small bags suited to a single pastry or sandwich through to large carrier bags that hold multiple takeaway containers. Think about your most common order size when choosing a default bag. Stocking two or three sizes covers most scenarios without overcomplicating your counter workflow. Small paper bags are ideal for bakery items or side orders, while large paper carrier bags handle full meal deals and multi-item orders.

      ### Handle Type

      Handles make a bigger difference than you might expect. Twisted paper handles are the most common; they are comfortable to carry and hold up well under moderate weight. Flat paper handles sit flush against the bag and give a sleeker look, often favoured by retail and premium food outlets. For very light items, bags with no handles (flat or SOS bags) keep costs down and work fine when customers are not carrying far.

      ### Sustainability and Compliance

      Paper bags are inherently more recyclable than plastic alternatives, which is one reason they have become the default for food service. Kraft paper bags biodegrade naturally and are accepted in most kerbside recycling. If your local authority has introduced single-use plastic bag charges or bans, paper carrier bags are a straightforward compliant option. Check that any bags marketed as compostable carry a recognised certification such as OK Compost or EN 13432.

      ### Cost and Value

      Brown paper bags are among the most cost-effective packaging items you will buy, often under two pence per unit at bulk quantities. White and printed paper bags cost more, but the per-unit premium shrinks at higher volumes. If you are considering branded paper bags or custom paper bags with your logo, most suppliers require minimum orders of 1,000 to 5,000 units. Factor in storage space; paper bags are bulky relative to their cost, so order quantities you can store and rotate through within a few months.

      ### Branding and Presentation

      Printed paper bags turn a functional item into a marketing tool. Every bag that leaves your premises carries your name into the street, the office, or the home. Custom printing works best on flat, uncluttered surfaces, so simple logos and one or two colours tend to look sharper than complex designs. If full custom printing is not yet in your budget, kraft paper bags pair well with branded stickers or stamps as a lower-commitment alternative.

      ## Pro Tips

      - Order samples in each size you are considering and pack a real order into them before committing to bulk. A bag that looks right empty can be too tight or too loose once filled.
      - Store paper bags flat and away from moisture. Damp kraft paper loses its strength and can tear under normal loads.
      - If you serve greasy foods, consider bags with a grease-resistant lining or use an inner wrap to prevent bleed-through that weakens the bag.

      ## Summary

      The right paper bags balance strength, size, and presentation for the way your business actually operates. Start with your most common order type, pick a material weight that handles it comfortably, and scale up to branded options when your volumes justify the investment.
    MARKDOWN

    Category.find_by(slug: "bags")&.update!(buying_guide: buying_guide)
  end

  def down
    Category.find_by(slug: "bags")&.update!(buying_guide: nil)
  end
end
