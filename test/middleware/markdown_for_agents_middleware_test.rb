# frozen_string_literal: true

require "test_helper"

class MarkdownForAgentsMiddlewareTest < ActiveSupport::TestCase
  HTML_BODY = "<html><body><h1>Hello</h1><p>World</p></body></html>"

  def html_app(body: HTML_BODY, status: 200, content_type: "text/html; charset=utf-8")
    ->(_env) { [ status, { "Content-Type" => content_type }, [ body ] ] }
  end

  def call(env, app: html_app)
    MarkdownForAgentsMiddleware.new(app).call(env)
  end

  test "passes through when Accept header does not request markdown" do
    env = Rack::MockRequest.env_for("/")
    status, headers, body = call(env)

    assert_equal 200, status
    assert_equal "text/html; charset=utf-8", headers["Content-Type"]
    assert_equal [ HTML_BODY ], body
  end

  test "converts HTML to markdown when Accept: text/markdown" do
    env = Rack::MockRequest.env_for("/", "HTTP_ACCEPT" => "text/markdown")
    status, headers, body = call(env)

    assert_equal 200, status
    assert_equal "text/markdown; charset=utf-8", headers["Content-Type"]
    markdown = body.is_a?(Array) ? body.join : body.to_s
    assert_match(/# Hello/, markdown)
    assert_match(/World/, markdown)
  end

  test "sets x-markdown-tokens header with estimated token count" do
    env = Rack::MockRequest.env_for("/", "HTTP_ACCEPT" => "text/markdown")
    _status, headers, _body = call(env)

    assert headers["x-markdown-tokens"].present?
    assert_match(/\A\d+\z/, headers["x-markdown-tokens"])
    assert_operator headers["x-markdown-tokens"].to_i, :>, 0
  end

  test "appends Accept to Vary header" do
    env = Rack::MockRequest.env_for("/", "HTTP_ACCEPT" => "text/markdown")
    _status, headers, _body = call(env)

    assert_match(/Accept/, headers["Vary"].to_s)
  end

  test "preserves existing Vary header entries" do
    app = ->(_env) {
      [ 200, { "Content-Type" => "text/html", "Vary" => "Accept-Encoding" }, [ HTML_BODY ] ]
    }
    env = Rack::MockRequest.env_for("/", "HTTP_ACCEPT" => "text/markdown")
    _status, headers, _body = call(env, app: app)

    assert_includes headers["Vary"], "Accept-Encoding"
    assert_includes headers["Vary"], "Accept"
  end

  test "handles Accept header with quality values" do
    env = Rack::MockRequest.env_for("/", "HTTP_ACCEPT" => "text/markdown,text/html;q=0.9")
    _status, headers, _body = call(env)

    assert_equal "text/markdown; charset=utf-8", headers["Content-Type"]
  end

  test "does not convert when Accept header is text/html only" do
    env = Rack::MockRequest.env_for("/", "HTTP_ACCEPT" => "text/html")
    _status, headers, body = call(env)

    assert_equal "text/html; charset=utf-8", headers["Content-Type"]
    assert_equal [ HTML_BODY ], body
  end

  test "does not convert non-HTML responses" do
    app = ->(_env) { [ 200, { "Content-Type" => "application/json" }, [ '{"ok":true}' ] ] }
    env = Rack::MockRequest.env_for("/api/thing", "HTTP_ACCEPT" => "text/markdown")
    _status, headers, body = call(env, app: app)

    assert_equal "application/json", headers["Content-Type"]
    assert_equal [ '{"ok":true}' ], body
  end

  test "does not convert redirect responses" do
    app = ->(_env) {
      [ 301, { "Content-Type" => "text/html", "Location" => "/new" }, [ "" ] ]
    }
    env = Rack::MockRequest.env_for("/old", "HTTP_ACCEPT" => "text/markdown")
    status, headers, _body = call(env, app: app)

    assert_equal 301, status
    assert_equal "text/html", headers["Content-Type"]
    assert_equal "/new", headers["Location"]
  end

  test "updates Content-Length when converting" do
    env = Rack::MockRequest.env_for("/", "HTTP_ACCEPT" => "text/markdown")
    _status, headers, body = call(env)

    markdown = body.is_a?(Array) ? body.join : body.to_s
    assert_equal markdown.bytesize.to_s, headers["Content-Length"]
  end

  test "HEAD Content-Type and Content-Length match the markdown GET representation" do
    stacked = MarkdownForAgentsMiddleware.new(Rack::Head.new(html_app))
    accept = { "HTTP_ACCEPT" => "text/markdown" }
    _get_status, get_headers, get_body = stacked.call(Rack::MockRequest.env_for("/", accept))
    _head_status, head_headers, head_body = stacked.call(Rack::MockRequest.env_for("/", accept.merge(method: "HEAD")))

    assert_equal "text/markdown; charset=utf-8", head_headers["Content-Type"]
    assert_equal get_headers["Content-Type"], head_headers["Content-Type"]
    assert_equal get_headers["Content-Length"], head_headers["Content-Length"]
    assert_equal get_body.join.bytesize.to_s, head_headers["Content-Length"]
    assert_equal [], head_body
  end
end

class MarkdownForAgentsMiddlewareNotFoundTest < ActiveSupport::TestCase
  NOT_FOUND_HTML = "<html><body><h1>Not found</h1><p>Try the <a href='/sitemap.xml'>sitemap</a>.</p></body></html>"

  def call(status)
    app = ->(_env) { [ status, { "Content-Type" => "text/html; charset=utf-8" }, [ NOT_FOUND_HTML ] ] }
    MarkdownForAgentsMiddleware.new(app).call(Rack::MockRequest.env_for("/missing", "HTTP_ACCEPT" => "text/markdown"))
  end

  test "converts 404 HTML responses so agents get a markdown not-found body" do
    status, headers, body = call(404)

    assert_equal 404, status
    assert_equal "text/markdown; charset=utf-8", headers["Content-Type"]
    assert_match(/# Not found/, body.join)
    assert_includes body.join, "[sitemap](/sitemap.xml)"
  end

  test "converts 410 HTML responses" do
    status, headers, _body = call(410)

    assert_equal 410, status
    assert_equal "text/markdown; charset=utf-8", headers["Content-Type"]
  end

  test "does not convert server error responses" do
    _status, headers, body = call(500)

    assert_equal "text/html; charset=utf-8", headers["Content-Type"]
    assert_equal [ NOT_FOUND_HTML ], body
  end
end

class MarkdownForAgentsMiddlewareRackHeadersTest < ActiveSupport::TestCase
  HTML = "<html><body><h1>Hi</h1></body></html>"

  def call(env_overrides = {}, headers: { "content-type" => "text/html", "content-length" => "999", "etag" => "\"abc\"" })
    app = ->(_env) { [ 200, headers, [ HTML ] ] }
    MarkdownForAgentsMiddleware.new(app).call(Rack::MockRequest.env_for("/", { "HTTP_ACCEPT" => "text/markdown" }.merge(env_overrides)))
  end

  test "does not duplicate lowercase Rack 3 headers from a plain Hash" do
    _status, headers, body = call

    assert_equal headers.keys.size, headers.keys.map(&:downcase).uniq.size, "duplicate header names: #{headers.keys}"
    assert_equal "text/markdown; charset=utf-8", headers["content-type"]
    assert_equal body.join.bytesize.to_s, headers["content-length"]
  end

  test "drops the HTML ETag because the markdown body is a different representation" do
    _status, headers, _body = call

    assert_nil headers["etag"]
    assert_nil headers["ETag"]
  end
end
