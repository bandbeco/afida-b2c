# frozen_string_literal: true

# Public-facing blog controller for viewing published posts.
#
# Routes:
#   GET /blog       - Blog index (list all published posts)
#   GET /blog/:slug - Individual post page
#
class BlogPostsController < ApplicationController
  allow_unauthenticated_access

  # GET /blog
  def index
    @blog_posts = BlogPost.published.recent
  end

  # GET /blog/:slug
  def show
    @blog_post = BlogPost.published.find_by!(slug: params[:slug])

    # First try to get posts from the same category
    if @blog_post.blog_category_id.present?
      @related_posts = BlogPost.published
                               .where(blog_category_id: @blog_post.blog_category_id)
                               .where.not(id: @blog_post.id)
                               .order("RANDOM()")
                               .limit(3)
    else
      @related_posts = BlogPost.none
    end

    # If not enough posts from same category, fill with other posts
    if @related_posts.size < 3
      existing_ids = @related_posts.pluck(:id) << @blog_post.id
      additional = BlogPost.published
                           .where.not(id: existing_ids)
                           .order("RANDOM()")
                           .limit(3 - @related_posts.size)
      @related_posts = @related_posts.to_a + additional.to_a
    end
  end
end
