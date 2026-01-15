# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

module Webhooks
  class OutrankControllerTest < ActionDispatch::IntegrationTest
    setup do
      @valid_token = "test-outrank-token-123"
      Rails.application.credentials.stubs(:dig).with(:outrank, :access_token).returns(@valid_token)
    end

    # ==========================================================================
    # Authentication Tests (T1.1, T1.2, T1.3)
    # ==========================================================================

    test "returns 401 when Authorization header is missing" do
      post webhooks_outrank_url, params: valid_payload, as: :json

      assert_response :unauthorized
      assert_equal({ "error" => "Unauthorized", "message" => "Invalid or missing access token" }, response.parsed_body)
      assert_no_difference "BlogPost.count" do
        post webhooks_outrank_url, params: valid_payload, as: :json
      end
    end

    test "returns 401 when token is invalid" do
      post webhooks_outrank_url,
           params: valid_payload,
           headers: { "Authorization" => "Bearer wrong-token" },
           as: :json

      assert_response :unauthorized
      assert_equal({ "error" => "Unauthorized", "message" => "Invalid or missing access token" }, response.parsed_body)
    end

    test "returns 401 when Authorization header has wrong format" do
      post webhooks_outrank_url,
           params: valid_payload,
           headers: { "Authorization" => "Basic #{@valid_token}" },
           as: :json

      assert_response :unauthorized
    end

    test "processes request when token is valid" do
      post webhooks_outrank_url,
           params: valid_payload,
           headers: valid_auth_header,
           as: :json

      assert_response :success
    end

    # ==========================================================================
    # T6.1: Full success flow integration test
    # ==========================================================================

    test "creates blog posts from valid webhook payload" do
      payload = {
        "event_type" => "publish_articles",
        "timestamp" => "2026-01-14T12:00:00Z",
        "data" => {
          "articles" => [
            {
              "id" => "outrank-integration-test-1",
              "title" => "Integration Test Article",
              "slug" => "integration-test-article",
              "content_markdown" => "# Test Content\n\nThis is the body.",
              "meta_description" => "Test description",
              "tags" => [ "integration-testing" ]
            }
          ]
        }
      }

      assert_difference "BlogPost.count", 1 do
        post webhooks_outrank_url, params: payload, headers: valid_auth_header, as: :json
      end

      assert_response :success

      body = response.parsed_body
      assert_equal "success", body["status"]
      assert_equal 1, body["processed"]
      assert_equal "created", body["results"].first["status"]

      post = BlogPost.find_by(outrank_id: "outrank-integration-test-1")
      assert_equal "Integration Test Article", post.title
      assert_equal "integration-test-article", post.slug
      assert_equal false, post.published
      assert_equal "integration-testing", post.blog_category.name
    end

    test "response matches API contract format" do
      post webhooks_outrank_url, params: valid_payload, headers: valid_auth_header, as: :json

      assert_response :success

      body = response.parsed_body
      assert body.key?("status"), "Response should include 'status'"
      assert body.key?("processed"), "Response should include 'processed'"
      assert body.key?("results"), "Response should include 'results'"
      assert_kind_of Array, body["results"]

      result = body["results"].first
      assert result.key?("outrank_id"), "Result should include 'outrank_id'"
      assert result.key?("status"), "Result should include 'status'"
    end

    test "creates categories from tags" do
      payload = {
        "event_type" => "publish_articles",
        "data" => {
          "articles" => [
            {
              "id" => "category-test-article",
              "title" => "Category Test",
              "slug" => "category-test-unique",
              "content_markdown" => "# Content",
              "tags" => [ "new-category-from-webhook" ]
            }
          ]
        }
      }

      assert_difference "BlogCategory.count", 1 do
        post webhooks_outrank_url, params: payload, headers: valid_auth_header, as: :json
      end

      category = BlogCategory.find_by(name: "new-category-from-webhook")
      assert_not_nil category
      assert_equal "new-category-from-webhook", category.slug
    end

    # ==========================================================================
    # T6.2: Malformed JSON
    # ==========================================================================

    test "returns error for missing data.articles" do
      payload = {
        "event_type" => "publish_articles",
        "data" => {}
      }

      post webhooks_outrank_url, params: payload, headers: valid_auth_header, as: :json

      assert_response :success
      body = response.parsed_body
      assert_equal 0, body["processed"]
    end

    # ==========================================================================
    # T6.3: Missing required fields
    # ==========================================================================

    test "returns error status when article missing required fields" do
      payload = {
        "event_type" => "publish_articles",
        "data" => {
          "articles" => [
            {
              "id" => "missing-title",
              "slug" => "missing-title-article",
              "content_markdown" => "# Content"
              # Missing: title
            }
          ]
        }
      }

      assert_no_difference "BlogPost.count" do
        post webhooks_outrank_url, params: payload, headers: valid_auth_header, as: :json
      end

      assert_response :success
      body = response.parsed_body
      assert_equal "partial", body["status"]
      assert_equal "error", body["results"].first["status"]
      assert_includes body["results"].first["message"], "Title"
    end

    test "processes valid articles even when some fail" do
      payload = {
        "event_type" => "publish_articles",
        "data" => {
          "articles" => [
            {
              "id" => "good-article",
              "title" => "Good Article",
              "slug" => "good-article-unique",
              "content_markdown" => "# Good content"
            },
            {
              "id" => "bad-article",
              "slug" => "bad-article"
              # Missing: title, content_markdown
            }
          ]
        }
      }

      assert_difference "BlogPost.count", 1 do
        post webhooks_outrank_url, params: payload, headers: valid_auth_header, as: :json
      end

      body = response.parsed_body
      assert_equal "partial", body["status"]
      assert_equal 2, body["processed"]
    end

    private

    def valid_auth_header
      { "Authorization" => "Bearer #{@valid_token}" }
    end

    def valid_payload
      {
        "event_type" => "publish_articles",
        "timestamp" => "2026-01-14T12:00:00Z",
        "data" => {
          "articles" => [
            {
              "id" => "test-article-#{SecureRandom.hex(4)}",
              "title" => "Test Article from Outrank",
              "slug" => "test-article-#{SecureRandom.hex(4)}",
              "content_markdown" => "# Hello World\n\nThis is test content.",
              "meta_description" => "Test meta description"
            }
          ]
        }
      }
    end
  end
end
