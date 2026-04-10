# frozen_string_literal: true

module Api
  module Internal
    module V1
      class BlogPostsController < ApplicationController
        before_action :set_blog_post, only: [ :show, :update ]

        # POST /api/internal/v1/blog_posts
        def create
          @blog_post = BlogPost.new(blog_post_params)
          @blog_post.published = false

          if @blog_post.save
            render json: { data: serialize_full(@blog_post) }, status: :created
          else
            render json: { errors: @blog_post.errors.messages }, status: :unprocessable_entity
          end
        end

        # GET /api/internal/v1/blog_posts/:id_or_slug
        def show
          render json: { data: serialize_full(@blog_post) }
        end

        # GET /api/internal/v1/blog_posts
        def index
          posts = BlogPost.all

          posts = posts.where(published: params[:published] == "true") if params[:published].present?
          posts = posts.where(blog_category_id: params[:category_id]) if params[:category_id].present?
          posts = posts.where("title ILIKE ?", "%#{params[:q]}%") if params[:q].present?

          page = (params[:page] || 1).to_i
          per_page = (params[:per_page] || 25).to_i.clamp(1, 100)
          total = posts.count
          posts = posts.order(updated_at: :desc).offset((page - 1) * per_page).limit(per_page)

          render json: {
            data: posts.map { |p| serialize_summary(p) },
            meta: { total: total, page: page, per_page: per_page }
          }
        end

        # PATCH /api/internal/v1/blog_posts/:id_or_slug
        def update
          update_params = blog_post_params
          update_params.delete(:published)

          if @blog_post.update(update_params)
            render json: { data: serialize_full(@blog_post) }
          else
            render json: { errors: @blog_post.errors.messages }, status: :unprocessable_entity
          end
        end

        private

        def set_blog_post
          id_or_slug = params[:id_or_slug]
          @blog_post = if id_or_slug.match?(/\A\d+\z/)
            BlogPost.find_by(id: id_or_slug)
          else
            BlogPost.find_by(slug: id_or_slug)
          end

          render json: { error: "Not found" }, status: :not_found unless @blog_post
        end

        def blog_post_params
          scalar_fields = params.permit(
            :title, :slug, :body, :excerpt, :meta_title, :meta_description,
            :primary_keyword, :intro, :conclusion,
            :top_cta_heading, :top_cta_body,
            :branding_heading, :branding_body,
            :final_cta_heading, :final_cta_body,
            :blog_category_id, :published
          ).to_h

          # Extract JSONB array fields from the parsed JSON body directly,
          # bypassing strong parameters so the model can validate their shape.
          json_body = request.body.rewind && JSON.parse(request.body.read) rescue {}
          jsonb_fields = {}
          BlogPost::JSONB_ARRAY_FIELDS.each do |field|
            key = field.to_s
            jsonb_fields[key] = json_body[key] if json_body.key?(key)
          end

          scalar_fields.merge(jsonb_fields)
        end

        def serialize_full(post)
          {
            id: post.id,
            title: post.title,
            slug: post.slug,
            body: post.body,
            excerpt: post.excerpt,
            published: post.published,
            published_at: post.published_at,
            meta_title: post.meta_title,
            meta_description: post.meta_description,
            primary_keyword: post.primary_keyword,
            secondary_keywords: post.secondary_keywords,
            intro: post.intro,
            conclusion: post.conclusion,
            top_cta_heading: post.top_cta_heading,
            top_cta_body: post.top_cta_body,
            top_cta_buttons: post.top_cta_buttons,
            decision_factors: post.decision_factors,
            buyer_setups: post.buyer_setups,
            recommended_options: post.recommended_options,
            faq_items: post.faq_items,
            branding_heading: post.branding_heading,
            branding_body: post.branding_body,
            final_cta_heading: post.final_cta_heading,
            final_cta_body: post.final_cta_body,
            final_cta_buttons: post.final_cta_buttons,
            internal_link_targets: post.internal_link_targets,
            target_category_slugs: post.target_category_slugs,
            target_collection_slugs: post.target_collection_slugs,
            target_product_slugs: post.target_product_slugs,
            blog_category_id: post.blog_category_id,
            url: "/blog/#{post.slug}",
            admin_url: "/admin/blog/posts/#{post.id}/edit",
            created_at: post.created_at,
            updated_at: post.updated_at
          }
        end

        def serialize_summary(post)
          {
            id: post.id,
            title: post.title,
            slug: post.slug,
            published: post.published,
            published_at: post.published_at,
            updated_at: post.updated_at,
            primary_keyword: post.primary_keyword,
            blog_category_id: post.blog_category_id
          }
        end
      end
    end
  end
end
