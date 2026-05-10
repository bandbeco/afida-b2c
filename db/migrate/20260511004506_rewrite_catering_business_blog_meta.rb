class RewriteCateringBusinessBlogMeta < ActiveRecord::Migration[8.1]
  def up
    post = BlogPost.find_by(slug: "how-to-start-a-catering-business")
    return unless post

    post.update!(
      meta_title: "How to Start a Catering Business in the UK: Step-by-Step",
      meta_description: "Start a catering business in the UK with our step-by-step guide. Registration, food safety, business structure, equipment, and startup costs. 2026 edition."
    )
  end

  def down
    post = BlogPost.find_by(slug: "how-to-start-a-catering-business")
    return unless post

    post.update!(
      meta_title: "How to Start a Catering Business in the UK: Your Complete Guide",
      meta_description: "Thinking about how to start a catering business? Our complete UK guide covers business plans, food safety, sourcing, and marketing for your new venture."
    )
  end
end
