class RewritePaperNapkinsBlogMeta < ActiveRecord::Migration[8.1]
  def up
    post = BlogPost.find_by(slug: "paper-napkins")
    return unless post

    post.update!(
      meta_title: "Best Paper Napkins for Restaurants & Cafés: 2026 UK Guide",
      meta_description: "Compare the best paper napkin brands for restaurants and cafés. Ply, absorbency, half-sheet vs full, dispenser fit, cost per pack. UK foodservice guide."
    )
  end

  def down
    post = BlogPost.find_by(slug: "paper-napkins")
    return unless post

    post.update!(
      meta_title: "A Buyer's Guide to Choosing Paper Napkins for Hospitality",
      meta_description: "Discover how to choose the right paper napkins for your hospitality business. Our guide covers ply, materials, folds, and custom branding for UK businesses."
    )
  end
end
