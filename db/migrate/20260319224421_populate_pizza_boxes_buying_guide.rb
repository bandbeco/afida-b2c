class PopulatePizzaBoxesBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    buying_guide = <<~MARKDOWN
      A pizza box does more than carry a pizza from oven to doorstep. The right pizza boxes keep food hot, prevent sogginess, stack without crushing, and tell your customers something about your business before they even open the lid.

      ## Key Factors to Consider

      ### Material and Construction

      Corrugated kraft cardboard is the industry standard for pizza packaging, and for good reason. The fluted inner layer creates an air pocket that insulates against heat loss while adding structural strength. Single-wall corrugated board handles everyday delivery and collection; it is lightweight yet rigid enough to stack several boxes high without collapse. The natural brown kraft finish signals an honest, eco-conscious brand, though white pizza boxes are available for a cleaner, more premium look.

      ### Size and Capacity

      Pizza boxes follow a straightforward sizing convention measured by the diameter of the pizza they hold. Common sizes are 7 inch for personal or kids' portions, 9 inch for small, 12 inch for medium, and 16 inch for large or family pizzas. A 12 inch pizza box is the most popular in UK takeaways and is a safe default if you are standardising on one size. For operations that serve a range, stocking two or three sizes covers most orders without cluttering your prep area. Small pizza boxes also double as containers for calzones, garlic bread, or sides.

      ### Heat Retention and Ventilation

      Keeping a pizza hot is only half the challenge; you also need to let steam escape. Boxes with ventilation holes or perforated corners allow moisture to exit so the base stays crisp rather than turning soggy in transit. Corrugated board naturally breathes better than solid card, which is another reason it dominates pizza packaging. If your delivery radius is large, consider pairing your boxes with insulated delivery bags for the best result.

      ### Sustainability and Compliance

      Kraft pizza boxes are recyclable through standard kerbside collections, provided they are not heavily soiled with grease. Educating your customers with a short note on the box, or on your website, helps keep recycling rates up. Because these boxes are made from unbleached paper fibre, they biodegrade naturally and avoid the regulatory complications of plastic-lined alternatives. No specialist certifications are needed; standard corrugated kraft board is widely accepted by UK recycling facilities.

      ### Cost and Value

      Pizza boxes are one of the more affordable items in your packaging lineup, often under 25p per unit when bought in bulk packs of 100. Larger sizes cost more per box due to the extra material, so it pays to match box size closely to your pizza size rather than defaulting to an oversized box. Buying in cases rather than small quantities brings significant savings, but factor in storage space; pizza boxes arrive flat-packed yet still take up room.

      ### Branding and Presentation

      The plain kraft surface is a natural canvas for branding. If custom pizza boxes or personalised pizza boxes with a full print run are beyond your current volume, branded stickers, stamps, or printed belly bands offer a low-commitment alternative that still makes each box feel intentional. Pizza packaging is one of the few items your customer sees at the moment of greatest anticipation, so presentation here has an outsized impact on perceived quality.

      ## Pro Tips

      - Order a sample pack before committing to bulk. Wall thickness, colour shade, and fold quality vary between manufacturers.
      - Store boxes flat in a dry area. Damp corrugated board loses its rigidity and can collapse under the weight of a loaded pizza.
      - If you serve by the slice, dedicated pizza slice trays are cheaper per unit than cutting a full box down and present better at the counter.
      - Test your box and delivery bag combination together; some insulated bags are sized for specific box dimensions and a poor fit wastes heat.

      ## Summary

      The right pizza boxes protect your product, present your brand, and cost very little per order when bought in bulk. Start with the size that matches your most popular pizza, choose corrugated kraft for proven performance, and build your branding from there.
    MARKDOWN

    Category.find_by(slug: "pizza-boxes")&.update!(buying_guide: buying_guide)
  end

  def down
    Category.find_by(slug: "pizza-boxes")&.update!(buying_guide: nil)
  end
end
