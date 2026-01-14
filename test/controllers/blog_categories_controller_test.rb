# frozen_string_literal: true

require "test_helper"

class BlogCategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @guides_category = blog_categories(:guides)
    @news_category = blog_categories(:news)
    @published_post = blog_posts(:published_post)

    # Set host to avoid www redirect in routes
    host! "example.com"
  end

  # ==========================================================================
  # Show Action
  # ==========================================================================

  test "show displays posts in category" do
    get blog_category_url(@guides_category)

    assert_response :success
    assert_includes response.body, @guides_category.name
  end

  test "show only displays published posts" do
    # Draft post in guides category shouldn't appear
    draft = blog_posts(:draft_post)
    draft.update!(blog_category: @guides_category)

    get blog_category_url(@guides_category)

    assert_response :success
    assert_includes response.body, @published_post.title
    assert_not_includes response.body, draft.title
  end

  test "show returns 404 for non-existent category" do
    get blog_category_url(slug: "non-existent-category")
    assert_response :not_found
  end

  test "show includes breadcrumb back to blog index" do
    get blog_category_url(@guides_category)

    assert_response :success
    assert_includes response.body, blog_posts_path
  end

  test "show sets correct meta title" do
    get blog_category_url(@guides_category)

    assert_response :success
    assert_includes response.body, "#{@guides_category.name} | Blog | Afida"
  end

  test "show displays post count" do
    get blog_category_url(@guides_category)

    assert_response :success
    # Should show "X articles in this category"
    assert_match(/\d+ articles? in this category/, response.body)
  end

  test "show displays empty state when category has no published posts" do
    # Create empty category
    empty_category = BlogCategory.create!(name: "Empty Category", slug: "empty-category")

    get blog_category_url(empty_category)

    assert_response :success
    assert_includes response.body, "No posts in this category"
  end
end
