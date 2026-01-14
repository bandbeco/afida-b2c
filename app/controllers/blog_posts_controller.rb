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
  end
end
