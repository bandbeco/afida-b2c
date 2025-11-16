require "application_system_test_case"

class BlogDisplayTest < ApplicationSystemTestCase
  test "visiting the blog index shows published articles" do
    content_item = seo_ai_engine_content_items(:published_one)

    visit blogs_path

    assert_selector "h1", text: "Afida Blog"
    assert_selector "h2", text: content_item.title
    assert_text content_item.published_at.strftime("%B %d, %Y")
  end

  test "clicking an article shows full content" do
    content_item = seo_ai_engine_content_items(:published_one)

    visit blogs_path
    click_on content_item.title

    # Verify we're on the article page
    assert_current_path blog_path(content_item)

    # Verify article content is displayed
    assert_selector "h1", text: content_item.title
    assert_text "Afida Editorial Team"
    assert_text content_item.published_at.strftime("%B %d, %Y")

    # Verify markdown is rendered (looking for HTML elements that markdown creates)
    page_html = page.html
    assert_includes page_html, "<h1>Introduction</h1>", "Markdown headers should be rendered"
    assert_includes page_html, "<h2>Benefits</h2>", "Markdown subheaders should be rendered"
  end

  test "blog article page includes structured data" do
    content_item = seo_ai_engine_content_items(:published_one)

    visit blog_path(content_item)

    page_html = page.html
    assert_includes page_html, '"@type":"Article"', "No Article structured data found"
    assert_includes page_html, content_item.title, "Article title not in structured data"
    assert_includes page_html, "Afida Editorial Team", "Author not in structured data"
  end

  test "blog article with related products displays product cards" do
    # Create a content item with related products
    product = products(:single_wall_cups)

    content_draft = SeoAiEngine::ContentDraft.create!(
      seo_ai_content_brief: SeoAiEngine::ContentBrief.create!(
        seo_ai_opportunity: SeoAiEngine::Opportunity.create!(
          target_keyword: "coffee cups guide",
          opportunity_type: "new_content",
          score: 85,
          search_volume: 200,
          competition_difficulty: 40,
          target_url: "/blog/coffee-cups-guide"
        ),
        target_keyword: "coffee cups guide",
        search_intent: "informational",
        suggested_structure: { sections: [] },
        competitor_analysis: {},
        product_linking_strategy: {},
        internal_linking_strategy: {},
        ai_model_used: "claude-3-5-sonnet",
        generation_cost_gbp: 0.10
      ),
      content_type: "blog_post",
      title: "Coffee Cups Guide",
      body: "# Guide\n\nAll about coffee cups.",
      meta_title: "Coffee Cups Guide | Afida",
      meta_description: "A guide to coffee cups",
      target_keywords: [ "coffee cups" ],
      status: "approved",
      quality_score: 85,
      review_notes: {},
      reviewer_model: "claude-3-5-sonnet",
      generation_cost_gbp: 0.15
    )

    content_item = SeoAiEngine::ContentItem.create!(
      content_draft: content_draft,
      slug: "coffee-cups-guide",
      title: "Coffee Cups Guide",
      body: "# Guide\n\nAll about coffee cups.",
      meta_title: "Coffee Cups Guide | Afida",
      meta_description: "A guide to coffee cups",
      target_keywords: [ "coffee cups" ],
      published_at: Time.current,
      author_credit: "Afida Editorial Team",
      related_product_ids: [ product.id ],
      related_category_ids: []
    )

    visit blog_path(content_item)

    # Verify related products section exists
    assert_selector "h2", text: "Related Products"
    assert_selector "h3", text: product.name
  end

  test "blog index shows empty state when no posts published" do
    # Delete all content items
    SeoAiEngine::ContentItem.destroy_all

    visit blogs_path

    assert_text "No blog posts published yet"
  end
end
