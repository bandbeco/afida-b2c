class PopulateHotCupsBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    buying_guide = <<~MARKDOWN
      Every takeaway coffee starts with the cup. Takeaway coffee cups are among the most frequently purchased items in food service, and choosing the right ones affects everything from drink quality to customer perception of your business.

      ## Key Factors to Consider

      ### Material and Composition

      Paper is the standard material for hot cups, but not all paper cups are created equal. Single-wall cups are lightweight and cost-effective for short serving windows, such as counter service where drinks are consumed quickly. Double-wall cups add an insulating air pocket between two layers of card, keeping drinks hotter for longer while remaining comfortable to hold. Ripple-wall cups achieve similar insulation with a corrugated outer wrap. All three eliminate the need for a separate sleeve, though single-wall cups are often paired with one.

      ### Size and Capacity

      Paper cups for hot drinks follow a standard sizing convention: 4oz for espresso, 8oz for small, 12oz for regular, and 16oz for large. Most cafés and restaurants find that 8oz and 12oz sizes make up the bulk of orders. Stock your most popular size in the largest quantity to get the best per-unit price, and keep smaller runs of the other sizes to cover the full range.

      ### Lids and Fit

      Disposable coffee cups with lids are the baseline expectation for any takeaway operation. Sip-through lids are the most common choice; they allow customers to drink on the move without removing the lid. Ensure your lids are from a compatible range, as rim diameters can vary by a millimetre or two between manufacturers. A poor fit leads to leaks, complaints, and wasted stock.

      ### Sustainability and Compliance

      Traditional paper coffee cups use a polyethylene (PE) lining to make them waterproof, which also makes them difficult to recycle through standard waste streams. PLA-lined and aqueous-coated cups are now widely available as recyclable or compostable alternatives. If sustainability matters to your customers, or if local regulations restrict single-use plastics, these options are worth the modest price premium. Look for certifications such as OK Compost or BPI to back up any claims you make.

      ### Cost and Value

      Single-wall cups are the cheapest per unit, but the total cost picture changes when you factor in sleeves. A double-wall or ripple-wall cup at a slightly higher unit price often works out cheaper than a single-wall cup plus a separate sleeve. Buying cardboard cups in bulk, typically cases of 500 or 1,000, brings significant savings. Weigh the discount against your storage capacity and turnover rate to avoid tying up cash in stock you won't use quickly.

      ### Branding and Presentation

      Branded coffee cups turn every takeaway order into a mobile advert. Custom printing is available on all wall types, with minimum orders usually starting at 1,000 units. For smaller operations not yet ready for a print run, choosing a distinctive colour or finish, such as kraft or black, gives your cups a recognisable look without the commitment.

      ## Pro Tips

      - Order samples from at least two suppliers before committing; wall thickness and print quality vary significantly.
      - If you switch cup supplier, re-test lid fit. A lid that worked perfectly on one brand may not seal on another.
      - Double-wall cups can serve as both hot and iced coffee vessels in a pinch, reducing the number of SKUs you need to stock.

      ## Summary

      The right takeaway coffee cups balance insulation, cost, and presentation for your specific service style. Start with your highest-volume drink size, pick the wall type that suits your workflow, and build from there.
    MARKDOWN

    Category.find_by(slug: "hot-cups")&.update!(buying_guide: buying_guide)
  end

  def down
    Category.find_by(slug: "hot-cups")&.update!(buying_guide: nil)
  end
end
