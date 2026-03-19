class PopulateSoupContainersBuyingGuide < ActiveRecord::Migration[8.1]
  def up
    buying_guide = <<~MARKDOWN
      Soup containers are one of those purchases that look simple until a lid pops off in a delivery bag. Whether you serve soups, stews, curries, or noodle dishes, the right disposable soup cups and pots keep food hot, sealed, and presentable from kitchen to customer.

      ## Key Factors to Consider

      ### Material and Composition

      Kraft paperboard is the most common material for paper soup containers. It is lightweight, sturdy, and available at the lowest cost per unit. All kraft soup cups feature an interior lining, typically PE or PLA, that creates a barrier against grease and moisture. For a more premium eco positioning, look for PLA-lined options that are industrially compostable. Kraft bowls, both round and rectangular, offer a wider, shallower format suited to grain bowls, stews, and salads as well as soups.

      ### Size and Capacity

      Soup containers follow a standard sizing convention: 8oz for starter or side portions, 12oz for a regular serving, and 16oz for a generous main. Heavy-duty soup pots with lids go up to 26oz and 32oz for family portions or meal prep. Narrower containers (around 90mm diameter) work well for soups and noodles, while wider formats (115mm and above) suit thicker stews and dishes that benefit from a broader surface. Stock your best-selling size in bulk and keep smaller quantities of the rest.

      ### Lids and Leak Resistance

      Secure closure is the single most important feature for takeaway soup containers. Lids are almost always sold separately, so confirm compatibility before ordering. Flat lids suit hot soups and stews; dome lids work better for cold items or dishes with generous toppings. A well-fitted lid should click or press firmly into place without needing force. If your menu includes saucy or liquid-heavy dishes, test the seal by tipping a filled container on its side for 30 seconds before committing to a bulk order.

      ### Temperature and Use Case

      Most kraft and paper soup containers are microwave safe, which is a real advantage for customers who reheat at home or in the office. Check the manufacturer's guidance, as the lining material determines microwave suitability: PLA-lined and unlined kraft handle microwaves well, while some PE-lined options do not. For hot holding, thicker-walled and heavy-duty containers retain heat longer and feel more substantial in hand. If you also serve cold items like overnight oats or chilled noodle salads, the same containers often work for both; just swap to a dome lid.

      ### Sustainability and Compliance

      Kraft soup containers are inherently more recyclable than plastic alternatives, and compostable versions with PLA linings carry certifications such as OK Compost. With single-use plastic bans expanding across the UK, paper-based soup cups position your business on the right side of current and upcoming regulations. If you market your packaging as compostable, confirm that your local waste infrastructure actually processes industrial compost; otherwise, recyclable kraft with a PE lining may be the more honest choice.

      ### Cost and Value

      Own-brand kraft disposable soup cups start from around 6p per unit in cases of 500, making them one of the most affordable hot food packaging options. Premium compostable ranges run closer to 9p per unit at case quantities, with small packs of 25 available at higher per-unit prices for trial or low-volume use. Remember to factor in lid costs, which typically add 7-8p per unit. Buying containers and lids from the same range avoids the hidden cost of mismatched sizing and wasted stock.

      ## Pro Tips

      - Always order a sample pack of containers and lids together, then fill one with your hottest, most liquid dish and tip it sideways; this 30-second test saves you from discovering leaks after a customer complaint.
      - If you serve both soups and thicker dishes like chilli or porridge, a 12oz container handles both well and reduces the number of SKUs you need to manage.
      - Wider kraft bowls can double as salad or grain bowl packaging, giving you more use from a single product line.
      - Check whether your lid material matches your container's eco credentials; a compostable container paired with a non-compostable lid undermines the environmental claim.

      ## Summary

      The right soup containers balance leak-proof performance, the correct size for your portions, and a material that aligns with your sustainability goals. Start with your most popular dish, test the seal under real conditions, and scale up from there.
    MARKDOWN

    Category.find_by(slug: "soup-containers")&.update!(buying_guide: buying_guide)
  end

  def down
    Category.find_by(slug: "soup-containers")&.update!(buying_guide: nil)
  end
end
