# frozen_string_literal: true

module Admin
  # Admin controller for managing blog posts.
  #
  # Provides full CRUD operations for creating, editing,
  # and publishing blog posts from the admin interface.
  #
  class BlogPostsController < Admin::ApplicationController
    before_action :set_blog_post, only: %i[show edit update destroy]

    # GET /admin/blog_posts
    def index
      @blog_posts = BlogPost.order(created_at: :desc)
    end

    # GET /admin/blog_posts/:id
    def show
    end

    # GET /admin/blog_posts/new
    def new
      @blog_post = BlogPost.new
    end

    # GET /admin/blog_posts/:id/edit
    def edit
    end

    # POST /admin/blog_posts
    def create
      @blog_post = BlogPost.new(blog_post_params)

      if @blog_post.save
        redirect_to admin_blog_posts_url, notice: "Blog post was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /admin/blog_posts/:id
    def update
      if @blog_post.update(blog_post_params)
        redirect_to admin_blog_posts_url, notice: "Blog post was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/blog_posts/:id
    def destroy
      @blog_post.destroy!
      redirect_to admin_blog_posts_url, notice: "Blog post was successfully deleted."
    end

    private

    def set_blog_post
      @blog_post = BlogPost.find_by!(slug: params[:id])
    end

    def blog_post_params
      params.require(:blog_post).permit(
        :title,
        :slug,
        :body,
        :excerpt,
        :published,
        :meta_title,
        :meta_description,
        :cover_image
      )
    end
  end
end
