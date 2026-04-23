# frozen_string_literal: true

require "reverse_markdown"

class MarkdownForAgentsMiddleware
  MARKDOWN_MEDIA_TYPE = "text/markdown"
  TOKEN_CHAR_RATIO = 4

  def initialize(app)
    @app = app
  end

  def call(env)
    wants_markdown = markdown_requested?(env)
    env = rewrite_accept_to_html(env) if wants_markdown

    status, headers, body = @app.call(env)
    return [ status, headers, body ] unless wants_markdown
    return [ status, headers, body ] unless convertible?(status, headers)

    html = extract_body(body)
    markdown = ReverseMarkdown.convert(html, unknown_tags: :bypass, github_flavored: true)

    new_headers = headers.dup
    new_headers["Content-Type"] = "#{MARKDOWN_MEDIA_TYPE}; charset=utf-8"
    new_headers["Content-Length"] = markdown.bytesize.to_s
    new_headers["Vary"] = append_vary(new_headers["Vary"])
    new_headers["x-markdown-tokens"] = estimate_tokens(markdown).to_s

    [ status, new_headers, [ markdown ] ]
  end

  private

  def markdown_requested?(env)
    accept = env["HTTP_ACCEPT"].to_s
    return false if accept.empty?

    accept.split(",").any? { |part| part.split(";").first.to_s.strip.casecmp?(MARKDOWN_MEDIA_TYPE) }
  end

  def rewrite_accept_to_html(env)
    env.merge("HTTP_ACCEPT" => "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8")
  end

  def convertible?(status, headers)
    return false unless status == 200
    content_type = headers["Content-Type"] || headers["content-type"]
    content_type.to_s.include?("text/html")
  end

  def extract_body(body)
    buffer = +""
    body.each { |part| buffer << part.to_s }
    buffer
  ensure
    body.close if body.respond_to?(:close)
  end

  def append_vary(existing)
    entries = existing.to_s.split(",").map(&:strip).reject(&:empty?)
    entries << "Accept" unless entries.any? { |e| e.casecmp?("Accept") }
    entries.join(", ")
  end

  def estimate_tokens(text)
    (text.length.to_f / TOKEN_CHAR_RATIO).ceil
  end
end
