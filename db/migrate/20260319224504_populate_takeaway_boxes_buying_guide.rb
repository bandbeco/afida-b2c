class PopulateTakeawayBoxesBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    buying_guide = <<~MARKDOWN
      Takeaway boxes are the workhorses of any food-to-go operation. From burger bars and fish and chip shops to street food vendors and delivery kitchens, the right takeaway food boxes keep meals hot, secure, and presentable on the journey from counter to customer.

      ## Key Factors to Consider

      ### Material and Composition

      Most takeaway boxes are made from kraft board, corrugated cardboard, or microflute. Kraft board is the most popular choice: it is lightweight, grease-resistant, and gives a clean, natural look that appeals to eco-conscious customers. Corrugated cardboard offers extra rigidity and insulation, making it a good fit for larger portions like fish and chips. Microflute, a finely corrugated board, sits between the two; it provides excellent heat retention and structural strength while keeping walls thin. For wet or saucy dishes, look for cardboard food boxes with a grease-resistant lining or consider leakproof paper pots with lids.

      ### Size and Capacity

      Takeaway containers come in a wide range of sizes to match different menu items. Burger boxes typically measure around 5 to 6 inches square, while burger meal boxes add extra room for chips on the side. Folded board trays come in small, medium, and large formats, suiting everything from a portion of chips to a full platter. Fish and chips boxes are sized specifically for that classic combination, available in small, medium, and large. Rather than stocking every size, identify the two or three formats that cover the bulk of your menu and buy those in volume.

      ### Temperature and Use Case

      Keeping food warm during transit is a core job for any carry out box. Kraft and microflute boxes trap heat effectively thanks to the insulating properties of their layered construction. Hinged-lid boxes with a snug closure retain heat better than open trays, so they suit delivery orders where the journey is longer. Windowed versions let customers see the food without opening the lid, which helps with presentation and reduces heat loss. For items that release steam, such as freshly fried food, a small vent or perforated panel prevents the box from going soggy.

      ### Sustainability and Compliance

      Cardboard and kraft takeaway boxes are recyclable through standard waste streams, provided they are not heavily contaminated with food residue. Microflute boxes made from sustainably sourced board can carry FSC certification. With single-use plastic restrictions tightening across the UK, paper and board packaging is increasingly the default rather than the alternative. If your boxes carry a compostable lining, check that it meets EN 13432 or carries the OK Compost mark so your environmental claims hold up.

      ### Cost and Value

      Takeaway packaging costs add up quickly at high volumes, so per-unit pricing matters. Folded board trays are among the most economical options, with packs of 300 to 500 bringing unit costs well below 10p. Kraft burger boxes sit slightly higher but still represent good value in packs of 200. Premium microflute boxes cost more per unit, though their superior insulation and structure may justify the difference for delivery-heavy operations where food quality on arrival drives repeat orders. Buying in bulk is the single biggest lever you have on cost.

      ### Branding and Presentation

      A plain kraft finish already looks clean and professional, and it pairs well with custom stamps, stickers, or branded tape for low-cost personalisation. For a more polished look, black kraft boxes create a premium feel without a custom print run. Full-colour custom printing is available on most box types, with minimum orders typically starting from 1,000 units. Coordinating your takeaway boxes with branded bags and napkins creates a consistent identity that customers remember.

      ## Pro Tips

      - Test your boxes with your actual menu items before ordering in bulk; a box that looks perfect empty can warp or leak under a loaded burger.
      - If you run a delivery operation, choose hinged boxes over open trays. The lid keeps food contained during transit and reduces spills.
      - Stock one versatile size, such as a medium folded board tray, as your default. It covers most use cases and simplifies ordering.
      - Keep a small quantity of leakproof pots for saucy or liquid-heavy items rather than forcing them into standard boxes.

      ## Summary

      The right takeaway boxes protect your food, reflect your brand, and keep costs manageable across hundreds of orders a day. Start with the material and size that match your core menu, buy in bulk to drive down per-unit costs, and treat your takeaway packaging as an extension of the dining experience.
    MARKDOWN

    Category.find_by(slug: "takeaway-boxes")&.update!(buying_guide: buying_guide)
  end

  def down
    Category.find_by(slug: "takeaway-boxes")&.update!(buying_guide: nil)
  end
end
