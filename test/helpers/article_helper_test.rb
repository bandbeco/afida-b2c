# frozen_string_literal: true

require "test_helper"

class ArticleHelperTest < ActionView::TestCase
  include ArticleHelper
  # blog_post_shop_links resolves category paths via CategoriesHelper, which is
  # mixed into the same view context at render time.
  include CategoriesHelper

  # ==========================================================================
  # XSS Protection Tests - render_markdown sanitization
  # ==========================================================================

  test "renders markdown to HTML" do
    result = render_markdown("# Hello\n\nWorld")

    assert_includes result, "<h1>Hello</h1>"
    assert_includes result, "<p>World</p>"
  end

  test "strips script tags from markdown" do
    result = render_markdown("<script>alert('xss')</script>Safe content")

    assert_not_includes result, "<script>"
    assert_not_includes result, "alert"
    assert_includes result, "Safe content"
  end

  test "strips iframe tags from markdown" do
    result = render_markdown("<iframe src='evil.com'></iframe>Safe content")

    assert_not_includes result, "<iframe"
    assert_not_includes result, "evil.com"
    assert_includes result, "Safe content"
  end

  test "strips javascript protocol from markdown links" do
    result = render_markdown("[Click me](javascript:alert('xss'))")

    assert_not_includes result, "javascript:"
    # Link should still render, but without the dangerous href
    assert_includes result, "Click me"
  end

  test "strips data URI from markdown links" do
    result = render_markdown("[Click me](data:text/html,<script>alert(1)</script>)")

    assert_not_includes result, "data:"
    assert_not_includes result, "<script>"
  end

  test "allows safe http links" do
    result = render_markdown("[Visit site](https://example.com)")

    assert_includes result, 'href="https://example.com"'
    assert_includes result, "Visit site"
  end

  test "allows relative links" do
    result = render_markdown("[Shop](/shop)")

    assert_includes result, 'href="/shop"'
    assert_includes result, "Shop"
  end

  test "handles blank content" do
    assert_equal "", render_markdown("")
    assert_equal "", render_markdown(nil)
  end

  test "renders tables from markdown" do
    markdown = "| Header |\n|---|\n| Cell |"
    result = render_markdown(markdown)

    assert_includes result, "<table>"
    assert_includes result, "<th>Header</th>"
    assert_includes result, "<td>Cell</td>"
  end

  test "renders fenced code blocks" do
    result = render_markdown("```ruby\nputs 'hello'\n```")

    assert_includes result, "<pre>"
    assert_includes result, "<code"
  end

  # ==========================================================================
  # blog_post_shop_links - resolve target slugs to commercial links
  # ==========================================================================

  test "blog_post_shop_links resolves a collection slug to name and path" do
    collection = collections(:coffee_shop_essentials)
    post = BlogPost.new(target_collection_slugs: [ collection.slug ], target_category_slugs: [])

    links = blog_post_shop_links(post)

    assert_equal 1, links.length
    assert_equal collection.name, links.first[:name]
    assert_equal collection_path(collection), links.first[:path]
  end

  test "blog_post_shop_links resolves a nested category slug to its nested path" do
    child = categories(:child_hot_cups)
    post = BlogPost.new(target_collection_slugs: [], target_category_slugs: [ child.slug ])

    links = blog_post_shop_links(post)

    assert_equal 1, links.length
    assert_equal child.name, links.first[:name]
    assert_equal category_subcategory_path(child.parent.slug, child.slug), links.first[:path]
  end

  test "blog_post_shop_links resolves a top-level category slug to its flat path" do
    top_level = categories(:cups)
    post = BlogPost.new(target_collection_slugs: [], target_category_slugs: [ top_level.slug ])

    links = blog_post_shop_links(post)

    assert_equal 1, links.length
    assert_equal category_path(top_level), links.first[:path]
  end

  test "blog_post_shop_links drops slugs that do not resolve to a record" do
    post = BlogPost.new(
      target_collection_slugs: [ "nope-collection" ],
      target_category_slugs: [ "nope-category" ]
    )

    assert_empty blog_post_shop_links(post)
  end

  test "blog_post_shop_links returns empty array when no target slugs" do
    post = BlogPost.new(target_collection_slugs: [], target_category_slugs: [])

    assert_empty blog_post_shop_links(post)
  end

  test "blog_post_shop_links lists collections before categories" do
    collection = collections(:coffee_shop_essentials)
    category = categories(:cups)
    post = BlogPost.new(
      target_collection_slugs: [ collection.slug ],
      target_category_slugs: [ category.slug ]
    )

    links = blog_post_shop_links(post)

    assert_equal collection.name, links.first[:name]
    assert_equal 2, links.length
  end

  # ==========================================================================
  # free_shipping_threshold_label - formatted free-shipping threshold
  # ==========================================================================

  test "free_shipping_threshold_label formats the threshold as whole pounds" do
    assert_equal "£100", free_shipping_threshold_label
  end

  test "free_shipping_threshold_label derives from Shipping::FREE_SHIPPING_THRESHOLD" do
    original = Shipping::FREE_SHIPPING_THRESHOLD
    Shipping.send(:remove_const, :FREE_SHIPPING_THRESHOLD)
    Shipping.const_set(:FREE_SHIPPING_THRESHOLD, BigDecimal("150"))

    assert_equal "£150", free_shipping_threshold_label
  ensure
    Shipping.send(:remove_const, :FREE_SHIPPING_THRESHOLD)
    Shipping.const_set(:FREE_SHIPPING_THRESHOLD, original)
  end
end
