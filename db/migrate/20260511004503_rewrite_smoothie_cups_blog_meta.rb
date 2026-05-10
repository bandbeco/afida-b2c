class RewriteSmoothieCupsBlogMeta < ActiveRecord::Migration[8.1]
  def up
    post = BlogPost.find_by(slug: "smoothie-cups")
    return unless post

    post.update!(
      meta_title: "Best Smoothie Cups: Sizes, Materials & Lids for Cafés",
      meta_description: "Compare the best smoothie cups for cafés and juice bars. PET, PLA, paper, and rPET options in 9 to 24oz, with matching lids and straws. UK guide."
    )
  end

  def down
    post = BlogPost.find_by(slug: "smoothie-cups")
    return unless post

    post.update!(
      meta_title: "The Definitive Guide to Choosing the Best Smoothie Cups",
      meta_description: "Discover the best smoothie cups for your UK café. Our guide compares PET, PLA, and paper options, sizes, and lids to help you serve Instagram-worthy drinks."
    )
  end
end
