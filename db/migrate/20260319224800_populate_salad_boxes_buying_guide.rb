class PopulateSaladBoxesBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    buying_guide = <<~MARKDOWN
      Salad boxes are the workhorse of any grab-and-go display. The right disposable salad containers keep contents fresh and visible, making it easy for customers to pick up a meal without second-guessing what is inside. This guide covers what to look for when buying salad boxes in bulk for your food service operation.

      ## Key Factors to Consider

      ### Material and Composition

      Most salad boxes are made from kraft board, often with a PLA (plant-based) window that lets customers see the contents. Kraft is sturdy, lightweight, and gives a natural, premium look that works well in delis, cafes, and health-focused outlets. Some ranges use a fully PLA or rPET shell for maximum clarity, which is worth considering if your salads are particularly colourful or layered. Kraft salad boxes with a compostable window offer the best balance of visibility and sustainability for most operations.

      ### Size and Capacity

      Takeaway salad boxes typically range from 500ml to 1,200ml. A 700ml box suits most individual portion salads, grain bowls, and pasta salads. Larger 900ml and 1,200ml options handle sharing portions, loaded salads with bulky toppings, or meal boxes that include a side and a protein. Smaller 500ml containers work well for side salads, fruit pots, and lighter options. Stocking two or three sizes covers the majority of menus without overcomplicating your setup.

      ### Temperature and Use Case

      Salad boxes are designed for cold and ambient foods. If your menu includes dressed salads, slaws, or anything with a heavy vinaigrette, look for containers with a secure tuck-top closure that resists leaking when tilted. Kraft board can soften over time with very wet fillings, so pack dressed salads close to service rather than hours in advance. These containers are not suitable for hot food; for warm grain bowls or heated dishes, use a container rated for higher temperatures.

      ### Sustainability and Compliance

      Compostable salad packaging is now expected rather than optional for many food service businesses. Kraft board with a PLA window is industrially compostable, meaning it breaks down in commercial composting facilities. Look for certifications such as OK Compost or BPI to verify claims. With single-use plastic regulations tightening across the UK and EU, choosing certified compostable or PFAS-free containers keeps you ahead of compliance requirements and aligns with customer expectations.

      ### Cost and Value

      Window salad boxes in kraft are among the most cost-effective options in the cold food packaging category, with pack quantities of 200 to 300 units bringing the per-unit cost down significantly. When comparing prices, factor in whether the container has an integrated closure or needs a separate lid, as separate lids add both cost and assembly time. Ordering a consistent size across your menu simplifies stock management and reduces waste from half-used packs of less popular sizes.

      ### Branding and Presentation

      The clear window on a salad box does most of the selling for you, especially in a chilled display cabinet where customers browse visually. Kraft exteriors offer a clean, natural canvas that pairs well with a branded sticker or sleeve for a professional finish at minimal cost. Custom printing is typically available from around 1,000 units if you want your logo directly on the box. For smaller operations, a simple label with your branding is a practical and affordable alternative.

      ## Pro Tips

      - Order samples in your two most likely sizes and pack them with your actual salad recipes. Fit, headroom for toppings, and how the food looks through the window all vary more than dimensions on a spec sheet suggest.
      - Test the tuck-top closure by turning a filled box on its side for 30 seconds. If dressing seeps out, you need a tighter-fitting option or a change in how you pack.
      - Check that your chosen box dimensions fit your display fridge shelves before placing a bulk order. A box that is too tall or wide for your cabinet is wasted stock.
      - If you serve both individual and sharing portions, pick sizes from the same product range so they stack neatly together in storage and in your display.

      ## Summary

      Choosing the right salad boxes comes down to matching size, material, and closure style to your menu and service format. Kraft containers with a clear window offer the best combination of visibility, sustainability, and value for most food service operations. Start with your highest-volume salad or bowl, find the size that fits it well, and test before committing to a large order.
    MARKDOWN

    Category.find_by(slug: "salad-boxes")&.update!(buying_guide: buying_guide)
  end

  def down
    Category.find_by(slug: "salad-boxes")&.update!(buying_guide: nil)
  end
end
