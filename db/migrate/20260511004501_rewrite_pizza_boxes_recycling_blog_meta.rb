class RewritePizzaBoxesRecyclingBlogMeta < ActiveRecord::Migration[8.1]
  def up
    post = BlogPost.find_by(slug: "can-you-recycle-pizza-boxes")
    return unless post

    post.update!(
      meta_title: "Can You Recycle Pizza Boxes? UK Rules, Grease & What to Do",
      meta_description: "Yes, clean pizza boxes recycle. Greasy or food-stained parts go in food waste, not recycling. UK 2026 rules, contamination tips, and what councils accept."
    )
  end

  def down
    post = BlogPost.find_by(slug: "can-you-recycle-pizza-boxes")
    return unless post

    post.update!(
      meta_title: "Can You Recycle Pizza Boxes? A 2026 Guide for UK Hospitality",
      meta_description: "Can you recycle pizza boxes in the UK? Get our 2026 guide for hospitality. Clarifies rules, contamination, & offers eco-friendly solutions."
    )
  end
end
