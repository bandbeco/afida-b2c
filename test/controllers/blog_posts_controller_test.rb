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

  test "index displays category badges when present" do
    get blog_posts_url

    assert_response :success
    # Posts with categories should display category name
    assert_includes response.body, @published_post.blog_category.name
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

  # ==========================================================================
  # Show Action - Structured Posts
  # ==========================================================================

  test "show renders structured layout for structured posts" do
    structured = blog_posts(:structured_post)
    get blog_post_url(structured)

    assert_response :success
    assert_includes response.body, "Switching to compostable cups"
    assert_includes response.body, "practical, affordable way"
  end

  test "show renders top CTA section for structured posts" do
    structured = blog_posts(:structured_post)
    get blog_post_url(structured)

    assert_response :success
    assert_includes response.body, structured.top_cta_heading
    assert_includes response.body, structured.top_cta_body
    assert_includes response.body, "Shop Compostable Cups"
    assert_includes response.body, "/collections/compostable-cups"
  end

  test "show renders decision factors for structured posts" do
    structured = blog_posts(:structured_post)
    get blog_post_url(structured)

    assert_response :success
    assert_includes response.body, "Material"
    assert_includes response.body, "PLA-lined cups"
    assert_includes response.body, "Size Range"
  end

  test "show renders buyer setups for structured posts" do
    structured = blog_posts(:structured_post)
    get blog_post_url(structured)

    assert_response :success
    assert_includes response.body, "High-Volume Cafe"
    assert_includes response.body, "Cafes serving 200+ cups per day"
    assert_includes response.body, "View Bulk Options"
  end

  test "show renders recommended options for structured posts" do
    structured = blog_posts(:structured_post)
    get blog_post_url(structured)

    assert_response :success
    assert_includes response.body, "Afida Classic PLA Cup"
    assert_includes response.body, "/products/afida-classic-pla-cup"
  end

  test "show renders branding section for structured posts" do
    structured = blog_posts(:structured_post)
    get blog_post_url(structured)

    assert_response :success
    assert_includes response.body, structured.branding_heading
    assert_includes response.body, structured.branding_body
  end

  test "show renders FAQ items for structured posts" do
    structured = blog_posts(:structured_post)
    get blog_post_url(structured)

    assert_response :success
    assert_includes response.body, "Are PLA cups really compostable?"
    assert_includes response.body, "EN 13432"
    assert_includes response.body, "Can I print my logo"
  end

  test "show renders final CTA for structured posts" do
    structured = blog_posts(:structured_post)
    get blog_post_url(structured)

    assert_response :success
    assert_includes response.body, structured.final_cta_heading
    assert_includes response.body, "Browse All Cups"
    assert_includes response.body, "/collections/cups"
  end

  test "show renders conclusion for structured posts" do
    structured = blog_posts(:structured_post)
    get blog_post_url(structured)

    assert_response :success
    assert_includes response.body, "practical, affordable way"
  end

  test "show does not render legacy body for structured posts" do
    structured = blog_posts(:structured_post)
    get blog_post_url(structured)

    assert_response :success
    assert_not_includes response.body, "Fallback body content for structured post"
  end

  test "show still renders legacy body for non-structured posts" do
    get blog_post_url(@published_post)

    assert_response :success
    assert_includes response.body, "eco-friendly packaging"
    assert_not @published_post.structured?
  end

  test "show preserves SEO meta tags for structured posts" do
    structured = blog_posts(:structured_post)
    get blog_post_url(structured)

    assert_response :success
    assert_includes response.body, structured.meta_title
    assert_match(/meta.*description.*#{Regexp.escape(structured.meta_description[0..20])}/, response.body)
  end

  test "show renders partially structured post with only intro and conclusion" do
    partial = blog_posts(:partially_structured_post)
    get blog_post_url(partial)

    assert_response :success
    assert_includes response.body, "gaining traction across the UK"
    assert_includes response.body, "easier than you think"
    assert_not_includes response.body, "Key Decision Factors"
    assert_not_includes response.body, "Frequently Asked Questions"
    assert_not_includes response.body, "Fallback body for partially structured post"
  end

  test "show does not render FAQ schema for posts without faq items" do
    partial = blog_posts(:partially_structured_post)
    get blog_post_url(partial)

    assert_response :success
    assert_not_includes response.body, "FAQPage"
  end

  test "show renders FAQ schema markup for structured posts" do
    structured = blog_posts(:structured_post)
    get blog_post_url(structured)

    assert_response :success
    assert_includes response.body, "FAQPage"
    assert_includes response.body, "Are PLA cups really compostable?"
  end
end
