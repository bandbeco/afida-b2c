# frozen_string_literal: true

require "test_helper"

class ArticleHelperTest < ActionView::TestCase
  include ArticleHelper

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
end
