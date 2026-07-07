class AddBuyingGuideToBowlsAndLids < ActiveRecord::Migration[8.1]
  def up
    guide = <<~MARKDOWN
      Takeaway bowls with lids are the workhorse format for poke, salads, ramen, rice boxes and hot counter food. This category covers round kraft bowls from 500ml up to extra large sharing sizes, PLA-lined paper food bowls, and the flat, domed and vented lids that fit them. The right kraft bowl arrives intact, keeps its shape with hot wet food in it, and looks good when the lid comes off.

      ## Key Factors to Consider

      ### Material & Composition

      Kraft paperboard is the default choice: rigid, natural-looking, and lined so dressings and sauces do not soak through. The 185-series food bowls use a PLA lining, a plant-based film that copes with wet and oily food. Lids come in more materials than bowls: clear PET shows the food off, PP tolerates heat well, and PLA keeps the whole unit plant-based. Black food containers offer a more premium, colour-contrast look for the same round format.

      ### Size & Capacity

      500ml suits lunch salads and sides, 750ml is the standard main-course size for poke and grain bowls, and 1000ml covers noodle dishes and large mains. Extra large bowls of around 1.3 litres handle sharing portions. If your menu spans several sizes, staying within one bowl range pays off at the lid shelf, because fit follows rim diameter rather than capacity.

      ### Temperature & Use Case

      PLA-lined kraft bowls take hot, wet food such as ramen, curries and stews straight off the pass; pick vented lids for hot dishes so steam escapes instead of popping the lid or fogging it. Clear flat and domed lids suit cold salads, poke and dessert bowls. If customers reheat in the container, check the product page first: PLA linings and clear PLA lids are not made for the microwave.

      ### Lid Compatibility

      Bowls and lids are usually separate line items, and fit is set by rim diameter, not volume. Our round kraft bowls share a diameter across the 500ml, 750ml and 1000ml sizes, so one lid line covers all three; 185-series bowls take 185-series lids. Always match the series or stated diameter when ordering, and reorder bowls and lids together so stock stays in step.

      ### Sustainability & Compliance

      Kraft bowls with PLA linings are certified for commercial composting rather than the home heap, so they work best where food-waste collection exists. If you are moving away from conventional plastics, pairing a PLA-lined bowl with a PLA lid keeps the whole unit plant-based; PET and PP lids are recyclable where clean but count as plastic packaging. Honest labelling on your menu about what goes in which bin earns trust with sustainability-minded customers.

      ### Cost & Value

      Bowls ship in cases of 300, with 500ml kraft rounds starting under 10p per bowl at case rates. Cost each dish as bowl plus lid, since the lid is often a third of the packaging cost of the unit. Premium PLA-lined series cost more per serving but read as a premium product in the customer's hand, which matters at poke-bowl price points.

      ## Pro Tips

      - Order samples before committing to a case, and test with your wettest, hottest dish rather than your driest.
      - Match lids by series or rim diameter, never by capacity alone; here one lid covers the 500ml, 750ml and 1000ml kraft rounds.
      - Use vented lids on hot food and clear lids on cold; a fogged lid ruins the photo on a delivery app listing.
      - Keep lid stock counted separately from bowls so a lid shortage never idles a full case of bowls.

      ## Summary

      Choose takeaway bowls by working backwards from the menu: hot and wet needs PLA-lined kraft with vented lids, cold and fresh suits clear-lidded kraft rounds. Standardise on one diameter series, cost bowl and lid together, and kraft bowls will cover most of a modern counter menu at sensible case prices.
    MARKDOWN

    Category.find_by(slug: "bowls-and-lids")&.update!(
      buying_guide: guide,
      meta_title: "Takeaway Bowls & Lids | Wholesale UK | Afida",
      meta_description: "Kraft and PLA-lined takeaway bowls with matching lids, by the case. For poke, salads, ramen and hot food to go. Free UK delivery over £100."
    )
  end

  def down
  end
end
