class RewriteCompostableVsBiodegradableBlogMeta < ActiveRecord::Migration[8.1]
  def up
    post = BlogPost.find_by(slug: "compostable-vs-biodegradable")
    return unless post

    post.update!(
      meta_title: "Compostable vs Biodegradable: What's the Difference?",
      meta_description: "No, biodegradable and compostable are not the same. Compostable breaks down to soil under specified conditions; biodegradable just degrades. UK 2026 guide."
    )
  end

  def down
    post = BlogPost.find_by(slug: "compostable-vs-biodegradable")
    return unless post

    post.update!(
      meta_title: "Compostable vs Biodegradable: A No-Nonsense Guide for UK Food Businesses",
      meta_description: "Confused about compostable vs biodegradable? Our definitive guide for UK hospitality businesses clarifies the differences, certifications, and costs."
    )
  end
end
