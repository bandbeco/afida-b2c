class RewriteEcoFriendlyPackagingBlogMeta < ActiveRecord::Migration[8.1]
  def up
    post = BlogPost.find_by(slug: "eco-friendly-packaging")
    return unless post

    post.update!(
      meta_title: "Biodegradable Packaging for UK Food Businesses: 2026 Guide",
      meta_description: "Biodegradable, compostable, and recyclable packaging compared for UK food businesses. Materials, EN 13432 certification, and costs. 2026 buyer's guide."
    )
  end

  def down
    post = BlogPost.find_by(slug: "eco-friendly-packaging")
    return unless post

    post.update!(
      meta_title: "A Buyer's Guide to Eco-Friendly Packaging",
      meta_description: "Choose the right eco friendly packaging for your UK café or restaurant. This guide breaks down compostable vs. recyclable materials, costs, and certifications."
    )
  end
end
