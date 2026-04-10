# frozen_string_literal: true

require "test_helper"

module Api
  module Internal
    module V1
      class BlogPostsControllerTest < ActionDispatch::IntegrationTest
        API_TOKEN = "test-internal-api-token-abc123"

        setup do
          ENV["AFIDA_INTERNAL_API_TOKEN"] = API_TOKEN
          @published_post = blog_posts(:published_post)
          @draft_post = blog_posts(:draft_post)
        end

        teardown do
          ENV.delete("AFIDA_INTERNAL_API_TOKEN")
        end

        # ====================================================================
        # Authentication
        # ====================================================================

        test "returns 401 without authorization header" do
          get api_internal_v1_blog_posts_url
          assert_response :unauthorized
          assert_equal "Unauthorized", response.parsed_body["error"]
        end

        test "returns 401 with invalid token" do
          get api_internal_v1_blog_posts_url, headers: auth_headers("wrong-token")
          assert_response :unauthorized
        end

        test "returns 503 when API token is not configured" do
          ENV.delete("AFIDA_INTERNAL_API_TOKEN")
          get api_internal_v1_blog_posts_url, headers: auth_headers(API_TOKEN)
          assert_response :service_unavailable
        end

        # ====================================================================
        # POST /api/internal/v1/blog_posts (create)
        # ====================================================================

        test "create returns 201 with valid minimal payload" do
          assert_difference "BlogPost.count", 1 do
            post api_internal_v1_blog_posts_url,
              params: { title: "Test API Post", body: "Some content." },
              headers: auth_headers,
              as: :json
          end

          assert_response :created
          data = response.parsed_body["data"]
          assert_equal "Test API Post", data["title"]
          assert_equal "test-api-post", data["slug"]
          assert_equal false, data["published"]
          assert_equal "/blog/test-api-post", data["url"]
          assert data["admin_url"].present?
          assert data["id"].present?
        end

        test "create defaults published to false" do
          post api_internal_v1_blog_posts_url,
            params: { title: "Draft Test", body: "Content." },
            headers: auth_headers,
            as: :json

          assert_response :created
          assert_equal false, response.parsed_body["data"]["published"]
          assert_equal false, BlogPost.find(response.parsed_body["data"]["id"]).published?
        end

        test "create accepts full structured payload" do
          params = {
            title: "Best Smoothie Cups for Takeaway Businesses",
            slug: "best-smoothie-cups-for-takeaway-businesses",
            body: "Full body content.",
            excerpt: "How to choose smoothie cups.",
            meta_title: "Best Smoothie Cups | Afida",
            meta_description: "A practical guide.",
            primary_keyword: "best smoothie cups",
            secondary_keywords: [ "smoothie cups", "takeaway smoothie cups" ],
            intro: "Choosing the right smoothie cup...",
            top_cta_heading: "Find the right smoothie cups",
            top_cta_body: "Afida supplies smoothie cups.",
            top_cta_buttons: [ { label: "Browse", url: "/shop", style: "primary" } ],
            decision_factors: [ { heading: "Size", body: "12oz to 20oz range." } ],
            buyer_setups: [ { title: "Budget", best_for: "Cafes", body: "A clear cup.", cta_label: "Browse", cta_url: "/shop" } ],
            recommended_options: [ { heading: "Smoothie cups", body: "Browse options.", url: "/shop" } ],
            faq_items: [ { question: "What size?", answer: "16oz." } ],
            final_cta_heading: "Ready?",
            final_cta_body: "Browse smoothie cups.",
            final_cta_buttons: [ { label: "Browse", url: "/shop" } ],
            branding_heading: "Branded cups",
            branding_body: "Worth it for brand recall.",
            conclusion: "Start with 16oz.",
            internal_link_targets: [ { label: "cups", url: "/shop" } ],
            target_category_slugs: [ "cups-and-drinks" ],
            target_collection_slugs: [],
            target_product_slugs: [],
            blog_category_id: blog_categories(:guides).id
          }

          assert_difference "BlogPost.count", 1 do
            post api_internal_v1_blog_posts_url,
              params: params,
              headers: auth_headers,
              as: :json
          end

          assert_response :created
          blog_post = BlogPost.find(response.parsed_body["data"]["id"])
          assert_equal "Best Smoothie Cups for Takeaway Businesses", blog_post.title
          assert_equal "best-smoothie-cups-for-takeaway-businesses", blog_post.slug
          assert_equal "Choosing the right smoothie cup...", blog_post.intro
          assert_equal 1, blog_post.faq_items.length
          assert_equal "What size?", blog_post.faq_items.first["question"]
          assert_equal [ "cups-and-drinks" ], blog_post.target_category_slugs
          assert_equal blog_categories(:guides).id, blog_post.blog_category_id
        end

        test "create auto-generates slug when omitted" do
          post api_internal_v1_blog_posts_url,
            params: { title: "My Great Article", body: "Content." },
            headers: auth_headers,
            as: :json

          assert_response :created
          assert_equal "my-great-article", response.parsed_body["data"]["slug"]
        end

        test "create returns 422 with validation errors" do
          post api_internal_v1_blog_posts_url,
            params: { title: "" },
            headers: auth_headers,
            as: :json

          assert_response :unprocessable_entity
          errors = response.parsed_body["errors"]
          assert errors["title"].present?
        end

        test "create returns 422 for malformed jsonb fields" do
          post api_internal_v1_blog_posts_url,
            params: { title: "Test", body: "Content", faq_items: "not an array" },
            headers: auth_headers,
            as: :json

          assert_response :unprocessable_entity
          assert response.parsed_body["errors"]["faq_items"].present?
        end

        test "create returns 422 for jsonb items missing required keys" do
          post api_internal_v1_blog_posts_url,
            params: { title: "Test", body: "Content", faq_items: [ { question: "Why?" } ] },
            headers: auth_headers,
            as: :json

          assert_response :unprocessable_entity
          assert response.parsed_body["errors"]["faq_items"].any? { |e| e.include?("missing required keys") }
        end

        test "create ignores published true and forces draft" do
          post api_internal_v1_blog_posts_url,
            params: { title: "Sneaky Publish", body: "Content.", published: true },
            headers: auth_headers,
            as: :json

          assert_response :created
          assert_equal false, response.parsed_body["data"]["published"]
        end

        # ====================================================================
        # GET /api/internal/v1/blog_posts/:id_or_slug (show)
        # ====================================================================

        test "show returns blog post by id" do
          get api_internal_v1_blog_post_url(@published_post.id), headers: auth_headers

          assert_response :ok
          data = response.parsed_body["data"]
          assert_equal @published_post.title, data["title"]
          assert_equal @published_post.slug, data["slug"]
          assert data["intro"].is_a?(String) || data["intro"].nil?
          assert data["faq_items"].is_a?(Array)
        end

        test "show returns blog post by slug" do
          get api_internal_v1_blog_post_url(@published_post.slug), headers: auth_headers

          assert_response :ok
          assert_equal @published_post.title, response.parsed_body["data"]["title"]
        end

        test "show returns all structured fields" do
          get api_internal_v1_blog_post_url(@draft_post.id), headers: auth_headers

          assert_response :ok
          data = response.parsed_body["data"]

          # Verify structured fields are present in response
          %w[intro conclusion top_cta_heading top_cta_body branding_heading branding_body
             final_cta_heading final_cta_body primary_keyword].each do |field|
            assert data.key?(field), "Expected response to include #{field}"
          end

          %w[faq_items decision_factors buyer_setups recommended_options
             top_cta_buttons final_cta_buttons internal_link_targets
             target_category_slugs target_collection_slugs target_product_slugs
             secondary_keywords].each do |field|
            assert data.key?(field), "Expected response to include #{field}"
          end
        end

        test "show returns 404 for non-existent post" do
          get api_internal_v1_blog_post_url("non-existent-slug"), headers: auth_headers
          assert_response :not_found
          assert_equal "Not found", response.parsed_body["error"]
        end

        # ====================================================================
        # GET /api/internal/v1/blog_posts (index)
        # ====================================================================

        test "index returns paginated list of blog posts" do
          get api_internal_v1_blog_posts_url, headers: auth_headers

          assert_response :ok
          body = response.parsed_body
          assert body["data"].is_a?(Array)
          assert body["meta"].present?
          assert body["meta"]["total"].present?
        end

        test "index filters by published status" do
          get api_internal_v1_blog_posts_url, params: { published: "false" }, headers: auth_headers

          assert_response :ok
          data = response.parsed_body["data"]
          assert data.all? { |p| p["published"] == false }
        end

        test "index filters by category_id" do
          guides = blog_categories(:guides)
          get api_internal_v1_blog_posts_url, params: { category_id: guides.id }, headers: auth_headers

          assert_response :ok
          data = response.parsed_body["data"]
          assert data.all? { |p| p["blog_category_id"] == guides.id }
        end

        test "index searches by query" do
          get api_internal_v1_blog_posts_url, params: { q: "Eco-Friendly" }, headers: auth_headers

          assert_response :ok
          data = response.parsed_body["data"]
          assert data.any? { |p| p["title"].include?("Eco-Friendly") }
        end

        test "index paginates results" do
          get api_internal_v1_blog_posts_url, params: { page: 1, per_page: 2 }, headers: auth_headers

          assert_response :ok
          data = response.parsed_body["data"]
          meta = response.parsed_body["meta"]
          assert data.length <= 2
          assert meta["page"].present?
          assert meta["per_page"].present?
        end

        test "index returns expected fields per item" do
          get api_internal_v1_blog_posts_url, headers: auth_headers

          assert_response :ok
          item = response.parsed_body["data"].first
          %w[id title slug published updated_at primary_keyword blog_category_id].each do |field|
            assert item.key?(field), "Expected index item to include #{field}"
          end
        end

        # ====================================================================
        # PATCH /api/internal/v1/blog_posts/:id_or_slug (update)
        # ====================================================================

        test "update modifies draft by id" do
          patch api_internal_v1_blog_post_url(@draft_post.id),
            params: { title: "Updated Title" },
            headers: auth_headers,
            as: :json

          assert_response :ok
          assert_equal "Updated Title", response.parsed_body["data"]["title"]
          assert_equal "Updated Title", @draft_post.reload.title
        end

        test "update modifies draft by slug" do
          patch api_internal_v1_blog_post_url(@draft_post.slug),
            params: { intro: "New intro text." },
            headers: auth_headers,
            as: :json

          assert_response :ok
          assert_equal "New intro text.", @draft_post.reload.intro
        end

        test "update replaces jsonb array fields" do
          patch api_internal_v1_blog_post_url(@draft_post.id),
            params: { faq_items: [ { question: "New Q?", answer: "New A." } ] },
            headers: auth_headers,
            as: :json

          assert_response :ok
          assert_equal 1, @draft_post.reload.faq_items.length
          assert_equal "New Q?", @draft_post.faq_items.first["question"]
        end

        test "update returns 422 for invalid data" do
          patch api_internal_v1_blog_post_url(@draft_post.id),
            params: { title: "" },
            headers: auth_headers,
            as: :json

          assert_response :unprocessable_entity
          assert response.parsed_body["errors"]["title"].present?
        end

        test "update returns 404 for non-existent post" do
          patch api_internal_v1_blog_post_url("non-existent"),
            params: { title: "X" },
            headers: auth_headers,
            as: :json

          assert_response :not_found
        end

        test "update prevents changing published to true" do
          patch api_internal_v1_blog_post_url(@draft_post.id),
            params: { published: true },
            headers: auth_headers,
            as: :json

          assert_response :ok
          assert_equal false, @draft_post.reload.published?
        end

        private

        def auth_headers(token = API_TOKEN)
          { "Authorization" => "Bearer #{token}" }
        end
      end
    end
  end
end
