# frozen_string_literal: true

module Admin
  # Admin controller for managing blog categories.
  #
  # Provides CRUD operations for creating and managing
  # blog categories from the admin interface.
  #
  class BlogCategoriesController < Admin::ApplicationController
    before_action :set_blog_category, only: %i[edit update destroy]

    # GET /admin/blog_categories
    def index
      @blog_categories = BlogCategory.order(:name).includes(:blog_posts)
    end

    # GET /admin/blog_categories/new
    def new
      @blog_category = BlogCategory.new
    end

    # GET /admin/blog_categories/:id/edit
    def edit
    end

    # POST /admin/blog_categories
    def create
      @blog_category = BlogCategory.new(blog_category_params)

      if @blog_category.save
        redirect_to admin_blog_categories_url, notice: "Category was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /admin/blog_categories/:id
    def update
      if @blog_category.update(blog_category_params)
        redirect_to admin_blog_categories_url, notice: "Category was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/blog_categories/:id
    def destroy
      @blog_category.destroy!
      redirect_to admin_blog_categories_url, notice: "Category was successfully deleted."
    end

    private

    def set_blog_category
      @blog_category = BlogCategory.find_by!(slug: params[:id])
    end

    def blog_category_params
      params.require(:blog_category).permit(:name, :slug)
    end
  end
end
