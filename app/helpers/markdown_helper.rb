# frozen_string_literal: true

# Helper for rendering Markdown content to HTML.
#
# Uses Redcarpet with:
# - HTML filtering (XSS prevention)
# - Hard line breaks (single newlines become <br>)
# - GitHub-flavored Markdown features (fenced code, tables, autolinks)
#
module MarkdownHelper
  # Renders Markdown text to HTML.
  #
  # @param text [String] Markdown content to render
  # @return [String] Rendered HTML (marked as html_safe)
  #
  # @example
  #   render_markdown("# Hello\n\nWorld")
  #   # => "<h1>Hello</h1>\n<p>World</p>"
  #
  def render_markdown(text)
    return "" if text.blank?

    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      hard_wrap: true,
      link_attributes: { rel: "noopener noreferrer" }
    )

    markdown = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      fenced_code_blocks: true,
      tables: true,
      strikethrough: true,
      no_intra_emphasis: true
    )

    markdown.render(text).html_safe
  end
end
