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
                            .includes(:blog_category)
                            .with_attached_cover_image
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
      add_json_parse_errors

      if @blog_post.errors.none? && @blog_post.save
        redirect_to admin_blog_posts_url, notice: "Blog post was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /admin/blog_posts/:id
    def update
      @blog_post.assign_attributes(blog_post_params)
      add_json_parse_errors

      if @blog_post.errors.none? && @blog_post.save
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
      @blog_post = BlogPost.find(params[:id])
    end

    def blog_post_params
      permitted = params.require(:blog_post).permit(
        :title,
        :slug,
        :body,
        :excerpt,
        :published,
        :meta_title,
        :meta_description,
        :cover_image,
        :blog_category_id,
        :intro,
        :top_cta_heading,
        :top_cta_body,
        :branding_heading,
        :branding_body,
        :final_cta_heading,
        :final_cta_body,
        :conclusion,
        :primary_keyword,
        *BlogPost::JSONB_ARRAY_FIELDS
      )

      # JSONB fields arrive as JSON strings from textareas. Parse each one,
      # falling back to [] for blank input. On parse failure, store the error
      # and assign [] so model validations don't add a redundant "must be an
      # array" message; the controller error is the only one the user sees.
      BlogPost::JSONB_ARRAY_FIELDS.each do |field|
        raw = permitted[field]
        next if raw.nil?

        text = raw.to_s.strip
        if text.blank?
          permitted[field] = []
        else
          permitted[field] = JSON.parse(text)
        end
      rescue JSON::ParserError
        permitted[field] = []
        @json_parse_errors ||= {}
        @json_parse_errors[field] = "contains invalid JSON"
      end

      permitted
    end

    def add_json_parse_errors
      return unless @json_parse_errors

      @json_parse_errors.each do |field, message|
        @blog_post.errors.add(field, message)
      end
    end
  end
end
