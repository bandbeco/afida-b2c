require "test_helper"

class BlogSeoTest < ActionDispatch::IntegrationTest
  test "sitemap includes published ContentItems" do
    # Create a published content item
    content_draft = SeoAiEngine::ContentDraft.create!(
      seo_ai_content_brief: SeoAiEngine::ContentBrief.create!(
        seo_ai_opportunity: SeoAiEngine::Opportunity.create!(
          target_keyword: "test keyword",
          opportunity_type: "new_content",
          score: 75,
          search_volume: 100,
          competition_difficulty: 50,
          target_url: "/blog/test"
        ),
        target_keyword: "test keyword",
        search_intent: "informational",
        suggested_structure: { sections: [] },
        competitor_analysis: {},
        product_linking_strategy: {},
        internal_linking_strategy: {},
        ai_model_used: "claude-3-5-sonnet",
        generation_cost_gbp: 0.10
      ),
      content_type: "blog_post",
      title: "Test Blog Post",
      body: "# Test\n\nThis is a test blog post.",
      meta_title: "Test Blog Post | Afida",
      meta_description: "A test blog post",
      target_keywords: [ "test" ],
      status: "approved",
      quality_score: 80,
      review_notes: {},
      reviewer_model: "claude-3-5-sonnet",
      generation_cost_gbp: 0.15
    )

    content_item = SeoAiEngine::ContentItem.create!(
      content_draft: content_draft,
      slug: "test-blog-post",
      title: "Test Blog Post",
      body: "# Test\n\nThis is a test blog post.",
      meta_title: "Test Blog Post | Afida",
      meta_description: "A test blog post",
      target_keywords: [ "test" ],
      published_at: Time.current,
      author_credit: "Afida Editorial Team",
      related_product_ids: [],
      related_category_ids: []
    )

    get sitemap_path(format: :xml)
    assert_response :success
    assert_includes response.body, blog_path(content_item)
  end

  test "blog index page has canonical URL" do
    get blogs_path
    assert_response :success
    assert_select 'link[rel="canonical"]'
  end

  test "blog show page has canonical URL" do
    # Use fixture data
    content_item = seo_ai_engine_content_items(:published_one)
    get blog_path(content_item)
    assert_response :success
    assert_select 'link[rel="canonical"]'
  end

  test "blog show page has Article structured data" do
    content_item = seo_ai_engine_content_items(:published_one)
    get blog_path(content_item)
    assert_response :success
    assert_includes response.body, '"@type":"Article"'
    assert_includes response.body, content_item.title
  end

  test "blog show page includes article metadata" do
    content_item = seo_ai_engine_content_items(:published_one)
    get blog_path(content_item)
    assert_response :success

    # Check for title
    assert_select "h1", text: content_item.title

    # Check for publication date
    assert_includes response.body, content_item.published_at.strftime("%B %d, %Y")

    # Check for author
    assert_includes response.body, "Afida Editorial Team"
  end
end
