# frozen_string_literal: true

require "test_helper"

class MarkdownHelperTest < ActionView::TestCase
  include MarkdownHelper

  # ==========================================================================
  # Basic Rendering
  # ==========================================================================

  test "renders paragraph text" do
    result = render_markdown("Hello world")
    assert_includes result, "<p>Hello world</p>"
  end

  test "renders headings" do
    result = render_markdown("# Heading 1\n## Heading 2")
    assert_includes result, "<h1>Heading 1</h1>"
    assert_includes result, "<h2>Heading 2</h2>"
  end

  test "renders bold text" do
    result = render_markdown("**bold text**")
    assert_includes result, "<strong>bold text</strong>"
  end

  test "renders italic text" do
    result = render_markdown("*italic text*")
    assert_includes result, "<em>italic text</em>"
  end

  test "renders links" do
    result = render_markdown("[Afida](https://afida.com)")
    assert_includes result, '<a href="https://afida.com"'
    assert_includes result, "Afida</a>"
  end

  test "renders unordered lists" do
    result = render_markdown("- Item 1\n- Item 2")
    assert_includes result, "<ul>"
    assert_includes result, "<li>Item 1</li>"
    assert_includes result, "<li>Item 2</li>"
  end

  test "renders ordered lists" do
    result = render_markdown("1. First\n2. Second")
    assert_includes result, "<ol>"
    assert_includes result, "<li>First</li>"
  end

  # ==========================================================================
  # GitHub-Flavored Markdown Features
  # ==========================================================================

  test "renders fenced code blocks" do
    result = render_markdown("```ruby\nputs 'hello'\n```")
    assert_includes result, "<code"
    assert_includes result, "puts"
  end

  test "renders tables" do
    markdown = "| Header |\n|--------|\n| Cell |"
    result = render_markdown(markdown)
    assert_includes result, "<table>"
    assert_includes result, "<th>Header</th>"
    assert_includes result, "<td>Cell</td>"
  end

  test "autolinks URLs" do
    result = render_markdown("Visit https://afida.com for more")
    assert_includes result, '<a href="https://afida.com"'
  end

  # ==========================================================================
  # Security - XSS Prevention
  # ==========================================================================

  test "filters raw HTML script tags" do
    result = render_markdown("<script>alert('xss')</script>")
    # Redcarpet's filter_html removes the script tags (XSS prevention)
    # The text content may remain but is harmless without the script context
    assert_not_includes result, "<script>"
    assert_not_includes result, "</script>"
  end

  test "filters onclick attributes" do
    result = render_markdown('<a href="#" onclick="alert(1)">click</a>')
    assert_not_includes result, "onclick"
  end

  test "filters iframe tags" do
    result = render_markdown('<iframe src="evil.com"></iframe>')
    assert_not_includes result, "<iframe"
  end

  # ==========================================================================
  # Edge Cases
  # ==========================================================================

  test "returns empty string for nil input" do
    result = render_markdown(nil)
    assert_equal "", result
  end

  test "returns empty string for blank input" do
    result = render_markdown("")
    assert_equal "", result
  end

  test "handles hard line breaks" do
    result = render_markdown("Line 1\nLine 2")
    # With hard_wrap: true, single newlines become <br>
    assert_includes result, "<br>"
  end
end
