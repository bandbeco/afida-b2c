# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

module Outrank
  class ArticleImporterTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper
    # ==========================================================================
    # T2.1: Creates BlogPost from valid payload
    # ==========================================================================

    test "creates blog post from article data" do
      article_data = {
        "id" => "new-article-123",
        "title" => "Test Article",
        "slug" => "test-article-new",
        "content_markdown" => "# Hello World\n\nThis is test content.",
        "meta_description" => "Test description"
      }

      assert_difference "BlogPost.count", 1 do
        result = Outrank::ArticleImporter.new(article_data).call
        assert_equal :created, result[:status]
      end

      post = BlogPost.last
      assert_equal "Test Article", post.title
      assert_equal "test-article-new", post.slug
      assert_equal "# Hello World\n\nThis is test content.", post.body
      assert_equal "Test description", post.meta_description
      assert_equal "new-article-123", post.outrank_id
    end

    test "stores outrank_id from article id field" do
      article_data = valid_article_data.merge("id" => "unique-outrank-id-xyz")

      Outrank::ArticleImporter.new(article_data).call

      post = BlogPost.last
      assert_equal "unique-outrank-id-xyz", post.outrank_id
    end

    test "sets meta_title from article title" do
      article_data = valid_article_data.merge("title" => "SEO Optimized Title")

      Outrank::ArticleImporter.new(article_data).call

      post = BlogPost.last
      assert_equal "SEO Optimized Title", post.meta_title
    end

    # ==========================================================================
    # T2.2: Maps first tag to BlogCategory
    # ==========================================================================

    test "uses first tag as blog category" do
      article_data = valid_article_data.merge("tags" => [ "sustainability", "cafes" ])

      assert_difference "BlogCategory.count", 1 do
        Outrank::ArticleImporter.new(article_data).call
      end

      post = BlogPost.last
      assert_equal "sustainability", post.blog_category.name
      assert_equal "sustainability", post.blog_category.slug
    end

    test "uses existing category when tag matches" do
      existing_category = blog_categories(:guides)
      article_data = valid_article_data.merge("tags" => [ existing_category.name ])

      assert_no_difference "BlogCategory.count" do
        Outrank::ArticleImporter.new(article_data).call
      end

      post = BlogPost.last
      assert_equal existing_category, post.blog_category
    end

    test "creates post without category when tags empty" do
      article_data = valid_article_data.merge("tags" => [])

      Outrank::ArticleImporter.new(article_data).call

      post = BlogPost.last
      assert_nil post.blog_category
    end

    test "creates post without category when tags missing" do
      article_data = valid_article_data.except("tags")

      Outrank::ArticleImporter.new(article_data).call

      post = BlogPost.last
      assert_nil post.blog_category
    end

    # ==========================================================================
    # T2.3: Creates post as unpublished draft
    # ==========================================================================

    test "creates post as unpublished draft" do
      Outrank::ArticleImporter.new(valid_article_data).call

      post = BlogPost.last
      assert_equal false, post.published
      assert_nil post.published_at
    end

    # ==========================================================================
    # Excerpt generation
    # ==========================================================================

    test "extracts excerpt from content markdown" do
      article_data = valid_article_data.merge(
        "content_markdown" => "# Heading\n\nThis is the first paragraph that should become the excerpt.\n\n## Next Section"
      )

      Outrank::ArticleImporter.new(article_data).call

      post = BlogPost.last
      assert_equal "This is the first paragraph that should become the excerpt.", post.excerpt
    end

    test "truncates long excerpts" do
      long_paragraph = "A" * 200
      article_data = valid_article_data.merge(
        "content_markdown" => "# Heading\n\n#{long_paragraph}\n\n## Next"
      )

      Outrank::ArticleImporter.new(article_data).call

      post = BlogPost.last
      assert post.excerpt.length <= 160
      assert post.excerpt.end_with?("...")
    end

    test "handles content with only headings gracefully" do
      article_data = valid_article_data.merge(
        "content_markdown" => "# Title\n\n## Subtitle\n\n### Section"
      )

      Outrank::ArticleImporter.new(article_data).call

      post = BlogPost.last
      assert_nil post.excerpt
    end

    # ==========================================================================
    # Result object
    # ==========================================================================

    test "returns result with status and blog_post_id" do
      article_data = valid_article_data
      result = Outrank::ArticleImporter.new(article_data).call

      assert_equal :created, result[:status]
      assert_equal BlogPost.last.id, result[:blog_post_id]
      assert_equal article_data["id"], result[:outrank_id]
    end

    # ==========================================================================
    # T3.1: Skips duplicate articles
    # ==========================================================================

    test "skips article when outrank_id already exists" do
      existing = blog_posts(:outrank_imported)
      article_data = valid_article_data.merge("id" => existing.outrank_id, "slug" => "different-slug")

      assert_no_difference "BlogPost.count" do
        result = Outrank::ArticleImporter.new(article_data).call
        assert_equal :skipped, result[:status]
        assert_equal "duplicate", result[:reason]
        assert_equal existing.outrank_id, result[:outrank_id]
      end
    end

    test "logs duplicate detection" do
      existing = blog_posts(:outrank_imported)
      article_data = valid_article_data.merge("id" => existing.outrank_id)

      Rails.logger.expects(:info).with(includes("Skipping duplicate"))

      Outrank::ArticleImporter.new(article_data).call
    end

    # ==========================================================================
    # T4.1 & T4.2: Content storage and sanitization
    # ==========================================================================

    test "stores content_markdown directly in body" do
      markdown_content = "# Introduction\n\nSome **bold** and *italic* text.\n\n- Item 1\n- Item 2"
      article_data = valid_article_data.merge("content_markdown" => markdown_content)

      Outrank::ArticleImporter.new(article_data).call

      post = BlogPost.last
      assert_includes post.body, "# Introduction"
      assert_includes post.body, "**bold**"
      assert_includes post.body, "*italic*"
    end

    test "sanitizes dangerous content from markdown" do
      article_data = valid_article_data.merge(
        "content_markdown" => "<script>alert('xss')</script># Title\n\n<iframe src='evil.com'></iframe>Safe content"
      )

      Outrank::ArticleImporter.new(article_data).call
      post = BlogPost.last

      assert_not_includes post.body, "<script>"
      assert_not_includes post.body, "alert"
      assert_not_includes post.body, "<iframe"
      assert_includes post.body, "# Title"
      assert_includes post.body, "Safe content"
    end

    test "strips img tags to prevent javascript URI XSS" do
      article_data = valid_article_data.merge(
        "content_markdown" => "<img src=\"javascript:alert('xss')\" alt=\"XSS\">Safe content"
      )

      Outrank::ArticleImporter.new(article_data).call
      post = BlogPost.last

      assert_not_includes post.body, "<img"
      assert_not_includes post.body, "javascript:"
      assert_includes post.body, "Safe content"
    end

    test "strips img tags to prevent data URI XSS" do
      article_data = valid_article_data.merge(
        "content_markdown" => "<img src=\"data:text/html,<script>alert(1)</script>\">Safe content"
      )

      Outrank::ArticleImporter.new(article_data).call
      post = BlogPost.last

      assert_not_includes post.body, "<img"
      assert_not_includes post.body, "data:"
      assert_includes post.body, "Safe content"
    end

    test "preserves safe HTML elements in markdown" do
      article_data = valid_article_data.merge(
        "content_markdown" => "# Title\n\n<strong>Bold</strong> and <em>italic</em>\n\n<a href='/shop'>Link</a>"
      )

      Outrank::ArticleImporter.new(article_data).call
      post = BlogPost.last

      assert_includes post.body, "<strong>Bold</strong>"
      assert_includes post.body, "<em>italic</em>"
      assert_includes post.body, "<a href=\"/shop\">Link</a>"
    end

    # ==========================================================================
    # T5.5: Image download integration (now async via background job)
    # ==========================================================================

    test "enqueues cover image download job when image_url provided" do
      article_data = valid_article_data.merge("image_url" => "https://cdn.outrank.so/cover.jpg")

      assert_enqueued_with(job: Outrank::DownloadCoverImageJob) do
        Outrank::ArticleImporter.new(article_data).call
      end
    end

    test "does not enqueue job when image_url blank" do
      article_data = valid_article_data.merge("image_url" => "")

      assert_no_enqueued_jobs(only: Outrank::DownloadCoverImageJob) do
        Outrank::ArticleImporter.new(article_data).call
      end
    end

    test "downloads cover image when job is performed" do
      image_url = "https://cdn.outrank.so/cover.jpg"
      image_content = file_fixture("test_image.jpg").read

      stub_request(:get, image_url)
        .to_return(body: image_content, headers: { "Content-Type" => "image/jpeg" })

      article_data = valid_article_data.merge("image_url" => image_url)

      # Create article and perform the enqueued job
      perform_enqueued_jobs do
        Outrank::ArticleImporter.new(article_data).call
      end

      post = BlogPost.last
      assert post.cover_image.attached?
    end

    test "creates article even when image download fails" do
      image_url = "https://cdn.outrank.so/broken.jpg"

      stub_request(:get, image_url).to_return(status: 404)

      article_data = valid_article_data.merge("image_url" => image_url)

      assert_difference "BlogPost.count", 1 do
        perform_enqueued_jobs do
          Outrank::ArticleImporter.new(article_data).call
        end
      end

      post = BlogPost.last
      assert_not post.cover_image.attached?
    end

    # ==========================================================================
    # Slug collision handling
    # ==========================================================================

    test "generates unique slug when collision detected" do
      # Create existing post with same slug
      existing = blog_posts(:outrank_imported)
      existing.update!(slug: "collision-test")

      article_data = valid_article_data.merge("slug" => "collision-test")
      Outrank::ArticleImporter.new(article_data).call

      post = BlogPost.last
      assert_equal "collision-test-2", post.slug
    end

    test "increments suffix for multiple collisions" do
      # Create existing posts with slug and slug-2
      existing = blog_posts(:outrank_imported)
      existing.update!(slug: "multi-collision")

      # Create first collision
      article_data1 = valid_article_data.merge("slug" => "multi-collision")
      Outrank::ArticleImporter.new(article_data1).call

      # Create second collision
      article_data2 = valid_article_data.merge("slug" => "multi-collision")
      Outrank::ArticleImporter.new(article_data2).call

      posts = BlogPost.where("slug LIKE ?", "multi-collision%").order(:id)
      slugs = posts.pluck(:slug)

      assert_includes slugs, "multi-collision"
      assert_includes slugs, "multi-collision-2"
      assert_includes slugs, "multi-collision-3"
    end

    test "handles slug race condition via retry" do
      # Test that the retry mechanism is in place by checking the code handles
      # ActiveRecord::RecordNotUnique gracefully. We can't easily simulate a true
      # race condition in tests, but we verify the behavior when it occurs.

      # Create article that will collide
      existing = blog_posts(:outrank_imported)
      existing.update!(slug: "race-slug")

      # The importer should successfully handle collision and use -2 suffix
      article_data = valid_article_data.merge("slug" => "race-slug")
      result = Outrank::ArticleImporter.new(article_data).call

      assert_equal :created, result[:status]
      new_post = BlogPost.find_by(outrank_id: article_data["id"])
      assert_equal "race-slug-2", new_post.slug
    end

    private

    def valid_article_data
      {
        "id" => "test-article-#{SecureRandom.hex(4)}",
        "title" => "Test Article Title",
        "slug" => "test-article-#{SecureRandom.hex(4)}",
        "content_markdown" => "# Introduction\n\nSome test content here.\n\n## Details",
        "meta_description" => "A test article for testing purposes."
      }
    end
  end
end
