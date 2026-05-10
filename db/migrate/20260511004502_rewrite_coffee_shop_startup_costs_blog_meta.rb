class RewriteCoffeeShopStartupCostsBlogMeta < ActiveRecord::Migration[8.1]
  def up
    post = BlogPost.find_by(slug: "startup-costs-for-coffee-shop")
    return unless post

    post.update!(
      meta_title: "How Much Does It Cost to Open a Coffee Shop in the UK?",
      meta_description: "UK coffee shop startup costs range from £25,000 for a modest local shop to over £150,000 for a city-centre fit-out. Full 2026 breakdown of every line item."
    )
  end

  def down
    post = BlogPost.find_by(slug: "startup-costs-for-coffee-shop")
    return unless post

    post.update!(
      meta_title: "Startup Costs for a Coffee Shop: A Practical Guide to Launching Your UK Café",
      meta_description: "Discover startup costs for coffee shop and learn a practical budget covering rent, equipment, staff, and sustainable packaging in the UK."
    )
  end
end
