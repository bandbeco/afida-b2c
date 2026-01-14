# frozen_string_literal: true

require "test_helper"

class BlogPostsControllerTest < ActionDispatch::IntegrationTest
  # ==========================================================================
  # Fixture Setup
  # ==========================================================================

  setup do
    @published_post = blog_posts(:published_post)
    @draft_post = blog_posts(:draft_post)
    @second_published_post = blog_posts(:second_published_post)

    # Set host to avoid www redirect in routes
    host! "example.com"
  end

  # ==========================================================================
  # Index Action
  # ==========================================================================

  test "index shows only published posts" do
    get blog_posts_url

    assert_response :success
    assert_includes response.body, @published_post.title
    assert_includes response.body, @second_published_post.title
    assert_not_includes response.body, @draft_post.title
  end

  test "index orders posts by published_at descending" do
    get blog_posts_url

    assert_response :success
    # second_published_post (1.day.ago) should appear before published_post (3.days.ago)
    assert response.body.index(@second_published_post.title) < response.body.index(@published_post.title)
  end

  test "index displays excerpts" do
    get blog_posts_url

    assert_response :success
    assert_includes response.body, @published_post.excerpt
  end

  test "index displays published dates" do
    get blog_posts_url

    assert_response :success
    # Check that date is displayed in some readable format
    assert_match(/#{@published_post.published_at.strftime("%B")}/, response.body)
  end

  test "index links to individual posts" do
    get blog_posts_url

    assert_response :success
    assert_includes response.body, blog_post_path(@published_post)
  end

  # ==========================================================================
  # Show Action
  # ==========================================================================

  test "show displays published post" do
    get blog_post_url(@published_post)

    assert_response :success
    assert_includes response.body, @published_post.title
  end

  test "show renders markdown body" do
    get blog_post_url(@published_post)

    assert_response :success
    # Published post has markdown headings
    assert_includes response.body, "<h1>"
  end

  test "show returns 404 for draft post" do
    get blog_post_url(@draft_post)
    assert_response :not_found
  end

  test "show returns 404 for non-existent slug" do
    get blog_post_url(slug: "non-existent-post")
    assert_response :not_found
  end

  test "show sets meta title" do
    get blog_post_url(@published_post)

    assert_response :success
    assert_includes response.body, @published_post.meta_title_with_fallback
  end

  test "show sets meta description" do
    get blog_post_url(@published_post)

    assert_response :success
    # Meta description should be in a meta tag
    assert_match(/meta.*description.*#{Regexp.escape(@published_post.meta_description_with_fallback[0..30])}/, response.body)
  end

  test "show displays published date" do
    get blog_post_url(@published_post)

    assert_response :success
    assert_match(/#{@published_post.published_at.strftime("%B")}/, response.body)
  end

  test "show links back to blog index" do
    get blog_post_url(@published_post)

    assert_response :success
    assert_includes response.body, blog_posts_path
  end
end
