class PopulateCupsAndDrinksBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    buying_guide = <<~MARKDOWN
      Choosing the right disposable cups is one of the most visible decisions you'll make for your food service business. From the morning coffee rush to cold drinks on a summer afternoon, your cups are in your customers' hands, literally, and they shape how your brand is perceived.

      ## Key Factors to Consider

      ### Material and Composition

      The two main options for disposable cups are paper and PLA (a plant-based plastic alternative). Single-wall paper cups are the most economical choice for everyday hot drinks, while double-wall and ripple-wall variants provide insulation without the need for a separate sleeve. For cold drinks like smoothies and iced coffees, PLA cups offer the clarity of plastic while remaining compostable. If you serve both hot and cold beverages, you'll need separate cup lines; no single material handles both extremes well.

      ### Size and Capacity

      Takeaway coffee cups typically come in four standard sizes: 4oz (espresso), 8oz (small), 12oz (regular), and 16oz (large). Most cafés find that 8oz and 12oz account for the majority of orders, so stock heavier in those sizes. For smoothie cups, 12oz to 20oz is the standard range. Getting sizes right avoids waste from customers upsizing into cups that are too large and reduces the frustration of drinks that don't fit.

      ### Lids and Accessories

      Disposable coffee cups with lids are what most customers expect for takeaway orders. Sip-through lids suit hot drinks, while domed lids with a straw slot work for smoothie cups with lids. Make sure your lids and cups come from compatible ranges; a mismatched lid is a spill waiting to happen. Consider whether you also need sleeves, stirrers, or straws, and source them alongside your cups for consistency.

      ### Sustainability and Compliance

      The shift toward eco friendly packaging is accelerating, and cups are under particular scrutiny. Traditional paper cups have a PE (polyethylene) lining that makes them difficult to recycle through standard streams. PLA-lined paper cups and fully compostable options are now widely available and increasingly expected by consumers. Check whether your local authority accepts compostable cups in food waste collections; if not, the environmental benefit is reduced. Look for certifications like OK Compost or BPI to verify claims.

      ### Cost and Value

      Paper cups for hot drinks range significantly in price depending on wall type and material. Single-wall cups are the cheapest per unit, but if you're currently buying cups plus separate sleeves, switching to double-wall or ripple-wall can actually reduce your total cost. Buying in bulk, in cases of 500 or 1,000, drops the per-unit price considerably. Balance your volume discount against storage space and shelf life.

      ### Branding and Presentation

      Takeaway coffee cups are a walking advertisement for your business. Custom-printed cups with your logo create brand recognition every time a customer walks down the street. Minimum order quantities for branded cups are typically 1,000+, so this works best for established businesses with consistent throughput. For smaller operations, choosing a distinctive cup colour or style, such as kraft cardboard cups, can set you apart without the commitment of a print run.

      ## Pro Tips

      - Always order a sample pack before committing to a bulk order; wall thickness, lid fit, and print quality vary more than you'd expect between suppliers.
      - Check lid compatibility if you switch cup suppliers. Even cups of the same stated size can have slightly different rim diameters.
      - For events or seasonal spikes, keep a buffer stock of your most-used sizes. Supply chain delays on cups are common during peak periods.
      - Test your hot cups with boiling water for 10 minutes before buying in bulk to check for softening or leaking at the seam.

      ## Summary

      The right disposable cups balance practicality, presentation, and sustainability for your specific operation. Start with your highest-volume drink, match the material and size to that use case, and build outward from there. Your cups are too visible to get wrong.
    MARKDOWN

    Category.find_by(slug: "cups-and-drinks")&.update!(buying_guide: buying_guide)
  end

  def down
    Category.find_by(slug: "cups-and-drinks")&.update!(buying_guide: nil)
  end
end
