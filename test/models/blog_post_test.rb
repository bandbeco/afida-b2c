# frozen_string_literal: true

require "test_helper"

class BlogPostTest < ActiveSupport::TestCase
  # ==========================================================================
  # Fixture Setup
  # ==========================================================================

  setup do
    @published_post = blog_posts(:published_post)
    @draft_post = blog_posts(:draft_post)
    @post_without_excerpt = blog_posts(:post_without_excerpt)
  end

  # ==========================================================================
  # Validations
  # ==========================================================================

  test "valid with all required attributes" do
    post = BlogPost.new(
      title: "Test Post",
      body: "This is the body content."
    )
    assert post.valid?
  end

  test "invalid without title" do
    post = BlogPost.new(body: "Content")
    assert_not post.valid?
    assert_includes post.errors[:title], "can't be blank"
  end

  test "invalid without body" do
    post = BlogPost.new(title: "Title")
    assert_not post.valid?
    assert_includes post.errors[:body], "can't be blank"
  end

  test "slug must be unique" do
    duplicate = BlogPost.new(
      title: "Different Title",
      slug: @published_post.slug,
      body: "Different body"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  # ==========================================================================
  # Callbacks - Slug Generation
  # ==========================================================================

  test "generates slug from title before validation" do
    post = BlogPost.new(title: "My New Blog Post", body: "Content here")
    post.valid?
    assert_equal "my-new-blog-post", post.slug
  end

  test "does not overwrite existing slug" do
    post = BlogPost.new(title: "My Title", slug: "custom-slug", body: "Content")
    post.valid?
    assert_equal "custom-slug", post.slug
  end

  test "handles special characters in title for slug" do
    post = BlogPost.new(title: "What's New in 2026?", body: "Content")
    post.valid?
    assert_equal "what-s-new-in-2026", post.slug
  end

  # ==========================================================================
  # Callbacks - Published At
  # ==========================================================================

  test "sets published_at when published changes from false to true" do
    @draft_post.update!(published: true)
    assert_not_nil @draft_post.published_at
    assert_in_delta Time.current, @draft_post.published_at, 2.seconds
  end

  test "does not change published_at when already set" do
    original_published_at = @published_post.published_at
    @published_post.update!(published: false)
    @published_post.update!(published: true)
    assert_equal original_published_at, @published_post.published_at
  end

  test "preserves published_at when unpublishing" do
    original_published_at = @published_post.published_at
    @published_post.update!(published: false)
    assert_equal original_published_at, @published_post.published_at
  end

  # ==========================================================================
  # Scopes
  # ==========================================================================

  test "published scope returns only published posts" do
    published_posts = BlogPost.published
    assert published_posts.all?(&:published?)
    assert_includes published_posts, @published_post
    assert_not_includes published_posts, @draft_post
  end

  test "drafts scope returns only unpublished posts" do
    draft_posts = BlogPost.drafts
    assert draft_posts.none?(&:published?)
    assert_includes draft_posts, @draft_post
    assert_not_includes draft_posts, @published_post
  end

  test "recent scope orders by published_at descending" do
    recent_posts = BlogPost.published.recent
    published_dates = recent_posts.pluck(:published_at).compact
    assert_equal published_dates, published_dates.sort.reverse
  end

  # ==========================================================================
  # Instance Methods
  # ==========================================================================

  test "to_param returns slug" do
    assert_equal @published_post.slug, @published_post.to_param
  end

  test "excerpt_with_fallback returns excerpt when present" do
    assert_equal @published_post.excerpt, @published_post.excerpt_with_fallback
  end

  test "excerpt_with_fallback returns truncated body when excerpt is blank" do
    fallback = @post_without_excerpt.excerpt_with_fallback
    assert_not_nil fallback
    assert fallback.length <= 160
    assert_not_includes fallback, "#" # Markdown stripped
  end

  test "meta_title_with_fallback returns meta_title when present" do
    assert_equal @published_post.meta_title, @published_post.meta_title_with_fallback
  end

  test "meta_title_with_fallback returns title when meta_title is blank" do
    assert_equal @draft_post.title, @draft_post.meta_title_with_fallback
  end

  test "meta_description_with_fallback returns meta_description when present" do
    assert_equal @published_post.meta_description, @published_post.meta_description_with_fallback
  end

  test "meta_description_with_fallback returns excerpt_with_fallback when meta_description is blank" do
    assert_equal @draft_post.excerpt_with_fallback, @draft_post.meta_description_with_fallback
  end
end
