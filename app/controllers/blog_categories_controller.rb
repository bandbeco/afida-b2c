# frozen_string_literal: true

# Public-facing controller for viewing blog posts by category.
#
# Routes:
#   GET /blog/categories/:slug - Posts filtered by category
#
class BlogCategoriesController < ApplicationController
  allow_unauthenticated_access

  # GET /blog/categories/:slug
  def show
    @blog_category = BlogCategory.find_by!(slug: params[:slug])
    @blog_posts = @blog_category.blog_posts
                                .published
                                .recent
                                .includes(:blog_category)
                                .with_attached_cover_image
  end
end
