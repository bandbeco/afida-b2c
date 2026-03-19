class PopulateCupAccessoriesBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    buying_guide = <<~MARKDOWN
      Coffee cup accessories are the finishing touches that turn a basic takeaway drink into a comfortable, complete experience. Stirrers, sleeves, carriers, and sugar sticks may be small items, but they directly affect how customers feel about your service and whether their drink arrives intact.

      ## Key Factors to Consider

      ### Material and Composition

      Most coffee cup accessories are now made from wood, paper, or moulded pulp fibre. Wooden coffee stirrers have largely replaced plastic ones across the UK following single-use plastic restrictions, and they come in birch or bamboo options. Cup sleeves are typically corrugated kraft card, which provides insulation without adding significant weight. Cup carriers split into two camps: moulded pulp fibre trays for basic stability, and card carriers with handles for a more premium feel. Sugar and sweetener sticks use paper wrapping as standard. All of these materials are widely recyclable or compostable.

      ### Size and Compatibility

      Sizing matters more than you might expect with takeaway cup accessories. Stirrers come in lengths from around 140mm (ideal for espresso and small cups) up to 190mm (suited to 12oz and 16oz cups). A stirrer that is too short for the cup is frustrating for the customer and reflects poorly on your setup. Cup sleeves are sized to specific rim diameters, often referred to by series number: a 79-series sleeve fits 8oz and 12oz cups, while an 89-series sleeve fits 16oz cups. Always confirm the series your cups belong to before ordering sleeves. Carriers are available in 2-cup and 4-cup configurations, with some designs splittable so staff can adapt on the spot.

      ### Temperature and Use Case

      Sleeves exist primarily for hot drinks, adding an insulating layer so customers can hold single-wall cups comfortably. If you already use double-wall or ripple-wall cups, sleeves are unnecessary, so check whether you are doubling up on cost. Carriers need to hold both hot and cold cups securely; pulp fibre trays handle this well because they absorb condensation from iced drinks without losing structural strength. Stirrers are used across hot and cold beverages alike, so a single length that suits your most common cup size keeps things simple.

      ### Sustainability and Compliance

      The UK ban on single-use plastic stirrers, straws, and cotton buds means wooden or paper stirrers are now a legal requirement, not a lifestyle choice. Moulded pulp carriers and kraft sleeves are compostable and accepted in most commercial food waste streams. If your operation carries sustainability certifications or communicates eco credentials to customers, using accessories made from FSC-certified wood or carrying OK Compost marks reinforces that message at every touchpoint.

      ### Cost and Value

      Disposable cup accessories are high-volume, low-cost items where bulk ordering delivers the best value. Wooden coffee stirrers are typically sold in cases of 10,000, bringing the per-unit cost well below a penny. Pulp fibre carriers cost a few pence each and prevent the far more expensive problem of spilled drinks and remakes. Handled card carriers cost more per unit but suit delivery and mobile ordering where presentation and security matter. Think about which accessories match your service style rather than defaulting to the cheapest option across the board.

      ## Pro Tips

      - Match your stirrer length to your most popular cup size; a 140mm stirrer disappearing inside a 16oz cup is a common and avoidable complaint.
      - If you use single-wall cups, calculate the combined cost of cup plus sleeve against switching to double-wall cups. One of those options is almost always cheaper.
      - Keep a small stock of 2-cup carriers even if you primarily use 4-cup trays; most multi-drink orders are actually for two drinks, and using the right carrier avoids cups sliding around.
      - Test sleeve fit with your actual cups before bulk ordering; a millimetre difference in rim diameter can mean the sleeve rides up or sits too loose.

      ## Summary

      The right coffee cup accessories make every takeaway order feel considered and complete. Focus on compatibility first, matching stirrer lengths and sleeve series to your cup range, then choose materials and carrier styles that suit your service format and volume.
    MARKDOWN

    Category.find_by(slug: "cup-accessories")&.update!(buying_guide: buying_guide)
  end

  def down
    Category.find_by(slug: "cup-accessories")&.update!(buying_guide: nil)
  end
end
