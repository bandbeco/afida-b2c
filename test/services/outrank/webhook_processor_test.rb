# frozen_string_literal: true

require "test_helper"

module Outrank
  class WebhookProcessorTest < ActiveSupport::TestCase
    # ==========================================================================
    # T2.5: Handles batch of articles
    # ==========================================================================

    test "processes multiple articles in batch" do
      payload = {
        "event_type" => "publish_articles",
        "timestamp" => "2026-01-14T12:00:00Z",
        "data" => {
          "articles" => [
            article_data("article-1", "First Article", "first-article"),
            article_data("article-2", "Second Article", "second-article"),
            article_data("article-3", "Third Article", "third-article")
          ]
        }
      }

      assert_difference "BlogPost.count", 3 do
        result = Outrank::WebhookProcessor.new(payload).call
        assert_equal "success", result[:status]
        assert_equal 3, result[:processed]
      end
    end

    test "returns aggregate results for each article" do
      payload = {
        "event_type" => "publish_articles",
        "data" => {
          "articles" => [
            article_data("new-article-1", "New Article", "new-article-slug")
          ]
        }
      }

      result = Outrank::WebhookProcessor.new(payload).call

      assert_equal 1, result[:results].length
      assert_equal "created", result[:results].first[:status]
      assert_equal "new-article-1", result[:results].first[:outrank_id]
    end

    test "handles empty articles array" do
      payload = {
        "event_type" => "publish_articles",
        "data" => { "articles" => [] }
      }

      result = Outrank::WebhookProcessor.new(payload).call

      assert_equal "success", result[:status]
      assert_equal 0, result[:processed]
      assert_empty result[:results]
    end

    test "continues processing when one article fails" do
      payload = {
        "event_type" => "publish_articles",
        "data" => {
          "articles" => [
            article_data("good-1", "Good Article", "good-article-one"),
            { "id" => "bad-article", "title" => "", "slug" => "bad-slug", "content_markdown" => "" }, # Missing required title/body
            article_data("good-2", "Another Good", "good-article-two")
          ]
        }
      }

      # Should create 2 posts despite one failing
      assert_difference "BlogPost.count", 2 do
        result = Outrank::WebhookProcessor.new(payload).call
        assert_equal "partial", result[:status]
        assert_equal 3, result[:processed]
      end
    end

    test "returns error status for failed articles" do
      payload = {
        "event_type" => "publish_articles",
        "data" => {
          "articles" => [
            { "id" => "fail-article", "title" => "", "slug" => "fail-slug", "content_markdown" => "" }
          ]
        }
      }

      result = Outrank::WebhookProcessor.new(payload).call

      assert_equal "partial", result[:status]
      assert_equal 1, result[:results].length
      assert_equal "error", result[:results].first[:status]
      assert_includes result[:results].first[:message], "Title"
    end

    test "generates unique slug when collision occurs" do
      existing = blog_posts(:published_post)

      payload = {
        "event_type" => "publish_articles",
        "data" => {
          "articles" => [
            article_data("new-article-with-dup-slug", "New Article", existing.slug)
          ]
        }
      }

      # Should succeed with -2 suffix
      assert_difference "BlogPost.count", 1 do
        result = Outrank::WebhookProcessor.new(payload).call
        assert_equal "success", result[:status]
      end

      new_post = BlogPost.find_by(outrank_id: "new-article-with-dup-slug")
      assert_equal "#{existing.slug}-2", new_post.slug
    end

    # ==========================================================================
    # T3.2: Response includes skip reason for duplicates
    # ==========================================================================

    test "response includes skip status for duplicates" do
      existing = blog_posts(:outrank_imported)

      payload = {
        "event_type" => "publish_articles",
        "data" => {
          "articles" => [
            article_data(existing.outrank_id, "Duplicate", "duplicate-slug-new")
          ]
        }
      }

      assert_no_difference "BlogPost.count" do
        result = Outrank::WebhookProcessor.new(payload).call
        assert_equal "success", result[:status]
        assert_equal 1, result[:processed]

        article_result = result[:results].first
        assert_equal "skipped", article_result[:status]
        assert_equal "duplicate", article_result[:reason]
      end
    end

    private

    def article_data(id, title, slug)
      {
        "id" => id,
        "title" => title,
        "slug" => slug,
        "content_markdown" => "# #{title}\n\nContent for #{title}.",
        "meta_description" => "Description for #{title}"
      }
    end
  end
end
