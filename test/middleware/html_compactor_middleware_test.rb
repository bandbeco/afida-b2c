# frozen_string_literal: true

require "test_helper"

class HtmlCompactorMiddlewareTest < ActiveSupport::TestCase
  INDENTED_HTML = <<~HTML
    <!DOCTYPE html>
    <html>
      <body>
        <!-- Hero -->
        <main>
          <h1>Hello</h1>

          <p>World</p>
        </main>
      </body>
    </html>
  HTML

  def app_returning(body, status: 200, headers: { "Content-Type" => "text/html; charset=utf-8" })
    ->(_env) { [ status, headers.dup, [ body ] ] }
  end

  def call(app, path: "/")
    HtmlCompactorMiddleware.new(app).call(Rack::MockRequest.env_for(path))
  end

  def body_of(response)
    response[2].respond_to?(:join) ? response[2].join : response[2].to_s
  end

  test "strips leading indentation and blank lines from HTML responses" do
    body = body_of(call(app_returning(INDENTED_HTML)))

    refute_match(/^[ \t]+/, body)
    refute_match(/\n\n/, body)
    assert_includes body, "<h1>Hello</h1>\n<p>World</p>"
  end

  test "strips HTML comments" do
    body = body_of(call(app_returning(INDENTED_HTML)))

    refute_includes body, "<!--"
    assert_includes body, "<!DOCTYPE html>"
  end

  test "keeps a single newline between lines so inline whitespace still separates words" do
    body = body_of(call(app_returning("<p>\n    Hello\n    world\n</p>")))

    assert_equal "<p>\nHello\nworld\n</p>", body
  end

  test "updates Content-Length" do
    _status, headers, body = call(app_returning(INDENTED_HTML))

    assert_equal body.join.bytesize.to_s, headers["Content-Length"]
  end

  test "compacts 404 HTML responses too" do
    status, _headers, body = call(app_returning(INDENTED_HTML, status: 404))

    assert_equal 404, status
    refute_match(/^[ \t]+/, body.join)
  end

  test "leaves responses containing preformatted text untouched" do
    html = "<html>\n  <body>\n    <pre>\n    keep me\n    </pre>\n  </body>\n</html>"

    assert_equal html, body_of(call(app_returning(html)))
  end

  test "leaves responses containing a textarea untouched" do
    html = "<form>\n  <textarea>\n    keep me\n  </textarea>\n</form>"

    assert_equal html, body_of(call(app_returning(html)))
  end

  test "leaves non-HTML responses untouched" do
    json = "{\n  \"ok\": true\n}"
    _status, headers, body = call(app_returning(json, headers: { "Content-Type" => "application/json" }))

    assert_equal json, body.join
    assert_nil headers["Content-Length"]
  end

  test "leaves already-encoded responses untouched" do
    headers = { "Content-Type" => "text/html", "Content-Encoding" => "gzip" }

    assert_equal INDENTED_HTML, body_of(call(app_returning(INDENTED_HTML, headers: headers)))
  end

  test "leaves bodiless responses untouched" do
    status, _headers, body = call(->(_env) { [ 304, { "Content-Type" => "text/html" }, [] ] })

    assert_equal 304, status
    assert_equal [], body
  end
end

class HtmlCompactorMiddlewareRackHeadersTest < ActiveSupport::TestCase
  test "does not duplicate lowercase Rack 3 headers from a plain Hash" do
    app = ->(_env) { [ 404, { "content-type" => "text/html", "content-length" => "999" }, [ "<html>\n  <body>\n    <p>x</p>\n  </body>\n</html>" ] ] }
    _status, headers, body = HtmlCompactorMiddleware.new(app).call(Rack::MockRequest.env_for("/missing"))

    assert_equal headers.keys.size, headers.keys.map(&:downcase).uniq.size, "duplicate header names: #{headers.keys}"
    assert_equal body.join.bytesize.to_s, headers["content-length"]
  end
end
