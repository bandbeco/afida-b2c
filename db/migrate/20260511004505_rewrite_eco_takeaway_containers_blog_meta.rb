class RewriteEcoTakeawayContainersBlogMeta < ActiveRecord::Migration[8.1]
  def up
    post = BlogPost.find_by(slug: "eco-friendly-takeaway-containers")
    return unless post

    post.update!(
      meta_title: "Eco-Friendly Takeaway Containers: 2026 UK Buying Guide",
      meta_description: "Compostable, recycled, and bagasse takeaway containers for UK cafés and restaurants. Sizes, costs, hot and cold food performance, and council disposal."
    )
  end

  def down
    post = BlogPost.find_by(slug: "eco-friendly-takeaway-containers")
    return unless post

    post.update!(
      meta_title: "Eco Friendly Takeaway Containers: A Guide for UK Food Businesses",
      meta_description: "A concise guide to eco friendly takeaway containers for UK food businesses - materials, performance, costs, and branding to help you choose."
    )
  end
end
