# frozen_string_literal: true

require "reverse_markdown"

class MarkdownForAgentsMiddleware
  MARKDOWN_MEDIA_TYPE = "text/markdown"
  TOKEN_CHAR_RATIO = 4
  CONVERTIBLE_STATUSES = [ 200, 404, 410 ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    wants_markdown = markdown_requested?(env)
    env = rewrite_accept_to_html(env) if wants_markdown
    head_request = env["REQUEST_METHOD"] == "HEAD"
    env = env_as_get(env) if head_request

    status, headers, body = @app.call(env)
    unless wants_markdown && convertible?(status, headers)
      return [ status, headers, head_request ? empty_body(body) : body ]
    end

    html = extract_body(body)
    markdown = ReverseMarkdown.convert(html, unknown_tags: :bypass, github_flavored: true)

    new_headers = Rack::Headers[headers]
    new_headers["content-type"] = "#{MARKDOWN_MEDIA_TYPE}; charset=utf-8"
    new_headers["content-length"] = markdown.bytesize.to_s
    new_headers["vary"] = append_vary(new_headers["vary"])
    new_headers.delete("etag")
    new_headers["x-markdown-tokens"] = estimate_tokens(markdown).to_s

    [ status, new_headers, head_request ? [] : [ markdown ] ]
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
    return false unless CONVERTIBLE_STATUSES.include?(status)
    Rack::Headers[headers]["content-type"].to_s.include?("text/html")
  end

  def extract_body(body)
    buffer = +""
    body.each { |part| buffer << part.to_s }
    buffer
  ensure
    body.close if body.respond_to?(:close)
  end

  def env_as_get(env)
    env.dup.tap do |get_env|
      get_env["REQUEST_METHOD"] = "GET"
      get_env.delete("action_dispatch.request")
    end
  end

  def empty_body(body)
    body.close if body.respond_to?(:close)
    []
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
