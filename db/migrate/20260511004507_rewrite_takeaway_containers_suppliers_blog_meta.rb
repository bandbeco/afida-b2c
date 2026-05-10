class RewriteTakeawayContainersSuppliersBlogMeta < ActiveRecord::Migration[8.1]
  def up
    post = BlogPost.find_by(slug: "takeaway-containers")
    return unless post

    post.update!(
      meta_title: "7 Best UK Takeaway Container Suppliers (2026)",
      meta_description: "Compare the 7 best UK takeaway container suppliers in 2026. Eco-friendly and conventional options, branded boxes, costs, lead times, and minimum orders."
    )
  end

  def down
    post = BlogPost.find_by(slug: "takeaway-containers")
    return unless post

    post.update!(
      meta_title: "7 Best Suppliers for Eco-Friendly Takeaway Containers in the UK (2026)",
      meta_description: "Discover the UK's best suppliers for sustainable takeaway containers. A guide for hospitality businesses on materials, branding, cost, and eco-friendly options."
    )
  end
end
